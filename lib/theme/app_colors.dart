import 'package:flutter/material.dart';

class AppColors {
  // Showroom Porcelain Palette
  static const Color porcelainBg = Color(0xFFF8FAFC);
  static const Color chassisText = Color(0xFF0F172A);
  static const Color caliperCrimson = Color(0xFFDC2626);
  static const Color crimsonHover = Color(0xFFB91C1C); // 5.28:1 on #FEE2E2, 6.47:1 on white
  static const Color crimsonLight = Color(0xFFFEE2E2);
  static const Color crimsonBorder = Color(0xFFFCA5A5);
  static const Color slateMuted = Color(0xFF475569); // 7.5:1 on white (accessible muted ink)
  static const Color slateSubtle = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color surfaceTint = Color(0xFFF1F5F9);

  // Semantic Status Tokens (WCAG AA compliant foreground + light surface pairs)
  static const Color emeraldGps = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF047857); // >= 4.5:1 on #ECFDF5 & #FFFFFF
  static const Color emeraldLight = Color(0xFFECFDF5);
  static const Color emeraldBorder = Color(0xFFA7F3D0);
  static const Color amberDark = Color(0xFF92400E); // >= 6.5:1 on #FEF3C7
  static const Color amberLight = Color(0xFFFFFBEB);
  static const Color amberBorder = Color(0xFFFDE68A);

  // Authentic Brand Identity Tokens
  static const Color bkashCrimson = Color(0xFFD12053);
  static const Color bkashPink = Color(0xFFE2136E);
  static const Color bkashPrimary = bkashPink;
  static const Color bkashDeep = bkashCrimson;
}
