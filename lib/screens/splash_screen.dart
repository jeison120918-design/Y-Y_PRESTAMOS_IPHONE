import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../main.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _scaleCtrl.forward();
    Future.delayed(
        const Duration(milliseconds: 300), () => _fadeCtrl.forward());
    _decidirRuta();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _decidirRuta() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    final configurado = await DBHelper().hayPrestamistaConfigurado();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            configurado ? const HomeScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AndryPrestamosApp.azulProfundo,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AndryPrestamosApp.azulProfundo,
              AndryPrestamosApp.azulOscuro,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color:
                            AndryPrestamosApp.azulPrincipal.withOpacity(0.55),
                        blurRadius: 32,
                        spreadRadius: 6,
                      ),
                      BoxShadow(
                        color:
                            AndryPrestamosApp.verdePrincipal.withOpacity(0.35),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Image.asset(
                        AndryPrestamosApp.logoAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.account_balance_wallet,
                            color: AndryPrestamosApp.azulPrincipal,
                            size: 60),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                        ),
                        children: [
                          TextSpan(
                            text: 'Y',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: '&',
                            style: TextStyle(color: Colors.white70),
                          ),
                          TextSpan(
                            text: 'Y',
                            style:
                                TextStyle(color: AndryPrestamosApp.verdeClaro),
                          ),
                        ],
                      ),
                    ),
                    const Text('PRÉSTAMOS',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          color: Colors.white70,
                          letterSpacing: 8,
                        )),
                    const SizedBox(height: 60),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AndryPrestamosApp.verdePrincipal),
                        backgroundColor:
                            AndryPrestamosApp.verdePrincipal.withOpacity(0.15),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(AndryPrestamosApp.telefonoDueno,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 14)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AndryPrestamosApp.dorado.withOpacity(0.35)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        AndryPrestamosApp.creadorFirma,
                        style: const TextStyle(
                          color: AndryPrestamosApp.dorado,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
