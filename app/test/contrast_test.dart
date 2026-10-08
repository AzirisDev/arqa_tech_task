import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/src/day/trip_card.dart';
import 'package:shift_diary/src/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final b in [Brightness.dark, Brightness.light]) {
    group('WCAG AA contrast (${b.name})', () {
      final theme = buildAppTheme(b);
      final colors = theme.extension<AppColors>()!;
      final surfaces = [colors.surfaceCard, theme.scaffoldBackgroundColor];

      test('text colours on surfaces (${b.name})', () {
        final texts = [
          colors.net,
          colors.cash,
          colors.card,
          colors.muted,
          theme.colorScheme.onSurface,
        ];
        for (final t in texts) {
          for (final s in surfaces) {
            expect(
              contrast(t, s),
              greaterThanOrEqualTo(4.5),
              reason: 'text $t on surface $s',
            );
          }
        }
      });

      test('onAccent on accents (${b.name})', () {
        for (final a in [colors.net, colors.cash, colors.card]) {
          expect(
            contrast(colors.onAccent, a),
            greaterThanOrEqualTo(4.5),
            reason: 'onAccent on accent $a',
          );
        }
      });

      test('payment chip text on tint (${b.name})', () {
        for (final accent in [colors.cash, colors.card]) {
          final bg = Color.alphaBlend(
            accent.withValues(alpha: paymentChipTint),
            colors.surfaceCard,
          );
          expect(
            contrast(accent, bg),
            greaterThanOrEqualTo(4.5),
            reason: 'chip $accent on tint $bg',
          );
        }
      });
    });
  }
}
