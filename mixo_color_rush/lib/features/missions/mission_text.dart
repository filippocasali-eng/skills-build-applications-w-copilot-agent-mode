import '../../core/models/missions.dart';
import '../../game/systems/color_system.dart';
import '../../l10n/generated/app_localizations.dart';

String colorName(AppLocalizations l, GameColor c) => switch (c) {
  GameColor.red => l.colorRed,
  GameColor.yellow => l.colorYellow,
  GameColor.blue => l.colorBlue,
  GameColor.orange => l.colorOrange,
  GameColor.green => l.colorGreen,
  GameColor.purple => l.colorPurple,
  GameColor.brown => l.colorBrown,
};

String missionText(AppLocalizations l, Mission m) => switch (m.kind) {
  MissionKind.colorGates => l.mColorGates(m.target, colorName(l, m.color!)),
  MissionKind.combo => l.mCombo(m.target),
  MissionKind.survive => l.mSurvive(m.target),
  MissionKind.score => l.mScore(m.target),
  MissionKind.drops => l.mDrops(m.target),
  MissionKind.nearMiss => l.mNearMiss(m.target),
  MissionKind.runs => l.mRuns(m.target),
  MissionKind.mixGates => l.mMixGates(m.target),
  MissionKind.jumps => l.mJumps(m.target),
};
