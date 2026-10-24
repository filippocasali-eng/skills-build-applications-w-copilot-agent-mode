import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Page scaffold with the game gradient and a big back button.
class MixoPage extends StatelessWidget {
  const MixoPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: MixoColors.night,
        foregroundColor: Colors.white,
        toolbarHeight: 64,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
        ),
        leading: IconButton(
          iconSize: 32,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: actions,
        bottom: bottom,
      ),
      body: DecoratedBox(
        decoration: mixoBackground,
        child: SafeArea(top: false, child: child),
      ),
    );
  }
}

/// Small rounded counter chip (stars, level).
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.text,
    this.color = MixoColors.sun,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// Large rounded menu tile (min 56 dp) with icon first: readable by kids
/// who don't read well yet.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = MixoColors.grape,
    this.subtitle,
    this.locked = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;
  final bool locked;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        locked ? Icons.lock_rounded : icon,
                        size: 38,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: MixoColors.candy,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wide primary button (≥ 72 dp tall).
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 80,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 36),
        label: Text(
          label,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

/// Rounded card used for panels.
class MixoCard extends StatelessWidget {
  const MixoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.black26,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12, width: 2),
      ),
      child: child,
    );
  }
}
