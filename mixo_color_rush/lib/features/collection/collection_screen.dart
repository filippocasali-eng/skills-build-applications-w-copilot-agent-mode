import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/cosmetics.dart';
import '../../core/models/profile.dart';
import '../../core/profile_controller.dart';
import '../../core/providers.dart';
import '../../core/services/feedback.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/mixo_avatar.dart';
import '../../l10n/content.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cosmetic_swatch.dart';

/// Collection: skins, trails and tunnel themes with a live preview.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  String? _preview;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(profileProvider);
    final previewItem = _preview == null ? null : Catalog.get(_preview!);
    final skin = previewItem?.type == CosmeticType.skin
        ? previewItem!
        : Catalog.get(p.skin);
    final theme = previewItem?.type == CosmeticType.theme
        ? previewItem!
        : Catalog.get(p.theme);
    final trail = previewItem?.type == CosmeticType.trail
        ? previewItem!
        : Catalog.get(p.trail);
    final pal = Catalog.paletteOf(theme.id);
    return DefaultTabController(
      length: 3,
      child: MixoPage(
        title: l.collection,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InfoChip(icon: Icons.star_rounded, text: '${p.stars}'),
          ),
        ],
        child: Column(
          children: [
            Container(
              height: 170,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(pal.skyTop),
                    Color(pal.skyMid),
                    Color(pal.skyBottom),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MixoAvatar(size: 150, accessory: skin.accessory),
                  if (trail.trail != TrailKind.none)
                    TrailSwatch(kind: trail.trail, size: 48),
                ],
              ),
            ),
            TabBar(
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
              tabs: [
                Tab(text: l.skins),
                Tab(text: l.trails),
                Tab(text: l.themes),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _Grid(
                    type: CosmeticType.skin,
                    profile: p,
                    onPreview: _setPreview,
                  ),
                  _Grid(
                    type: CosmeticType.trail,
                    profile: p,
                    onPreview: _setPreview,
                  ),
                  _Grid(
                    type: CosmeticType.theme,
                    profile: p,
                    onPreview: _setPreview,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setPreview(String id) => setState(() => _preview = id);
}

class _Grid extends ConsumerWidget {
  const _Grid({
    required this.type,
    required this.profile,
    required this.onPreview,
  });

  final CosmeticType type;
  final PlayerProfile profile;
  final void Function(String id) onPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = Catalog.ofType(type).toList();
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) =>
          _ItemCard(item: items[i], profile: profile, onPreview: onPreview),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  const _ItemCard({
    required this.item,
    required this.profile,
    required this.onPreview,
  });

  final CosmeticItem item;
  final PlayerProfile profile;
  final void Function(String id) onPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final content = ContentText(Localizations.localeOf(context).languageCode);
    final owned = profile.unlocked.contains(item.id);
    final equipped =
        profile.skin == item.id ||
        profile.trail == item.id ||
        profile.theme == item.id;
    final String status;
    if (equipped) {
      status = l.equipped;
    } else if (owned) {
      status = l.equip;
    } else {
      status = switch (item.unlock) {
        UnlockKind.level => l.levelShort(item.level),
        UnlockKind.stars => '${item.price} ★',
        UnlockKind.product => l.inShop,
        UnlockKind.start => '',
      };
    }
    return Material(
      color: equipped ? MixoColors.grape : Colors.black26,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: Key('item-${item.id}'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => _tap(context, ref, owned),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: owned ? 1 : 0.45,
                      child: CosmeticSwatch(item: item),
                    ),
                    if (!owned) const Icon(Icons.lock_rounded, size: 28),
                  ],
                ),
              ),
              Text(
                content.item(item.id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                status,
                style: TextStyle(
                  color: equipped ? MixoColors.sun : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _tap(BuildContext context, WidgetRef ref, bool owned) async {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(profileProvider.notifier);
    onPreview(item.id);
    if (owned) {
      ctrl.equip(item.id);
      ref.read(audioProvider).sfx(Sfx.click);
      return;
    }
    if (item.unlock != UnlockKind.stars) {
      final msg = item.unlock == UnlockKind.level
          ? l.reachLevel(item.level)
          : l.findInShop;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    final content = ContentText(Localizations.localeOf(context).languageCode);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MixoColors.violet,
        title: Text(content.item(item.id)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 100, child: CosmeticSwatch(item: item)),
            Text(
              l.buyWithStars(item.price),
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const Key('confirm-buy'),
            onPressed: profile.stars >= item.price
                ? () => Navigator.pop(context, true)
                : null,
            child: Text(
              profile.stars >= item.price ? l.unlock : l.notEnoughStars,
            ),
          ),
        ],
      ),
    );
    if (confirm == true && ctrl.buy(item.id)) {
      ctrl.equip(item.id);
      ref.read(audioProvider).sfx(Sfx.unlock);
    }
  }
}
