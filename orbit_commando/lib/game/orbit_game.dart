import 'package:flame/cache.dart';
import 'package:flame/camera.dart';
import 'package:flame/game.dart';

import '../engine/loop/fixed_step_clock.dart';
import '../engine/loop/fixed_tick.dart';
import '../engine/render/pixel_renderer.dart';
import '../engine/render/virtual_screen.dart';
import 'game_resources.dart';
import 'game_strings.dart';
import 'scenes/demo_scene.dart';

enum StartScene { title, sandbox }

/// Root Flame game. Renders at 384x216 via [PixelPerfectRender] and runs the
/// simulation at a fixed 60 Hz via [FixedStepClock].
class OrbitGame extends FlameGame with PixelPerfectRender implements TickHost {
  OrbitGame({required this.strings, this.startScene = StartScene.title})
    : super(
        camera: CameraComponent(
          viewport: FixedSizeViewport(
            VirtualScreen.width.toDouble(),
            VirtualScreen.height.toDouble(),
          ),
        ),
      ) {
    images = Images(prefix: 'assets/');
    assets = AssetsCache(prefix: 'assets/');
  }

  final GameStrings strings;
  final StartScene startScene;
  final FixedStepClock clock = FixedStepClock();
  final List<FixedTick> _ticking = [];

  late final GameResources resources;

  /// Smoothed frames per second, for the debug overlay.
  double fps = 60;

  @override
  Future<void> onLoad() async {
    resources = await GameResources.load(images: images, assets: assets);
    await add(DemoScene(showTitle: startScene == StartScene.title));
  }

  @override
  void registerTick(FixedTick c) => _ticking.add(c);

  @override
  void unregisterTick(FixedTick c) => _ticking.remove(c);

  @override
  void update(double dt) {
    if (dt > 0) fps += (1 / dt - fps) * 0.05;
    final steps = clock.advance(dt);
    for (var s = 0; s < steps; s++) {
      final tick = clock.tick - steps + s + 1;
      // Index loop: the list may change while ticking (spawns/despawns
      // are applied by Flame at the end of the frame anyway).
      for (var i = 0; i < _ticking.length; i++) {
        _ticking[i].fixedUpdate(tick);
      }
    }
    super.update(dt);
  }
}
