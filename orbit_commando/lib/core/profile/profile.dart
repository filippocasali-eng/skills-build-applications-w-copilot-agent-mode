import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Player profile: neutral age gate answer and account state.
class Profile {
  const Profile({
    this.birthYear,
    this.birthMonth,
    this.accountId,
    this.nickname = '',
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    birthYear: j['by'] as int?,
    birthMonth: j['bm'] as int?,
    accountId: j['account'] as String?,
    nickname: j['nick'] as String? ?? '',
  );

  final int? birthYear;
  final int? birthMonth;
  final String? accountId;
  final String nickname;

  bool get ageKnown => birthYear != null && birthMonth != null;

  int ageAt(DateTime now) {
    if (!ageKnown) return 0;
    var a = now.year - birthYear!;
    if (now.month < birthMonth!) a--;
    return a;
  }

  /// Online features (chat, leaderboards): 16+.
  bool canGoOnline(DateTime now) => ageAt(now) >= 16;

  /// Paid capsules and free-text chat: 18+.
  bool isAdult(DateTime now) => ageAt(now) >= 18;

  Map<String, Object?> toJson() => {
    'by': birthYear,
    'bm': birthMonth,
    'account': accountId,
    'nick': nickname,
  };

  Profile copyWith({
    int? birthYear,
    int? birthMonth,
    String? accountId,
    String? nickname,
  }) => Profile(
    birthYear: birthYear ?? this.birthYear,
    birthMonth: birthMonth ?? this.birthMonth,
    accountId: accountId ?? this.accountId,
    nickname: nickname ?? this.nickname,
  );
}

class ProfileController extends Notifier<Profile> {
  @override
  Profile build() =>
      Profile.fromJson(ref.watch(saveStoreProvider).section('profile'));

  Future<void> set(Profile Function(Profile p) change) async {
    state = change(state);
    final s = ref.read(saveStoreProvider);
    s.section('profile')
      ..clear()
      ..addAll(state.toJson());
    await s.flush();
  }
}

final profileProvider = NotifierProvider<ProfileController, Profile>(
  ProfileController.new,
);

/// Store country (ISO 3166-1 alpha-2). v1 uses the device region; with
/// Play Billing it should come from the billing config (MONETIZATION.md).
String deviceCountry() =>
    (PlatformDispatcher.instance.locale.countryCode ?? '').toUpperCase();
