import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/hermes_service.dart';
import 'services/monitor_service.dart';
import 'services/scheduler_service.dart';
import 'services/notification_service.dart';
import 'services/terminal_service.dart';
import 'services/file_service.dart';
import 'services/system_service.dart';
import 'services/browser_service.dart';
import 'core/logger.dart';
import 'core/platform.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  final logger = JarvisLogger();
  await logger.init();
  logger.info('Jarvis Desktop Agent starting...');
  logger.info('Platform: ${PlatformInfo.current.name}');

  // Initialize services
  final hermesService = HermesService();
  final monitorService = MonitorService();
  final schedulerService = SchedulerService();

  // Register default command handlers
  hermesService.registerDefaultHandler((command) async {
    logger.info('Processing command: ${command.action}', data: command.payload);

    try {
      switch (command.action) {
        case 'terminal.run':
          final terminal = TerminalService();
          final result = await terminal.run(
            command.payload['command'] as String? ?? '',
            workdir: command.payload['workdir'] as String?,
            timeout: command.payload['timeout'] as int? ?? 30000,
          );
          return command.successResponse({
            'stdout': result.stdout,
            'stderr': result.stderr,
            'exitCode': result.exitCode,
            'timedOut': result.timedOut,
          });

        case 'file.read':
          final fileService = FileService();
          final result = await fileService.read(command.payload['path'] as String? ?? '');
          return command.successResponse(result.toJson());

        case 'file.write':
          final fileService = FileService();
          final result = await fileService.write(
            command.payload['path'] as String? ?? '',
            command.payload['content'] as String? ?? '',
          );
          return command.successResponse(result.toJson());

        case 'file.list':
          final fileService = FileService();
          final result = await fileService.list(
            command.payload['path'] as String? ?? '.',
            recursive: command.payload['recursive'] as bool? ?? false,
          );
          return command.successResponse(result.toJson());

        case 'file.organize':
          final fileService = FileService();
          final result = await fileService.organizeDownloads(
            olderThanDays: command.payload['olderThanDays'] as int? ?? 30,
          );
          return command.successResponse(result.toJson());

        case 'system.info':
          final systemService = SystemService();
          final info = await systemService.getInfo();
          return command.successResponse(info.toJson());

        case 'system.shutdown':
          final systemService = SystemService();
          await systemService.shutdown(delaySeconds: command.payload['delay'] as int? ?? 0);
          return command.successResponse('Shutting down...');

        case 'system.restart':
          final systemService = SystemService();
          await systemService.restart(delaySeconds: command.payload['delay'] as int? ?? 0);
          return command.successResponse('Restarting...');

        case 'system.sleep':
          final systemService = SystemService();
          await systemService.sleep();
          return command.successResponse('Sleeping...');

        case 'system.lock':
          final systemService = SystemService();
          await systemService.lockScreen();
          return command.successResponse('Locked');

        case 'app.open':
          final systemService = SystemService();
          await systemService.openApp(command.payload['name'] as String? ?? '');
          return command.successResponse('App opened');

        case 'browser.open':
          final browserService = BrowserService();
          await browserService.openUrl(command.payload['url'] as String? ?? '');
          return command.successResponse('URL opened');

        case 'notification.show':
          final notificationService = NotificationService();
          await notificationService.show(
            command.payload['title'] as String? ?? 'Jarvis',
            command.payload['body'] as String? ?? '',
          );
          return command.successResponse('Notification sent');

        case 'ping':
          return command.successResponse('pong');

        default:
          return command.errorResponse('Unknown action: ${command.action}');
      }
    } catch (e) {
      logger.error('Command failed', exception: e);
      return command.errorResponse(e.toString());
    }
  });

  // Connect to Hermes (will auto-reconnect)
  hermesService.connect();

  // Start monitoring
  monitorService.start();

  // Init scheduler
  await schedulerService.init();

  logger.info('All services initialized');

  runApp(
    MultiProvider(
      providers: [
        Provider<HermesService>.value(value: hermesService),
        Provider<MonitorService>.value(value: monitorService),
        Provider<SchedulerService>.value(value: schedulerService),
      ],
      child: const JarvisApp(),
    ),
  );
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jarvis Desktop Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
