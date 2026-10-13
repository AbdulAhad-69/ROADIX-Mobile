import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_colors.dart';
import 'screens/splash_screen.dart';

// Top-level shortcut to access the Supabase client anywhere in the app
final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock status bar to dark icons on Showroom Porcelain background
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Initialize Supabase Client
  // Replace these placeholder strings with your actual Project URL & Public Anon Key
  // from: Supabase Dashboard -> Project Settings -> API
  await Supabase.initialize(
    url: 'https://rgzmoqpkugpcqfryrjkj.supabase.co', // Replace with your Project URL
    anonKey: 'sb_publishable_Brh5ctiNGrTdmKlVG2sHwA_aFWPlkAt', // Replace with your Public Anon Key
  );

  runApp(const RoadixApp());
}

class RoadixApp extends StatelessWidget {
  const RoadixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROADIX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.porcelainBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.caliperCrimson,
          primary: AppColors.caliperCrimson,
          background: AppColors.porcelainBg,
        ),
        fontFamily: 'sans-serif',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}