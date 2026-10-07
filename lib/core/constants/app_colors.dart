import 'package:flutter/material.dart';

class AppColors {
  // Brand Palette (Sesuai persis dengan versi Web)
  static const Color brandPrimary = Color(
    0xFFA65F2B,
  ); // #A65F2B (Cokelat Emas Khas)
  static const Color brandPrimaryHover = Color(0xFF87491F); // #87491F
  static const Color brandDarkBrown = Color(0xFF6B3E26); // #6B3E26
  static const Color brandEspresso = Color(
    0xFF3B2922,
  ); // #3B2922 (Heading & teks gelap)
  static const Color brandHoney = Color(0xFFF4C542); // #F4C542 (Aksen Madu)
  static const Color brandSoftCream = Color(
    0xFFFFF4DE,
  ); // #FFF4DE (Background aksen lembut)
  static const Color brandSoftCreamLight = Color(
    0xFFFFFBF2,
  ); // #FFFBF2 (Card background hangat)
  static const Color brandWarmGray = Color(
    0xFF7A726D,
  ); // #7A726D (Secondary text)
  static const Color brandPlaceholder = Color(
    0xFFA8A29D,
  ); // #A8A29D (Placeholder / hint text lembut & pudar)
  static const Color brandTextPrimary = Color.fromARGB(
    255,
    228,
    223,
    220,
  ); // #4B4541 (Primary body text)
  static const Color brandBorder = Color(
    0xFFEDE7E2,
  ); // #EDE7E2 (Border divider)
  static const Color brandNaturalGreen = Color(
    0xFF5F8D4E,
  ); // #5F8D4E (Sukses / Halal)

  // Status & UI Colors
  static const Color background = Color(
    0xFFF7F7F7,
  ); // #F7F7F7 (Background Scaffold, AppBar, StatusBar)
  static const Color surface = Colors.white;
  static const Color card = Colors.white;
  static const Color error = Color(0xFFDC2626);
  static const Color success = brandNaturalGreen;
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF2563EB);
}
