import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../engine/render/sprite_atlas.dart';

/// Loads atlases for Flutter screens (gallery, hero select), cached.
class AtlasCache {
  static final Map<String, Future<(AtlasData, ui.Image)>> _cache = {};

  static Future<(AtlasData, ui.Image)> load(String name) => _cache.putIfAbsent(
    name,
    () async {
      final json = jsonDecode(
        await rootBundle.loadString('assets/sprites/$name.json'),
      ) as Map<String, dynamic>;
      final data = AtlasData.fromJson(json);
      final bytes = await rootBundle.load('assets/sprites/${data.image}');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return (data, frame.image);
    },
  );
}

/// An animated atlas sprite, nearest-neighbour scaled.
class AtlasSprite extends StatefulWidget {
  const AtlasSprite(
    this.atlas, {
    super.key,
    this.anim = 'idle',
    this.scale = 2,
    this.silhouette = false,
    this.flipX = false,
  });

  final String atlas;
  final String anim;
  final double scale;

  /// Draw as a dark silhouette (locked items).
  final bool silhouette;
  final bool flipX;

  @override
  State<AtlasSprite> createState() => _AtlasSpriteState();
}

class _AtlasSpriteState extends State<AtlasSprite>
    with SingleTickerProviderStateMixin {
  (AtlasData, ui.Image)? _a;
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    AtlasCache.load(widget.atlas).then((v) {
      if (mounted) setState(() => _a = v);
    });
    _ticker = createTicker((d) => setState(() => _t = d.inMicroseconds / 1e6))
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    if (a == null) {
      return SizedBox(width: 32 * widget.scale, height: 32 * widget.scale);
    }
    final (data, image) = a;
    final r = data.frames.first;
    return CustomPaint(
      size: Size(r.width * widget.scale, r.height * widget.scale),
      painter: _AtlasPainter(
        data,
        image,
        widget.anim,
        _t,
        widget.scale,
        widget.silhouette,
        widget.flipX,
      ),
    );
  }
}

class _AtlasPainter extends CustomPainter {
  _AtlasPainter(
    this.data,
    this.image,
    this.anim,
    this.t,
    this.scale,
    this.silhouette,
    this.flipX,
  );

  final AtlasData data;
  final ui.Image image;
  final String anim;
  final double t, scale;
  final bool silhouette, flipX;

  @override
  void paint(Canvas canvas, Size size) {
    final a = data.animations[anim] ?? data.animations.values.first;
    final i = a.frames[(t * a.fps).floor() % a.frames.length];
    final src = data.frames[i];
    final paint = Paint()..filterQuality = FilterQuality.none;
    if (silhouette) {
      paint.colorFilter = const ColorFilter.mode(
        Color(0xFF1B1A2B),
        BlendMode.srcATop,
      );
    }
    canvas.save();
    if (flipX) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(image, src, Offset.zero & size, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AtlasPainter old) => true;
}
