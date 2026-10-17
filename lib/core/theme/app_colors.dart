import 'package:flutter/material.dart';

/// CheraSakhi — feminine luxury palette: Berry Velvet + Rose Gold + Blush.
class AppColors {
  AppColors._();

  // Berry Velvet (primary)
  static const berry = Color(0xFF831843);
  static const berryMid = Color(0xFFA21C5B);
  static const blossom = Color(0xFFEC4899); // highlights, "paid" state

  // Rose Gold (accent / metallic)
  static const roseGold = Color(0xFFB76E79);
  static const roseGoldLight = Color(0xFFE8A598);
  static const roseGoldPale = Color(0xFFF9D7CF);
  static const blush = Color(0xFFFDECEE);

  // Lavender (secondary soft tone)
  static const lavender = Color(0xFFC4B5FD);

  // Backgrounds
  static const milk = Color(0xFFFFF7F9);
  static const night = Color(0xFF1C1020);
  static const nightSurface = Color(0xFF2A1830);

  static const danger = Color(0xFFDC2626);
  static const whatsapp = Color(0xFF25D366);

  static const roseGoldGradient = LinearGradient(
    colors: [Color(0xFFF2C4B8), Color(0xFFD4918F), Color(0xFFB76E79)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const berryGradient = LinearGradient(
    colors: [Color(0xFFA21C5B), Color(0xFF831843), Color(0xFF4A0D2B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
