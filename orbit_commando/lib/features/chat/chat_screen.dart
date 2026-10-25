import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/pixel.dart';
import '../../core/profile/profile.dart';
import '../../core/progress/progress.dart';
import '../../core/settings/settings.dart';
import '../../core/social/chat_service.dart';
import '../../engine/render/palette.g.dart';
import '../../l10n/app_localizations.dart';

/// Global, squadron and friends chat with moderation. Under 16: no access.
/// 16-17: quick messages only. 18+: free text through the filter.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String _channel = 'global';
  final _text = TextEditingController();
  String? _status;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _channelId {
    final lang = Localizations.localeOf(context).languageCode;
    return _channel == 'global' ? 'global_$lang' : _channel;
  }

  Future<void> _send(String text, {bool emote = false}) async {
    final l = AppLocalizations.of(context);
    final r = await ref
        .read(chatServiceProvider)
        .send(_channelId, text, emote: emote);
    setState(() {
      _status = switch (r) {
        SendStatus.sent => null,
        SendStatus.filtered => l.chatFiltered,
        SendStatus.rateLimited => l.chatSlowDown,
        SendStatus.muted => l.chatMuted,
        SendStatus.offline => l.chatOffline,
        SendStatus.notAllowed => l.onlineUnder16,
      };
      if (r == SendStatus.sent) _text.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider);
    final settings = ref.watch(settingsProvider);
    final now = DateTime.now();
    Widget body;
    if (!settings.chatEnabled) {
      body = Center(child: PixelText(l.chatDisabled));
    } else if (!profile.canGoOnline(now)) {
      body = Center(child: PixelText(l.onlineUnder16));
    } else {
      body = _chat(l, profile.isAdult(now));
    }
    return PixelScreen(title: l.menuChat, child: body);
  }

  Widget _chat(AppLocalizations l, bool adult) {
    final chat = ref.watch(chatServiceProvider);
    final emotes = [
      l.emoteNiceShot,
      l.emoteHelpBoss,
      l.emoteGG,
      l.emoteHi,
      l.emoteThanks,
      l.emoteOneMore,
    ];
    final kills = ref.watch(progressProvider).stat('kills');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (id, name) in [
                  ('global', l.chatGlobal),
                  ('squad_orbit', l.chatSquadron),
                  ('friends', l.chatFriends),
                ]) ...[
                  PixelButton(
                    label: name,
                    width: double.infinity,
                    color: _channel == id ? Pal.gold7 : Pal.ink6,
                    onPressed: () => setState(() => _channel = id),
                  ),
                  const SizedBox(height: 4),
                ],
                if (chat.isDemo)
                  const PixelText(
                    'DEMO OFFLINE',
                    scale: 0.7,
                    color: Pal.ember5,
                  ),
                if (_channel == 'squad_orbit') ...[
                  const SizedBox(height: 8),
                  PixelText(l.squadGoal, scale: 0.7, color: Pal.aqua6),
                  PixelText(
                    '${(kills % 10000)}/10000',
                    scale: 0.8,
                    color: Pal.gold6,
                  ),
                  Container(
                    height: 8,
                    width: 180,
                    color: Pal.ink2,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 8,
                      width: 180 * ((kills % 10000) / 10000),
                      color: Pal.moss5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<ChatMessage>>(
                    key: ValueKey(_channelId),
                    stream: chat.watch(_channelId),
                    builder: (context, snap) {
                      final msgs = snap.data ?? const [];
                      return ListView(
                        reverse: true,
                        children: [
                          for (final m in msgs.reversed)
                            Row(
                              children: [
                                Expanded(
                                  child: PixelText(
                                    '${m.nick}: ${m.text}',
                                    scale: 0.8,
                                    color: m.user == 'me'
                                        ? Pal.gold6
                                        : Pal.ink7,
                                  ),
                                ),
                                if (m.user != 'me') ...[
                                  PixelButton(
                                    label: l.chatReport,
                                    scale: 0.5,
                                    onPressed: () async {
                                      await chat.report(m);
                                      if (mounted) {
                                        setState(() => _status = l.reported);
                                      }
                                    },
                                  ),
                                  PixelButton(
                                    label: l.chatBlock,
                                    scale: 0.5,
                                    onPressed: () async {
                                      await chat.block(m.user);
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                ],
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                ),
                if (_status != null)
                  PixelText(_status!, scale: 0.7, color: Pal.ember5),
                if (!adult)
                  PixelText(l.chatEmotesOnly, scale: 0.6, color: Pal.ink5),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final e in emotes)
                      PixelButton(
                        label: e,
                        scale: 0.6,
                        onPressed: () => _send(e, emote: true),
                      ),
                  ],
                ),
                if (adult)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          maxLength: 140,
                          style: PixelText.style(scale: 0.8),
                          decoration: const InputDecoration(
                            counterText: '',
                            isDense: true,
                            filled: true,
                            fillColor: Pal.ink1,
                          ),
                          onSubmitted: _send,
                        ),
                      ),
                      PixelButton(
                        label: l.chatSend,
                        onPressed: () => _send(_text.text),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
