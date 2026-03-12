import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- CORES LIGHT ---
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: const Color(0xFF00A859), // Verde Academy
    scaffoldBackgroundColor: const Color(0xFFF5F7FA), // Cinza claro fundo
    cardColor: Colors.white,
    dividerColor: Colors.grey[200],

    // Textos
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.sairaCondensed(
          color: const Color(0xFF1E293B), fontWeight: FontWeight.bold),
      bodyMedium: GoogleFonts.inter(color: const Color(0xFF64748B)),
    ),

    // Esquema de Cores M3
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF00A859),
      secondary: Colors.indigo,
      surface: Colors.white,
      onSurface: Colors.black87, // Texto no fundo branco
      error: Colors.redAccent,
    ),
  );

  // --- CORES DARK ---
  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor:
        const Color(0xFF00C86A), // Verde um pouco mais claro para contraste
    scaffoldBackgroundColor: const Color(0xFF121212), // Preto fundo
    cardColor: const Color(0xFF1E1E1E), // Cinza escuro cards
    dividerColor: Colors.grey[800],

    // Textos
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.sairaCondensed(
          color: Colors.white, fontWeight: FontWeight.bold),
      bodyMedium: GoogleFonts.inter(color: Colors.grey[400]),
    ),

    // Esquema de Cores M3
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00C86A),
      secondary: Colors.indigoAccent,
      surface: Color(0xFF1E1E1E), // Superfície de cards
      onSurface: Colors.white, // Texto no fundo escuro
      error: Colors.redAccent,
    ),
  );
}
