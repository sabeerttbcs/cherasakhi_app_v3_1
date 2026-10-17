import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.berry,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.blossom : AppColors.berry,
      onPrimary: Colors.white,
      secondary: AppColors.roseGoldLight,
      onSecondary: Colors.white,
      tertiary: AppColors.roseGold,
      surface: isDark ? AppColors.nightSurface : Colors.white,
      error: AppColors.danger,
    );

    final ink = isDark ? const Color(0xFFF5E6EC) : const Color(0xFF3B0A20);
    final base = GoogleFonts.poppinsTextTheme(ThemeData(brightness: brightness).textTheme)
        .apply(bodyColor: ink, displayColor: ink);

    TextStyle display(TextStyle? s, FontWeight w) =>
        GoogleFonts.playfairDisplay(textStyle: s, fontWeight: w);

    // Strict hierarchy: Playfair Display (elegant serif) for Display/Headline/Title,
    // Poppins for Body/Caption.
    final text = base.copyWith(
      displayLarge: display(base.displayLarge, FontWeight.w700),
      displayMedium: display(base.displayMedium, FontWeight.w700),
      displaySmall: display(base.displaySmall, FontWeight.w700),
      headlineLarge: display(base.headlineLarge, FontWeight.w700),
      headlineMedium: display(base.headlineMedium, FontWeight.w700),
      headlineSmall: display(base.headlineSmall, FontWeight.w700),
      titleLarge: display(base.titleLarge, FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3),
      bodySmall: base.bodySmall?.copyWith(color: ink.withOpacity(0.6)),
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.night : AppColors.milk,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: ink,
        titleTextStyle: text.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.nightSurface : Colors.white,
        indicatorColor: AppColors.roseGoldLight.withOpacity(0.22),
        elevation: 0,
        height: 70,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : AppColors.berry.withOpacity(0.04),
        border: border(Colors.transparent),
        enabledBorder: border(ink.withOpacity(0.07)),
        focusedBorder: border(scheme.primary, 1.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: text.labelLarge,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.nightSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}
