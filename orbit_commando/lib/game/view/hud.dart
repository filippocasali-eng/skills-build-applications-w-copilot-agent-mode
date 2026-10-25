import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/render/bitmap_font.dart';
import '../../engine/render/palette.g.dart';
import '../../engine/render/virtual_screen.dart';
import '../bosses/bosses.dart';
import '../input/controls.dart';
import '../play_game.dart';
import '../sim/balance.dart';
import 'fx.dart';
import 'world_renderer.dart';

/// Arcade HUD in screen space: 7-segment score, lives, weapon and ammo,
/// grenades, credits, boss bar and the touch controls.
class Hud extends Component with HasGameReference<PlayGame> {
  final Paint _fill = Paint()..isAntiAlias = false;
  final Paint _stroke = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke;
  late final Paint _ui = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  @override
  void render(Canvas canvas) {
    final g = game;
    final sim = g.sim;
    final res = g.res;
    final font = res.font;
    final p = sim.player;

    // Flash overlay (big explosions).
    if (g.fx.flash > 0) {
      _fill.color = Pal.ink7.withValues(alpha: 0.7);
      canvas.drawRect(VirtualScreen.rect, _fill);
    }

    // --- score (7 segment) ---
    font.draw(canvas, '1P', 8, 6, color: Pal.ember5, shadow: Pal.ink0);
    final digits = res.atlas('seg_digits');
    final score = sim.score.clamp(0, 99999999).toString().padLeft(8, ' ');
    for (var i = 0; i < 8; i++) {
      final ch = score[i] == ' ' ? 'd_' : 'd${score[i]}';
      drawFrame(canvas, digits, digits.frameAt(ch, 0), 24.0 + i * 13, 5);
    }
    if (sim.combo >= 3) {
      font.draw(
        canvas,
        'x${sim.combo} COMBO',
        24,
        25,
        color: (g.time * 8).floor().isEven ? Pal.gold7 : Pal.ember6,
        shadow: Pal.ink0,
      );
    }

    // --- friend's challenge: the score to beat, green once beaten ---
    final target = g.config.target;
    if (target != null) {
      final beaten = sim.score > target;
      font.draw(
        canvas,
        beaten ? 'BEATEN!' : 'BEAT $target',
        VirtualScreen.width / 2,
        8,
        color: beaten ? Pal.moss6 : Pal.neon6,
        shadow: Pal.ink0,
        scale: 2,
        align: PixelTextAlign.center,
      );
    }

    // --- hype callout: pops in big, settles, blinks out ---
    final hype = g.hypeText;
    if (hype != null) {
      final t = g.hypeAge;
      final scale = t < 0.08 ? 5 : (g.hypeTier >= 4 ? 4 : 3);
      final colors = [Pal.gold7, Pal.ember6, Pal.neon6, Pal.aqua7];
      final c = g.hypeTier >= 4
          ? colors[(t * 16).floor() % colors.length]
          : colors[g.hypeTier - 1];
      if (t < 1.0 || (t * 12).floor().isEven) {
        font.draw(
          canvas,
          hype,
          VirtualScreen.width / 2,
          96 - (t < 0.08 ? 6 : 0),
          color: c,
          shadow: Pal.ink0,
          scale: scale,
          align: PixelTextAlign.center,
        );
        if (sim.combo >= 3) {
          font.draw(
            canvas,
            'x${sim.combo}',
            VirtualScreen.width / 2,
            96 + 10.0 * scale + 4,
            color: Pal.ink7,
            shadow: Pal.ink0,
            scale: 2,
            align: PixelTextAlign.center,
          );
        }
      }
    }

    // --- lives / hp ---
    final icons = res.atlas('icons');
    final hero = heroAtlasOf(g);
    canvas.save();
    canvas.translate(8, 46);
    canvas.scale(0.4);
    drawFrame(
      canvas,
      hero,
      hero.frameAt('idle', 0),
      hero.data.origin.dx,
      hero.data.origin.dy,
    );
    canvas.restore();
    font.draw(
      canvas,
      'x${math.max(0, p.lives)}',
      36,
      64,
      color: Pal.ink7,
      shadow: Pal.ink0,
    );
    if (p.maxHp > 1) {
      for (var i = 0; i < p.maxHp; i++) {
        canvas.save();
        canvas.translate(60.0 + i * 14, 68);
        canvas.scale(0.5);
        if (i < p.hp) {
          drawFrame(canvas, icons, icons.frameAt('heart', 0), 0, 0);
        } else {
          drawFrame(
            canvas,
            icons,
            icons.frameAt('heart', 0),
            0,
            0,
            paint: Paint()
              ..colorFilter = const ColorFilter.mode(
                Color(0xFF2E2D45),
                BlendMode.srcATop,
              ),
          );
        }
        canvas.restore();
      }
    }

    // --- weapon / ammo / grenades (top centre) ---
    final cx = VirtualScreen.width / 2;
    _fill.color = Pal.ink0.withValues(alpha: 0.6);
    canvas.drawRect(Rect.fromLTWH(cx - 70, 4, 140, 22), _fill);
    final w = p.inVehicle ? null : p.weapon;
    final wName = w == null
        ? sim.vehicles.current?.kind.name.toUpperCase() ?? ''
        : (w == WeaponKind.blaster ? 'BLASTER' : w.name.toUpperCase());
    font.draw(
      canvas,
      wName,
      cx - 64,
      10,
      color: w == null ? Pal.aqua6 : weaponColor(w),
      shadow: Pal.ink0,
    );
    final ammoText = w == null
        ? '${sim.vehicles.current?.hp ?? 0}HP'
        : (w == WeaponKind.blaster || p.ammo > 100000)
        ? '∞'
        : '${p.ammo}';
    font.draw(
      canvas,
      ammoText == '∞' ? 'INF' : ammoText,
      cx + 8,
      10,
      color: Pal.ink7,
      shadow: Pal.ink0,
      align: PixelTextAlign.right,
    );
    canvas.save();
    canvas.translate(cx + 30, 15);
    canvas.scale(0.6);
    drawFrame(canvas, icons, icons.frameAt('grenade', 0), 0, 0);
    canvas.restore();
    font.draw(
      canvas,
      '${p.grenades}',
      cx + 40,
      10,
      color: Pal.moss6,
      shadow: Pal.ink0,
    );

    // --- credits + pause (top right) ---
    canvas.save();
    canvas.translate(VirtualScreen.width - 92.0, 15);
    canvas.scale(0.6);
    drawFrame(canvas, icons, icons.frameAt('credit', 0), 0, 0);
    canvas.restore();
    font.draw(
      canvas,
      'x${g.config.credits}',
      VirtualScreen.width - 82,
      10,
      color: Pal.gold6,
      shadow: Pal.ink0,
    );
    if (!g.isAttract) {
      drawFrame(
        canvas,
        icons,
        icons.frameAt('pause', 0),
        VirtualScreen.width - 20.0,
        18,
        paint: _ui,
      );
    }

    // --- boss bar ---
    final boss = sim.bosses.boss;
    if (boss != null && boss.active && !boss.dead) {
      final bw = 300.0, bx = cx - bw / 2, by = 34.0;
      font.draw(
        canvas,
        _bossName(boss.kind),
        cx,
        by - 1,
        color: Pal.ember6,
        shadow: Pal.ink0,
        align: PixelTextAlign.center,
      );
      _fill.color = Pal.ink0;
      canvas.drawRect(Rect.fromLTWH(bx - 2, by + 10, bw + 4, 8), _fill);
      _fill.color = Pal.ember2;
      canvas.drawRect(Rect.fromLTWH(bx, by + 12, bw, 4), _fill);
      _fill.color = boss.hpFraction < 0.3 && (g.time * 6).floor().isEven
          ? Pal.gold6
          : Pal.ember5;
      canvas.drawRect(
        Rect.fromLTWH(bx, by + 12, bw * boss.hpFraction, 4),
        _fill,
      );
    }

    // --- level start banner ---
    if (sim.tick < 150 && !g.isAttract) {
      font.draw(
        canvas,
        g.config.title ?? sim.level.name,
        cx,
        140,
        color: Pal.ink7,
        shadow: Pal.ink0,
        align: PixelTextAlign.center,
        scale: 2,
      );
      if (sim.tick > 60 && (sim.tick ~/ 8).isEven) {
        font.draw(
          canvas,
          'GO!',
          cx,
          170,
          color: Pal.gold6,
          shadow: Pal.ember2,
          align: PixelTextAlign.center,
          scale: 3,
        );
      }
    }
    if (g.isAttract) {
      if ((g.time * 2).floor().isEven) {
        font.draw(
          canvas,
          'DEMO PLAY',
          cx,
          300,
          color: Pal.ink7,
          shadow: Pal.ink0,
          align: PixelTextAlign.center,
          scale: 2,
        );
      }
      return;
    }

    if (g.config.showTouchControls) _drawControls(canvas);
  }

  String _bossName(BossKind k) => switch (k) {
    BossKind.stamper => 'TIMBRATORE SUPREMO',
    BossKind.washer => 'LAVATRICE COSMICA',
    BossKind.emperor => 'IMPERATORE GLORBO',
  };

  void _drawControls(Canvas canvas) {
    final t = game.touch;
    final touchAtlas = game.res.atlas('touch');
    final icons = game.res.atlas('icons');
    final alpha = t.layout.opacity;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..color = Color.fromRGBO(255, 255, 255, alpha);
    // Floating stick: base where the thumb landed, knob following it.
    if (t.stickActive) {
      drawFrame(
        canvas,
        touchAtlas,
        touchAtlas.frameAt('base', 0),
        t.stickOriginX,
        t.stickOriginY,
        paint: paint,
      );
      drawFrame(
        canvas,
        touchAtlas,
        touchAtlas.frameAt('knob', 0),
        t.stickOriginX + t.stickX,
        t.stickOriginY + t.stickY,
        paint: paint,
      );
    } else {
      // Ghost hint of where the stick lives.
      _stroke
        ..strokeWidth = 1
        ..color = Pal.ink5.withValues(alpha: alpha * 0.5);
      canvas.drawCircle(const Offset(90, 280), 30, _stroke);
    }
    for (final e in t.layout.buttons.entries) {
      final b = e.value;
      final down = t.pressed.contains(e.key);
      canvas.save();
      canvas.translate(b.x, b.y);
      canvas.scale(b.radius / 30);
      drawFrame(
        canvas,
        touchAtlas,
        touchAtlas.frameAt(down ? 'button_down' : 'button', 0),
        0,
        0,
        paint: paint,
      );
      final icon = switch (e.key) {
        ControlButton.fire => 'fire',
        ControlButton.jump => 'jump',
        ControlButton.grenade => 'grenade',
        ControlButton.dash => 'dash',
      };
      if (e.key != ControlButton.dash || game.sim.player.dashUnlocked) {
        drawFrame(
          canvas,
          icons,
          icons.frameAt(icon, 0),
          0,
          down ? 2 : 0,
          paint: paint,
        );
      }
      canvas.restore();
    }
  }
}
