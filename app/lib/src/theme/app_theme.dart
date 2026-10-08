import 'package:flutter/material.dart';

/// App colours that Material's [ColorScheme] has no slot for.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.net,
    required this.cash,
    required this.card,
    required this.surfaceCard,
    required this.inputFill,
    required this.muted,
    required this.onAccent,
  });

  /// Take-home amount; also the primary accent.
  final Color net;

  /// Cash payments.
  final Color cash;

  /// Card payments.
  final Color card;

  /// Background of cards.
  final Color surfaceCard;

  /// Background of text inputs and the payment toggle.
  final Color inputFill;

  /// Secondary text.
  final Color muted;

  /// Text and icons drawn on net/cash/card fills.
  final Color onAccent;

  static const dark = AppColors(
    net: Color(0xFF2BB673),
    cash: Color(0xFFE0A33A),
    card: Color(0xFF5A9CF0),
    surfaceCard: Color(0xFF1F2228),
    inputFill: Color(0xFF181B20),
    muted: Color(0xFF9AA0A8),
    onAccent: Color(0xFF0B1F14),
  );

  static const light = AppColors(
    net: Color(0xFF167A48),
    cash: Color(0xFF9A5F00),
    card: Color(0xFF2563B8),
    surfaceCard: Color(0xFFFFFFFF),
    inputFill: Color(0xFFF7F8FA),
    muted: Color(0xFF5F6670),
    onAccent: Color(0xFFFFFFFF),
  );

  /// Colours of the current theme; light colours when the theme has none
  /// (e.g. a bare `MaterialApp` in widget tests).
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({
    Color? net,
    Color? cash,
    Color? card,
    Color? surfaceCard,
    Color? inputFill,
    Color? muted,
    Color? onAccent,
  }) => AppColors(
    net: net ?? this.net,
    cash: cash ?? this.cash,
    card: card ?? this.card,
    surfaceCard: surfaceCard ?? this.surfaceCard,
    inputFill: inputFill ?? this.inputFill,
    muted: muted ?? this.muted,
    onAccent: onAccent ?? this.onAccent,
  );

  @override
  AppColors lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      net: Color.lerp(net, other.net, t)!,
      cash: Color.lerp(cash, other.cash, t)!,
      card: Color.lerp(card, other.card, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

/// App theme for [brightness]: the mock's dark palette or its light twin.
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? AppColors.dark : AppColors.light;
  final background = isDark ? const Color(0xFF14161A) : const Color(0xFFF4F5F7);
  final outline = isDark ? const Color(0xFF2E323A) : const Color(0xFFE1E4E8);
  final text = isDark ? const Color(0xFFECEEF1) : const Color(0xFF15171A);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: colors.net,
        brightness: brightness,
      ).copyWith(
        primary: colors.net,
        onPrimary: colors.onAccent,
        surface: background,
        // Neutral dialog surfaces: the seed-tinted defaults pull the green
        // primary below AA on light.
        surfaceDim: isDark ? background : outline,
        surfaceBright: colors.surfaceCard,
        surfaceContainerLowest: colors.surfaceCard,
        surfaceContainerLow: colors.surfaceCard,
        surfaceContainer: colors.surfaceCard,
        surfaceContainerHigh: colors.surfaceCard,
        surfaceContainerHighest: colors.surfaceCard,
        onSurface: text,
        onSurfaceVariant: colors.muted,
        outline: outline,
        outlineVariant: outline,
      );

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    extensions: [colors],
    appBarTheme: AppBarThemeData(
      backgroundColor: background,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark ? BorderSide.none : BorderSide(color: outline),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colors.inputFill,
      border: border(outline),
      enabledBorder: border(outline),
      focusedBorder: border(colors.net, 1.5),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.net,
        foregroundColor: colors.onAccent,
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.net,
      foregroundColor: colors.onAccent,
      shape: const CircleBorder(),
    ),
    dividerTheme: DividerThemeData(color: outline),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.onAccent
            : colors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.net
            : colors.inputFill,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : colors.muted,
      ),
    ),
  );
}
