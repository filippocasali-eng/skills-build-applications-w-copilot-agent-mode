import 'input/controls.dart';

/// Player-facing control settings.
class ControlsConfig {
  const ControlsConfig({
    this.layout = const ControlsLayout(),
    this.vibration = true,
  });

  final ControlsLayout layout;
  final bool vibration;
}
