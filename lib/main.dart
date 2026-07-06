import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/splash_screen.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // ignore: avoid_print
      print('=== FLUTTER ERROR ===\n${details.exceptionAsString()}\n${details.stack}');
    };

    await initializeDateFormatting('es', null);
    runApp(const AndryPrestamosApp());
  }, (Object error, StackTrace stack) {
    // ignore: avoid_print
    print('=== ZONE ERROR ===\n$error\n$stack');
  });
}

/// NOTE: La clase mantiene el nombre `AndryPrestamosApp` por compatibilidad
/// con el resto del codigo, pero la marca visible en toda la app y en los
/// documentos generados es "Y&Y PRESTAMOS".
class AndryPrestamosApp extends StatelessWidget {
  const AndryPrestamosApp({super.key});

  // =====================================================================
  //          PALETA OFICIAL Y&Y PRESTAMOS (v2.2.0)
  // ---------------------------------------------------------------------
  //  Identidad visual del logo:
  //    · Azul marino (Y izquierda)  → color principal / institucional
  //    · Verde vibrante (Y derecha) → color de acento y confirmaciones
  //    · Blanco                     → contraste
  //    · Gris carbón                → texto "PRESTAMOS"
  //
  //  Los tonos oscuros que se usaban antes (verde-militar) fueron
  //  reemplazados por tonos AZUL MARINO en todos los fondos, tarjetas
  //  y superficies para respetar la identidad de la marca.
  // =====================================================================

  // Azul marino (identidad principal)
  static const Color azulPrincipal = Color(0xFF1A3A6B); // "Y" azul del logo
  static const Color azulOscuro = Color(0xFF0D1B33); // fondo principal
  static const Color azulProfundo =
      Color(0xFF08132A); // fondo más oscuro / splash
  static const Color azulClaro = Color(0xFF2E5AA0); // acentos claros / hover
  static const Color azulSuperficie = Color(0xFF16233A); // tarjetas / cards
  static const Color azulSuperficieAlt =
      Color(0xFF1E2E4A); // inputs / superficies alt

  // Verde institucional (acento)
  static const Color verdePrincipal = Color(0xFF2E9E3A); // "Y" verde del logo
  static const Color verdeOscuro = Color(0xFF1B6B27); // sombra del verde
  static const Color verdeClaro = Color(0xFF43A047); // éxito / al día

  // Semánticos
  static const Color dorado = Color(0xFFFFC107); // resaltados premium
  static const Color doradoOscuro = Color(0xFFFFA000);
  static const Color rojoMora = Color(0xFFD32F2F);
  static const Color naranjaAlerta = Color(0xFFFB8C00);
  static const Color rojoRetiro = Color(0xFFEF5350);
  static const Color azulInfo = Color(0xFF4FC3F7);

  // ===== Marca =====
  static const String nombreNegocio = 'Y&Y PRESTAMOS';
  static const String telefonoDueno = '829-796-4283';

  // Ruta al logo (empaquetado como asset).
  static const String logoAsset = 'assets/images/yy_logo.png';
  static const String logoAssetSmall = 'assets/images/yy_logo_small.png';
  static const String logoAssetBw = 'assets/images/yy_logo_bw.png';

  static const String creadorSistema = 'J.F.B SYSTEM';
  static const String creadorTelefono = '809-798-3301';
  static String get creadorFirma => '$creadorSistema - $creadorTelefono';

  static const String versionApp = '2.2.0';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: nombreNegocio,
      debugShowCheckedModeBanner: false,
      // SafeArea global: evita que el contenido quede debajo del notch, la
      // Dynamic Island o la barra inferior (home indicator) de iPhone.
      // `top: false` porque cada pantalla ya usa AppBar (que respeta el
      // notch por su cuenta); lo que casi nunca se maneja pantalla-por-
      // pantalla es el borde INFERIOR, así que se protege aquí una sola vez.
      builder: (context, child) {
        return SafeArea(
          top: false,
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: azulPrincipal,
          onPrimary: Colors.white,
          secondary: verdePrincipal,
          onSecondary: Colors.white,
          tertiary: dorado,
          onTertiary: azulOscuro,
          surface: azulSuperficie,
          onSurface: Colors.white,
          error: rojoMora,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: azulOscuro,
        appBarTheme: const AppBarTheme(
          backgroundColor: azulOscuro,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: azulSuperficie,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: verdePrincipal,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: azulPrincipal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: verdePrincipal,
            side: const BorderSide(color: verdePrincipal),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: dorado,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: azulClaro, width: 2),
          ),
          filled: true,
          fillColor: azulSuperficieAlt,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixIconColor: Colors.white54,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: azulSuperficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
          contentTextStyle: const TextStyle(color: Colors.white70),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: azulSuperficie,
          contentTextStyle: TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: azulSuperficieAlt,
          selectedColor: verdePrincipal,
          labelStyle: const TextStyle(color: Colors.white),
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white70),
          bodyLarge: TextStyle(color: Colors.white),
          titleMedium:
              TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        dividerColor: Colors.white12,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      home: const SplashScreen(),
    );
  }
}
