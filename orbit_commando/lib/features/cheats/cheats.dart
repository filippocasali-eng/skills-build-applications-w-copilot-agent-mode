/// Title-screen secret codes, entered as swipes (touch) or arrows / D-pad.
///
/// The sequences are original (an "orbit" circle, a pixel staircase and a
/// TV-knob wiggle) and deliberately unlike well-known codes.
enum Dir { up, down, left, right }

enum Cheat { bigHeads, giantPixels, brokenTube }

class CheatCodes {
  static const codes = <Cheat, List<Dir>>{
    // Two clockwise orbits.
    Cheat.bigHeads: [
      Dir.up,
      Dir.right,
      Dir.down,
      Dir.left,
      Dir.up,
      Dir.right,
      Dir.down,
      Dir.left,
    ],
    // Down three steps, up three steps.
    Cheat.giantPixels: [Dir.down, Dir.down, Dir.down, Dir.up, Dir.up, Dir.up],
    // Wiggle the TV knob, then thump the set.
    Cheat.brokenTube: [
      Dir.left,
      Dir.right,
      Dir.left,
      Dir.right,
      Dir.down,
      Dir.up,
    ],
  };
}

class CheatDetector {
  final List<Dir> _buffer = [];

  /// Feeds one direction; returns a cheat when a code completes.
  Cheat? feed(Dir d) {
    _buffer.add(d);
    if (_buffer.length > 12) _buffer.removeAt(0);
    for (final e in CheatCodes.codes.entries) {
      final code = e.value;
      if (_buffer.length < code.length) continue;
      var match = true;
      for (var i = 0; i < code.length; i++) {
        if (_buffer[_buffer.length - code.length + i] != code[i]) {
          match = false;
          break;
        }
      }
      if (match) {
        _buffer.clear();
        return e.key;
      }
    }
    return null;
  }
}
