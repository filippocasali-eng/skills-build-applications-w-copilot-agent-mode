import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/pixel.dart';
import '../../core/monetization/wallet.dart';
import '../../core/profile/profile.dart';
import '../../core/progress/progress.dart';
import '../../core/providers.dart';
import '../../core/settings/settings.dart';
import '../../engine/render/palette.g.dart';
import '../../l10n/app_localizations.dart';

/// Short-form privacy notice (the full policy lives in PRIVACY.md and on
/// the store listing) and the "delete my data" action.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  static const _it = '''
ORBIT COMMANDO '94 funziona offline. Salviamo sul tuo telefono: progressi, impostazioni e acquisti.
Senza il tuo consenso non usiamo l'ID pubblicitario: la scelta si fa nel modulo di consenso (UMP) e si può cambiare in Impostazioni.
Le statistiche anonime sono disattivate finché non le accendi.
Chat (solo 16+ con account): i messaggi passano da un filtro automatico, si possono segnalare e bloccare; i log si conservano 30 giorni.
Acquisti: gestiti da Google Play; teniamo lo storico sul dispositivo e, con il backend attivo, la verifica dello scontrino.
Puoi cancellare tutti i dati locali con il pulsante qui sotto.''';

  static const _en = '''
ORBIT COMMANDO '94 works offline. We store on your phone: progress, settings and purchases.
Without your consent we don't use the advertising ID: you choose in the consent form (UMP) and can change it in Settings.
Anonymous stats stay off until you turn them on.
Chat (16+ with an account only): messages pass an automatic filter and can be reported and blocked; logs are kept for 30 days.
Purchases: handled by Google Play; we keep the history on the device and, with the backend on, receipt validation.
You can delete all local data with the button below.''';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final it = Localizations.localeOf(context).languageCode == 'it';
    return PixelScreen(
      title: l.privacyPolicy,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          PixelText(it ? _it : _en, scale: 0.8),
          const SizedBox(height: 16),
          PixelButton(
            label: l.deleteData,
            color: Pal.ember5,
            onPressed: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: Pal.ink1,
                  content: PixelText(l.deleteData, color: Pal.ember5),
                  actions: [
                    PixelButton(
                      label: l.no,
                      onPressed: () => Navigator.of(c).pop(false),
                    ),
                    PixelButton(
                      label: l.yes,
                      onPressed: () => Navigator.of(c).pop(true),
                    ),
                  ],
                ),
              );
              if (yes != true) return;
              final store = ref.read(saveStoreProvider);
              for (final s in const [
                'progress',
                'wallet',
                'profile',
                'ghosts',
                'settings',
                'chat',
              ]) {
                store.section(s).clear();
              }
              await store.flush();
              ref
                ..invalidate(progressProvider)
                ..invalidate(walletProvider)
                ..invalidate(profileProvider)
                ..invalidate(settingsProvider);
              if (context.mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }
}
