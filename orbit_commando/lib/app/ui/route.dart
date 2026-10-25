import 'package:flutter/widgets.dart';

/// Instant page switch (no Material slide) for a retro feel.
class PixelRoute extends PageRouteBuilder<void> {
  PixelRoute(Widget page)
    : super(
        pageBuilder: (_, _, _) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
}
