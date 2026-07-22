import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Awfar CC — Midnight Indigo theme.
class AppTheme {
  AppTheme._();

  // Brand palette
  static const Color brandPrimary = Color(0xFF4F46E5); // electric indigo
  static const Color brandAccent = Color(0xFF6366F1);
  static const Color brandDanger = Color(0xFFEF4444);
  static const Color brandSuccess = Color(0xFF22C55E);
  static const Color brandWarning = Color(0xFFF59E0B);

  // Dark surfaces
  static const Color bgDark = Color(0xFF0A0A1A);
  static const Color surfaceDark = Color(0xFF141432);
  static const Color borderDark = Color(0xFF1E1E5A);
  static const Color textMuted = Color(0xFF94A3B8);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF1E1E5A)],
  );

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: brightness,
      primary: brandPrimary,
      onPrimary: Colors.white,
      secondary: brandAccent,
      onSecondary: Colors.white,
      error: brandDanger,
      onError: Colors.white,
      surface: isDark ? surfaceDark : Colors.white,
      onSurface: isDark ? Colors.white : const Color(0xFF0F172A),
      onSurfaceVariant: isDark ? textMuted : const Color(0xFF64748B),
      outline: isDark ? borderDark : const Color(0xFFE2E8F0),
      surfaceContainerHighest:
          isDark ? const Color(0xFF1A1A3E) : const Color(0xFFF1F5F9),
    );

    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final scaffold = isDark ? bgDark : const Color(0xFFF4F6FA);
    final cardColor = isDark ? surfaceDark : Colors.white;
    final borderColor = isDark ? borderDark : const Color(0xFFE2E8F0);
    final mutedText = isDark ? textMuted : const Color(0xFF64748B);

    final textTheme = GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, letterSpacing: -1),
      displayMedium: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, letterSpacing: -0.8),
      displaySmall: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineSmall: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, letterSpacing: -0.2),
    ).apply(
      bodyColor: isDark ? Colors.white : const Color(0xFF0F172A),
      displayColor: isDark ? Colors.white : const Color(0xFF0F172A),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xFF0F172A)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        labelStyle: TextStyle(color: isDark ? textMuted : const Color(0xFF475569)),
        hintStyle: TextStyle(color: isDark ? textMuted.withOpacity(0.7) : const Color(0xFF94A3B8)),
        prefixIconColor: isDark ? textMuted : const Color(0xFF64748B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandPrimary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF0F0F26) : Colors.white,
        indicatorColor: brandPrimary.withValues(alpha: isDark ? 0.18 : 0.12),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: isDark ? Colors.white : brandPrimary);
          }
          return IconThemeData(color: mutedText);
        }),
        height: 68,
        elevation: isDark ? 0 : 2,
        shadowColor: isDark ? Colors.transparent : Colors.black12,
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: mutedText,
        textColor: scheme.onSurface,
        tileColor: cardColor,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? surfaceDark : const Color(0xFF1E293B),
        contentTextStyle: GoogleFonts.dmSans(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF1A1A3E) : const Color(0xFFF1F5F9),
        selectedColor: brandPrimary.withValues(alpha: 0.18),
        labelStyle: GoogleFonts.dmSans(color: scheme.onSurface),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.dmSans(color: scheme.onSurface),
      ),
      iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xFF334155)),
    );
  }
}
