import 'dart:async';
import '../models/orb_state.dart';

class OrbStateManager {
  OrbState _currentState = OrbState.idle;
  final StreamController<OrbState> _stateController =
      StreamController<OrbState>.broadcast();
  final Map<OrbState, int> _listeners = {};

  OrbState get currentState => _currentState;
  Stream<OrbState> get stateStream => _stateController.stream;

  void _transitionTo(OrbState newState) {
    if (_currentState == newState) return;
    final oldState = _currentState;
    _currentState = newState;
    _stateController.add(newState);
    _logTransition(oldState, newState);
  }

  void _logTransition(OrbState from, OrbState to) {
    // State transitions are logged but not to timeline to avoid noise
  }

  void requestListening(String source) {
    _listeners[OrbState.listening] = (_listeners[OrbState.listening] ?? 0) + 1;
    _transitionTo(OrbState.listening);
  }

  void releaseListening(String source) {
    final count = (_listeners[OrbState.listening] ?? 0) - 1;
    if (count <= 0) {
      _listeners.remove(OrbState.listening);
      if (_currentState == OrbState.listening) {
        _transitionTo(OrbState.idle);
      }
    } else {
      _listeners[OrbState.listening] = count;
    }
  }

  void requestThinking(String source) {
    _listeners[OrbState.thinking] = (_listeners[OrbState.thinking] ?? 0) + 1;
    _transitionTo(OrbState.thinking);
  }

  void releaseThinking(String source) {
    final count = (_listeners[OrbState.thinking] ?? 0) - 1;
    if (count <= 0) {
      _listeners.remove(OrbState.thinking);
      if (_currentState == OrbState.thinking) {
        _transitionTo(OrbState.idle);
      }
    } else {
      _listeners[OrbState.thinking] = count;
    }
  }

  void requestSpeaking(String source) {
    _listeners[OrbState.speaking] = (_listeners[OrbState.speaking] ?? 0) + 1;
    _transitionTo(OrbState.speaking);
  }

  void releaseSpeaking(String source) {
    final count = (_listeners[OrbState.speaking] ?? 0) - 1;
    if (count <= 0) {
      _listeners.remove(OrbState.speaking);
      if (_currentState == OrbState.speaking) {
        _transitionTo(OrbState.idle);
      }
    } else {
      _listeners[OrbState.speaking] = count;
    }
  }

  void forceIdle() {
    _listeners.clear();
    _transitionTo(OrbState.idle);
  }

  bool get isIdle => _currentState == OrbState.idle;
  bool get isListening => _currentState == OrbState.listening;
  bool get isThinking => _currentState == OrbState.thinking;
  bool get isSpeaking => _currentState == OrbState.speaking;
  bool get isActive => _currentState != OrbState.idle;

  void dispose() {
    _stateController.close();
  }
}
