enum OrbState {
  idle,
  listening,
  thinking,
  speaking,
}

extension OrbStateExtension on OrbState {
  String get label {
    switch (this) {
      case OrbState.idle:
        return 'Idle';
      case OrbState.listening:
        return 'Listening';
      case OrbState.thinking:
        return 'Thinking';
      case OrbState.speaking:
        return 'Speaking';
    }
  }

  String get description {
    switch (this) {
      case OrbState.idle:
        return 'Ready to help';
      case OrbState.listening:
        return 'Capturing voice input';
      case OrbState.thinking:
        return 'Processing your request';
      case OrbState.speaking:
        return 'Delivering response';
    }
  }

  bool get isActive => this != OrbState.idle;
}
