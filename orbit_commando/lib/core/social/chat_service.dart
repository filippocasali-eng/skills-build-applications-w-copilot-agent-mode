import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'moderation.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channel,
    required this.user,
    required this.nick,
    required this.text,
    required this.time,
    this.emote = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    channel: j['channel'] as String,
    user: j['user'] as String,
    nick: j['nick'] as String,
    text: j['text'] as String,
    time: DateTime.parse(j['time'] as String),
    emote: j['emote'] as bool? ?? false,
  );

  final String id, channel, user, nick, text;
  final DateTime time;
  final bool emote;
}

enum SendStatus { sent, filtered, rateLimited, muted, offline, notAllowed }

/// Chat transport. Global per language, squadron (clan, up to 30) and
/// private messages between mutual friends.
abstract interface class ChatService {
  bool get online;
  bool get isDemo;
  Stream<List<ChatMessage>> watch(String channel);
  Future<SendStatus> send(String channel, String text, {bool emote = false});
  Future<void> report(ChatMessage m);
  Future<void> block(String userId);
  Set<String> get blocked;
}

/// Talks to the backend in backend/functions when BACKEND_URL is set at
/// build time. The server re-runs the filter, rate limit and mutes.
class BackendChatService implements ChatService {
  BackendChatService(this.baseUrl, this.token);

  final String baseUrl;
  final String token;
  final Set<String> _blocked = {};
  final RateLimiter _rate = RateLimiter();

  @override
  bool get online => true;
  @override
  bool get isDemo => false;
  @override
  Set<String> get blocked => _blocked;

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    'authorization': 'Bearer $token',
  };

  @override
  Stream<List<ChatMessage>> watch(String channel) async* {
    while (true) {
      try {
        final r = await http.get(
          Uri.parse('$baseUrl/chat/$channel'),
          headers: _headers,
        );
        if (r.statusCode == 200) {
          final list = (jsonDecode(r.body) as List<dynamic>).map(
            (e) => ChatMessage.fromJson(e as Map<String, dynamic>),
          );
          yield list.where((m) => !_blocked.contains(m.user)).toList();
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  @override
  Future<SendStatus> send(
    String channel,
    String text, {
    bool emote = false,
  }) async {
    if (!ChatFilter.check(text).allowed) return SendStatus.filtered;
    if (!_rate.tryAcquire(DateTime.now())) return SendStatus.rateLimited;
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/chat/$channel'),
        headers: _headers,
        body: jsonEncode({'text': text, 'emote': emote}),
      );
      return switch (r.statusCode) {
        200 => SendStatus.sent,
        403 => SendStatus.muted,
        422 => SendStatus.filtered,
        429 => SendStatus.rateLimited,
        _ => SendStatus.offline,
      };
    } catch (_) {
      return SendStatus.offline;
    }
  }

  @override
  Future<void> report(ChatMessage m) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/report'),
        headers: _headers,
        body: jsonEncode({'message': m.id}),
      );
    } catch (_) {}
  }

  @override
  Future<void> block(String userId) async => _blocked.add(userId);
}

/// Offline demo used when no backend is configured: your messages go
/// through the same filter, rate limit, report/mute and block logic, and a
/// few NPC pilots chat back. Clearly labelled as a demo in the UI.
class DemoChatService implements ChatService {
  final Map<String, List<ChatMessage>> _channels = {};
  final Map<String, StreamController<List<ChatMessage>>> _streams = {};
  final Set<String> _blocked = {};
  final RateLimiter _rate = RateLimiter();
  final ReportTracker _reports = ReportTracker(threshold: 1);
  int _n = 0;

  static const _npc = [
    (
      'npc1',
      'ACE_RITA',
      [
        'Bel colpo!',
        'Qualcuno ha battuto la Lavatrice?',
        'GG',
        'Aiuto col boss?',
      ],
    ),
    (
      'npc2',
      'VECTOR77',
      ['One more!', 'Nice shot!', 'Squadron goal almost done', 'GG'],
    ),
    (
      'npc3',
      'DOC_FAN',
      ['Ciao!', 'Grazie!', 'Il mech a molla è top', 'Ancora una!'],
    ),
  ];

  @override
  bool get online => true;
  @override
  bool get isDemo => true;
  @override
  Set<String> get blocked => _blocked;

  void _emit(String ch) => _streams[ch]?.add(
    [...?_channels[ch]].where((m) => !_blocked.contains(m.user)).toList(),
  );

  void _add(ChatMessage m) {
    (_channels[m.channel] ??= []).add(m);
    if (_channels[m.channel]!.length > 60) _channels[m.channel]!.removeAt(0);
    _emit(m.channel);
  }

  @override
  Stream<List<ChatMessage>> watch(String channel) {
    final c = _streams.putIfAbsent(channel, StreamController.broadcast);
    if ((_channels[channel] ?? const []).isEmpty) {
      for (final (id, nick, lines) in _npc) {
        _add(
          ChatMessage(
            id: 'm${_n++}',
            channel: channel,
            user: id,
            nick: nick,
            text: lines.first,
            time: DateTime.now(),
          ),
        );
      }
    }
    Future.microtask(() => _emit(channel));
    return c.stream;
  }

  @override
  Future<SendStatus> send(
    String channel,
    String text, {
    bool emote = false,
  }) async {
    final now = DateTime.now();
    if (_reports.isMuted('me', now)) return SendStatus.muted;
    if (!emote && !ChatFilter.check(text).allowed) return SendStatus.filtered;
    if (!_rate.tryAcquire(now)) return SendStatus.rateLimited;
    _add(
      ChatMessage(
        id: 'm${_n++}',
        channel: channel,
        user: 'me',
        nick: 'YOU',
        text: text,
        time: now,
        emote: emote,
      ),
    );
    // An NPC answers after a moment.
    final npc = _npc[_n % _npc.length];
    Timer(const Duration(milliseconds: 1500), () {
      _add(
        ChatMessage(
          id: 'm${_n++}',
          channel: channel,
          user: npc.$1,
          nick: npc.$2,
          text: npc.$3[_n % npc.$3.length],
          time: DateTime.now(),
          emote: true,
        ),
      );
    });
    return SendStatus.sent;
  }

  @override
  Future<void> report(ChatMessage m) async {
    _reports.report(target: m.user, by: 'me', now: DateTime.now());
  }

  @override
  Future<void> block(String userId) async {
    _blocked.add(userId);
    for (final ch in _channels.keys) {
      _emit(ch);
    }
  }
}

const backendUrl = String.fromEnvironment('BACKEND_URL');

final chatServiceProvider = Provider<ChatService>((ref) {
  if (backendUrl.isNotEmpty) return BackendChatService(backendUrl, '');
  return DemoChatService();
});
