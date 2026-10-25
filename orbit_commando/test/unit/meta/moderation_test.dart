import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/core/profile/profile.dart';
import 'package:orbit_commando/core/social/moderation.dart';

void main() {
  test('blocks profanity in IT and EN, also disguised', () {
    for (final t in [
      'you are a b1tch',
      'che stronzo',
      'F.U.C.K this',
      'VAFFANCULO',
      'c4zz0',
    ]) {
      expect(ChatFilter.check(t).reason, FilterReason.profanity, reason: t);
    }
  });

  test('blocks phone numbers, e-mails and links', () {
    expect(
      ChatFilter.check('call me +39 333 123 4567').reason,
      FilterReason.phone,
    );
    expect(
      ChatFilter.check('mail pippo@example.com').reason,
      FilterReason.email,
    );
    expect(ChatFilter.check('go to www.sito.it').reason, FilterReason.link);
    expect(ChatFilter.check('http://x.y/z').reason, FilterReason.link);
  });

  test('lets normal game talk through', () {
    for (final t in [
      'GG!',
      'Aiuto col boss?',
      'Level 3 is hard',
      'ho fatto 120000 punti',
    ]) {
      expect(ChatFilter.check(t).allowed, isTrue, reason: t);
    }
  });

  test('rate limit: 1 message every 3 seconds', () {
    final r = RateLimiter();
    final t0 = DateTime(2026);
    expect(r.tryAcquire(t0), isTrue);
    expect(r.tryAcquire(t0.add(const Duration(seconds: 2))), isFalse);
    expect(r.tryAcquire(t0.add(const Duration(seconds: 3))), isTrue);
  });

  test('automatic mute after reports from several users', () {
    final r = ReportTracker(threshold: 3);
    final t = DateTime(2026);
    expect(r.report(target: 'x', by: 'a', now: t), isFalse);
    expect(
      r.report(target: 'x', by: 'a', now: t),
      isFalse,
      reason: 'same reporter twice',
    );
    expect(r.report(target: 'x', by: 'b', now: t), isFalse);
    expect(r.report(target: 'x', by: 'c', now: t), isTrue);
    expect(r.isMuted('x', t.add(const Duration(minutes: 30))), isTrue);
    expect(r.isMuted('x', t.add(const Duration(hours: 2))), isFalse);
  });

  test('age gate: online from 16, paid capsules and free chat from 18', () {
    final now = DateTime(2026, 6, 15);
    const p15 = Profile(birthYear: 2011, birthMonth: 1);
    const p17 = Profile(birthYear: 2009, birthMonth: 1);
    const p18 = Profile(birthYear: 2008, birthMonth: 6);
    const notYet18 = Profile(birthYear: 2008, birthMonth: 7);
    expect(p15.canGoOnline(now), isFalse);
    expect(p17.canGoOnline(now), isTrue);
    expect(p17.isAdult(now), isFalse);
    expect(p18.isAdult(now), isTrue);
    expect(notYet18.isAdult(now), isFalse);
  });
}
