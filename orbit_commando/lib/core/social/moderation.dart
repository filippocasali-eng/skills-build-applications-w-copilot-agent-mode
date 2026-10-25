/// Client-side mirror of the server chat filter (backend/functions runs
/// the same rules; the server is authoritative). Covers insults and
/// profanity (IT/EN), phone numbers, e-mails and links.
enum FilterReason { ok, profanity, phone, email, link, empty, tooLong }

class FilterResult {
  const FilterResult(this.reason, this.text);

  final FilterReason reason;
  final String text;

  bool get allowed => reason == FilterReason.ok;
}

class ChatFilter {
  /// Kept short and mild in the repo; the server list is longer and
  /// updated remotely. Matching ignores case, accents and leetspeak.
  static const _words = [
    // en
    'fuck',
    'shit',
    'bitch',
    'bastard',
    'asshole',
    'dick',
    'cunt',
    'slut',
    'whore',
    'retard',
    'faggot',
    'nigger',
    // it
    'cazzo',
    'stronzo',
    'stronza',
    'vaffanculo',
    'fanculo',
    'puttana',
    'troia',
    'coglione',
    'merda',
    'bastardo',
    'frocio', 'negro', 'mongoloide', 'ritardato',
  ];

  static final _phone = RegExp(r'(\+?\d[\d\s\-.()]{6,}\d)');
  static final _email = RegExp(
    r'[\w.+-]+@[\w-]+\.[\w.]+',
    caseSensitive: false,
  );
  static final _link = RegExp(
    r'(https?://|www\.|\b[\w-]+\.(com|it|net|org|io|gg|ly|me|tv|xyz)\b)',
    caseSensitive: false,
  );

  static String normalize(String s) {
    const map = {
      '0': 'o',
      '1': 'i',
      '3': 'e',
      '4': 'a',
      '5': 's',
      '7': 't',
      '@': 'a',
      r'$': 's',
      'à': 'a',
      'è': 'e',
      'é': 'e',
      'ì': 'i',
      'ò': 'o',
      'ù': 'u',
    };
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      b.write(map[ch] ?? ch);
    }
    // Remove separators people use to dodge filters: f.u.c.k, f u c k
    return b.toString().replaceAll(RegExp(r'[^a-z]'), '');
  }

  static FilterResult check(String text, {int maxLength = 140}) {
    final t = text.trim();
    if (t.isEmpty) return const FilterResult(FilterReason.empty, '');
    if (t.length > maxLength) return FilterResult(FilterReason.tooLong, t);
    if (_email.hasMatch(t)) return FilterResult(FilterReason.email, t);
    if (_link.hasMatch(t)) return FilterResult(FilterReason.link, t);
    if (_phone.hasMatch(t)) return FilterResult(FilterReason.phone, t);
    final n = normalize(t);
    for (final w in _words) {
      if (n.contains(w)) return FilterResult(FilterReason.profanity, t);
    }
    return FilterResult(FilterReason.ok, t);
  }
}

/// 1 message every [interval] per user.
class RateLimiter {
  RateLimiter({this.interval = const Duration(seconds: 3)});

  final Duration interval;
  DateTime? _last;

  bool tryAcquire(DateTime now) {
    if (_last != null && now.difference(_last!) < interval) return false;
    _last = now;
    return true;
  }
}

/// Automatic mute after multiple reports from distinct users.
class ReportTracker {
  ReportTracker({this.threshold = 3, this.muteFor = const Duration(hours: 1)});

  final int threshold;
  final Duration muteFor;
  final Map<String, Set<String>> _reports = {};
  final Map<String, DateTime> _mutedUntil = {};

  /// Returns true when the report triggered a mute.
  bool report({
    required String target,
    required String by,
    required DateTime now,
  }) {
    final s = _reports.putIfAbsent(target, () => {})..add(by);
    if (s.length >= threshold) {
      _mutedUntil[target] = now.add(muteFor);
      s.clear();
      return true;
    }
    return false;
  }

  bool isMuted(String user, DateTime now) {
    final u = _mutedUntil[user];
    return u != null && now.isBefore(u);
  }
}
