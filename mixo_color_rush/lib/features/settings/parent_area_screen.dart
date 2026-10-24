import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/profile_controller.dart';
import '../../core/providers.dart';
import '../../core/services/wellbeing.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import 'info_page.dart';

/// Parent area (reached only through the parental gate).
class ParentAreaScreen extends ConsumerWidget {
  const ParentAreaScreen({super.key});

  static const limits = [0, 15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(profileProvider);
    final ctrl = ref.read(profileProvider.notifier);
    final now = ref.watch(clockProvider)();
    final todayMin = Wellbeing.todayMs(p, now) ~/ 60000;
    return MixoPage(
      title: l.parentArea,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MixoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.dailyLimit,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  l.playedToday(todayMin),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in limits)
                      ChoiceChip(
                        key: Key('limit-$m'),
                        label: Text(m == 0 ? l.noLimit : '$m min'),
                        selected: p.parent.dailyLimitMinutes == m,
                        onSelected: (_) =>
                            ctrl.update((p) => p.parent.dailyLimitMinutes = m),
                      ),
                  ],
                ),
                if (p.parent.dailyLimitMinutes > 0) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => ctrl.update((p) {
                      Wellbeing.addPlay(p, 0, now);
                      p.limitExtensionMinutes += 15;
                    }),
                    icon: const Icon(Icons.more_time_rounded),
                    label: Text(l.extend15),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          MixoCard(
            child: SwitchListTile(
              key: const Key('purchases-enabled'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l.purchasesEnabled,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(l.purchasesInfo),
              value: p.parent.purchasesEnabled,
              onChanged: (v) =>
                  ctrl.update((p) => p.parent.purchasesEnabled = v),
            ),
          ),
          const SizedBox(height: 12),
          MixoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: MixoColors.mint,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.parentPrivacyTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(l.parentPrivacyBody),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          InfoPage(title: l.privacy, body: l.privacyText),
                    ),
                  ),
                  child: Text(l.privacy),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MixoCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.delete_forever_rounded,
                color: MixoColors.candy,
              ),
              title: Text(l.resetProgress),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l.resetProgress),
                    content: Text(l.resetConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l.reset),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  final store = ref.read(storeProvider);
                  await store.remove('mixo.profile');
                  await store.remove('mixo.profile.bak');
                  ref.invalidate(profileProvider);
                  if (context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
