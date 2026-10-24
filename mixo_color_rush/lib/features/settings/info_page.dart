import 'package:flutter/material.dart';

import '../../core/widgets/common.dart';

/// Static text page (privacy policy, credits). Local only, no links.
class InfoPage extends StatelessWidget {
  const InfoPage({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return MixoPage(
      title: title,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(body, style: const TextStyle(fontSize: 17, height: 1.45)),
        ],
      ),
    );
  }
}
