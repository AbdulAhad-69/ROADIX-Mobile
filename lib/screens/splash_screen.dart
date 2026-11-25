import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/demo_session.dart';
import '../src/core/router/app_router.dart';
import '../theme/app_colors.dart';
import 'emergency_home_screen.dart';
import 'login_screen.dart';
import 'mechanic_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _navTimer = Timer(const Duration(milliseconds: 1600), _routeFromSplash);
  }

  Future<void> _routeFromSplash() async {
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null || DemoSession.isActive) {
      String? role = DemoSession.isActive ? DemoSession.role : null;
      if (session != null) {
        try {
          final res = await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', session.user.id)
              .maybeSingle();
          role = res?['role'] as String?;
        } catch (_) {}
      }
      if (!mounted) return;
      if (role == 'mechanic') {
        navigateRoot(
          context,
          route: AppRoutes.mechanic,
          fallbackWidget: const MechanicHomeScreen(),
        );
      } else {
        navigateRoot(
          context,
          route: AppRoutes.home,
          fallbackWidget: const EmergencyHomeScreen(),
        );
      }
    } else {
      navigateRoot(
        context,
        route: AppRoutes.login,
        fallbackWidget: const LoginScreen(),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _progressController.stop();
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 96,
                    height: 76,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.alt_route,
                      color: AppColors.caliperCrimson,
                      size: 68,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'ROADIX',
                    style: TextStyle(
                      color: AppColors.chassisText,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "HELP WHEN THE ROAD DOESN'T.",
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Container(
                width: 112,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.slateBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
                clipBehavior: Clip.antiAlias,
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return FractionallySizedBox(
                      alignment: Alignment(
                        -1.0 + (_progressController.value * 2.0),
                        0.0,
                      ),
                      widthFactor: 0.5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.caliperCrimson,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
