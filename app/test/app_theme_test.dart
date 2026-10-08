import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/main.dart';
import 'package:shift_diary/src/day/day_screen.dart';
import 'package:shift_diary/src/theme/app_theme.dart';

import 'fakes.dart';

void main() {
  Future<AppColors> colorsFor(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(ShiftDiaryApp(api: FakeApiClient()));
    await tester.pumpAndSettle();
    return AppColors.of(tester.element(find.byType(DayScreen)));
  }

  testWidgets('uses the dark palette when the system is dark', (tester) async {
    final colors = await colorsFor(tester, Brightness.dark);
    expect(colors.net, AppColors.dark.net);
    expect(colors.surfaceCard, AppColors.dark.surfaceCard);
  });

  testWidgets('uses the light palette when the system is light', (
    tester,
  ) async {
    final colors = await colorsFor(tester, Brightness.light);
    expect(colors.net, AppColors.light.net);
    expect(colors.surfaceCard, AppColors.light.surfaceCard);
  });
}
