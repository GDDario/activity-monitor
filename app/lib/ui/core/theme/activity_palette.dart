import 'package:flutter/material.dart';
import 'package:app/ui/core/theme/activity_colors.dart';

class ActivityPalette extends ThemeExtension<ActivityPalette> {
  const ActivityPalette({this.dark = false});
  final bool dark;
  static ActivityPalette of(BuildContext context) =>
      Theme.of(context).extension<ActivityPalette>() ?? const ActivityPalette();
  Color get canvas => dark ? const Color(0xff101a14) : ActivityColors.canvas;
  Color get surface => dark ? const Color(0xff1c2720) : ActivityColors.surface;
  Color get surfaceMuted =>
      dark ? const Color(0xff26342b) : ActivityColors.surfaceMuted;
  Color get surfaceStrong =>
      dark ? const Color(0xff34453b) : ActivityColors.surfaceStrong;
  Color get ink => dark ? const Color(0xffe2eae3) : ActivityColors.ink;
  Color get mutedInk =>
      dark ? const Color(0xffbecbc0) : ActivityColors.mutedInk;
  Color get outline => dark ? const Color(0xff46564a) : ActivityColors.outline;
  Color get outlineText =>
      dark ? const Color(0xffa8b9ad) : ActivityColors.outlineText;
  Color get primary => dark ? const Color(0xffa2d1b5) : ActivityColors.primary;
  Color get onPrimary => dark ? const Color(0xff102118) : Colors.white;
  Color get primaryContainer => ActivityColors.primaryContainer;
  Color get onPrimaryContainer =>
      dark ? const Color(0xffe5f5e9) : ActivityColors.onPrimaryContainer;
  Color get onContainerAction => dark ? const Color(0xffe5f5e9) : Colors.white;
  Color get primarySoft =>
      dark ? const Color(0xff294434) : ActivityColors.primarySoft;
  Color get secondary =>
      dark ? const Color(0xffffb68c) : ActivityColors.secondary;
  Color get secondarySoft =>
      dark ? const Color(0xff5b351e) : ActivityColors.secondarySoft;
  Color get onSecondaryContainer =>
      dark ? const Color(0xffffdbc9) : ActivityColors.onSecondaryContainer;
  Color get error => dark ? const Color(0xffffb4ab) : ActivityColors.error;
  Color get navigationIndicator =>
      dark ? const Color(0xff344d3d) : ActivityColors.navigationIndicator;
  Color get inputSurface => dark ? surfaceMuted : const Color(0xfff2f4f0);
  Color get border => dark ? outline : const Color(0xffe1e3df);
  Color get completionInk => dark ? primary : const Color(0xff5d8170);
  Color get neutralBadge => dark ? surfaceMuted : const Color(0xffeceeeb);
  Color get selectedBadge =>
      dark ? const Color(0xff385343) : const Color(0xffdbe5df);
  Color get mediumBadge =>
      dark ? const Color(0xff493a1e) : const Color(0xffffe8b5);
  Color get highBadge =>
      dark ? const Color(0xff4b2a24) : const Color(0xffffdbd2);
  Color get mediumInk =>
      dark ? const Color(0xffffd98f) : const Color(0xff805300);
  Color get highInk => dark ? const Color(0xffffb5a5) : const Color(0xff7c2e19);
  Color get badgeInk =>
      dark ? const Color(0xffc7e7d3) : const Color(0xff234f3a);
  Color get subtleText => dark ? mutedInk : const Color(0xff57615c);
  Color get soloIndicator => dark ? primary : primaryContainer;
  @override
  ActivityPalette copyWith({bool? dark}) =>
      ActivityPalette(dark: dark ?? this.dark);
  @override
  ActivityPalette lerp(covariant ActivityPalette? other, double t) =>
      other == null
      ? this
      : t < .5
      ? this
      : other;
}
