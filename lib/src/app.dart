import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';

/// Root application widget configuring theme and GoRouter
class RoadixApp extends ConsumerWidget {
  const RoadixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appTitle,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.porcelainBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.caliperCrimson,
          primary: AppColors.caliperCrimson,
          surface: AppColors.porcelainBg,
        ),
        fontFamily: 'sans-serif',
        useMaterial3: true,
      ),
    );
  }
}
