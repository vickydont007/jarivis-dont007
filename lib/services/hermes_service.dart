import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/command_model.dart';
import '../core/constants.dart';
import '../core/logger.dart';

typedef CommandHandler = Future<JarvisCommand> Function(JarvisCommand command);

class HermesService {
  static final HermesService _instance = HermesService._internal();
  factory HermesService() => _instance;
  HermesService._internal();

  final JarvisLogger _log = JarvisLogger();
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  
  bool _isConnected = false;
  bool _shouldReconnect = true;
  String _wsUrl = AppConstants.hermesDefaultUrl;
  
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<JarvisCommand> _commandController =
      StreamController<JarvisCommand>.broadcast();

  Stream<bool> get onConnectionChanged => _connectionController.stream;
  Stream<JarvisCommand> get onCommand => _commandController.stream;
  bool get isConnected => _isConnected;

  final Map<String, CommandHandler> _handlers = {};

  void registerHandler(String action, CommandHandler handler) {
    _handlers[action] = handler;
  }

  void registerDefaultHandler(CommandHandler handler) {
    _handlers['*'] = handler;
  }

  Future<void> connect({String? url}) async {
    _wsUrl = url ?? AppConstants.hermesDefaultUrl;
    _shouldReconnect = true;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    try {
      _channel?.sink.close();
      await _subscription?.cancel();

      final wsUrl = Uri.parse(_wsUrl);
      _log.info('Connecting to Hermes at $_wsUrl');
      
      _channel = WebSocketChannel.connect(wsUrl);
      await _channel!.ready;

      _isConnected = true;
      _connectionController.add(true);
      _log.info('Connected to Hermes successfully');

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      _log.error('Connection failed', exception: e);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final command = JarvisCommand.fromJson(data);
      
      if (!command.isResponse) {
        _log.info('Command received: ${command.action}', data: command.payload);
        _processCommand(command);
        _commandController.add(command);
      }
    } catch (e) {
      _log.error('Failed to parse message', exception: e);
    }
  }

  Future<void> _processCommand(JarvisCommand command) async {
    // Check for specific handler
    final handler = _handlers[command.action] ?? _handlers['*'];
    if (handler != null) {
      final response = await handler(command);
      send(response);
    }
  }

  void _onError(dynamic error) {
    _log.error('WebSocket error', exception: error);
    _isConnected = false;
    _connectionController.add(false);
  }

  void _onDone() {
    _log.info('WebSocket connection closed');
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      Duration(milliseconds: AppConstants.reconnectDelay),
      _doConnect,
    );
    _log.info('Reconnecting in ${AppConstants.reconnectDelay}ms...');
  }

  void send(JarvisCommand command) {
    if (_channel == null || !_isConnected) {
      _log.warning('Cannot send: not connected');
      return;
    }
    try {
      final json = jsonEncode(command.toJson());
      _channel!.sink.add(json);
      _log.debug('Sent: ${command.action}');
    } catch (e) {
      _log.error('Failed to send', exception: e);
    }
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _connectionController.add(false);
    _log.info('Disconnected from Hermes');
  }

  void dispose() {
    disconnect();
    _connectionController.close();
    _commandController.close();
  }
}
