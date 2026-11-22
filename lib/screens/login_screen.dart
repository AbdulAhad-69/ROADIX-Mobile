import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../src/core/config/app_config.dart';
import '../src/core/utils/phone_utils.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';
import 'emergency_home_screen.dart';
import 'mechanic_home_screen.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _usePhoneAuth = true;
  bool _isSignUp = false;
  String _selectedRole = 'motorist'; // 'motorist' or 'mechanic'
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isDemoActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (data.session != null && mounted && !_isDemoActionInProgress) {
          _proceedBasedOnRole();
        }
      },
      onError: (e) {
        // Auth state stream error handled gracefully
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _proceedBasedOnRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // Must not navigate to protected screens if no active user session
      return;
    }

    String? role;
    try {
      role = await SupabaseService().getUserRole();
    } catch (_) {}

    if (role == null) {
      // Profile does not exist yet (brand new OAuth or email registration)
      final meta = user.userMetadata;
      final fullName = meta?['full_name'] as String? ??
          meta?['name'] as String? ??
          (_nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : user.email?.split('@').first ?? 'User');
      final assignedRole = _selectedRole;
      try {
        await SupabaseService().createOrUpdateProfile(
          fullName: fullName,
          phone: user.phone,
          role: assignedRole,
        );
        role = assignedRole;
      } catch (_) {
        role = assignedRole;
      }
    }

    if (!mounted) return;
    if (role == 'mechanic') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MechanicHomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EmergencyHomeScreen()),
      );
    }
  }

  void _proceedToHome() => _proceedBasedOnRole();

  Future<void> _loginAsDemoMotorist() async {
    setState(() {
      _isLoading = true;
      _isDemoActionInProgress = true;
    });
    try {
      HapticFeedback.mediumImpact();
      try {
        await SupabaseService().signInAnonymously();
      } catch (_) {}
      try {
        await SupabaseService().createOrUpdateProfile(
          fullName: 'Tanvir Ahmed',
          phone: '+8801711000001',
          role: 'motorist',
        );
      } catch (_) {}
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmergencyHomeScreen()),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDemoActionInProgress = false;
        });
      }
    }
  }

  Future<void> _loginAsDemoTechnician() async {
    setState(() {
      _isLoading = true;
      _isDemoActionInProgress = true;
    });
    try {
      HapticFeedback.mediumImpact();
      try {
        await SupabaseService().signInAnonymously();
      } catch (_) {}
      try {
        await SupabaseService().createOrUpdateProfile(
          fullName: 'Rahim Uddin',
          phone: '+8801811000011',
          role: 'mechanic',
        );
        await SupabaseService().ensureMechanicProfile(
          workshopName: 'Gulshan Auto Clinic',
          workshopAddress: 'Plot 14, Road 45, Gulshan 2, Dhaka',
        );
      } catch (_) {}
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MechanicHomeScreen()),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDemoActionInProgress = false;
        });
      }
    }
  }

  Future<void> _loginAsGuest() async {
    setState(() {
      _isLoading = true;
      _isDemoActionInProgress = true;
    });
    try {
      HapticFeedback.mediumImpact();
      try {
        await SupabaseService().signInAnonymously();
      } catch (_) {}
      try {
        await SupabaseService().createOrUpdateProfile(
          fullName: 'Guest Motorist',
          phone: '+8801700000000',
          role: 'motorist',
        );
      } catch (_) {}
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmergencyHomeScreen()),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDemoActionInProgress = false;
        });
      }
    }
  }

  void _openGuestSosSheet() {
    HapticFeedback.mediumImpact();
    final guestPhoneController = TextEditingController();
    String? localError;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.caliperCrimson.withAlpha(20),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.flash_on, color: AppColors.caliperCrimson, size: 20),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'GUEST SOS DISPATCH',
                            style: TextStyle(
                              color: AppColors.caliperCrimson,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.slateMuted, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Direct Roadside Assistance',
                    style: TextStyle(
                      color: AppColors.chassisText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'No account or password required. Please provide an active callback phone number so dispatched mechanics can call you.',
                    style: TextStyle(color: AppColors.slateMuted, fontSize: 12, height: 1.3),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.crimsonLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.crimsonBorder),
                      ),
                      child: Text(
                        localError!,
                        style: const TextStyle(color: AppColors.caliperCrimson, fontSize: 11),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: guestPhoneController,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    style: const TextStyle(color: AppColors.chassisText, fontSize: 14, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Callback Mobile Number',
                      hintText: '017XXXXXXXX',
                      prefixText: '+880 ',
                      prefixStyle: const TextStyle(color: AppColors.chassisText, fontWeight: FontWeight.bold),
                      prefixIcon: const Icon(Icons.phone, color: AppColors.slateMuted, size: 20),
                      filled: true,
                      fillColor: AppColors.porcelainBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.slateBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.slateBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.caliperCrimson, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final raw = guestPhoneController.text.trim();
                              final normalized = PhoneUtils.normalize(raw);
                              if (!PhoneUtils.isValidBangladeshPhone(normalized)) {
                                setSheetState(() {
                                  localError = 'Please enter a valid 11-digit Bangladesh phone (e.g. 01712345678)';
                                });
                                return;
                              }

                              setSheetState(() {
                                isSubmitting = true;
                                localError = null;
                              });

                              try {
                                HapticFeedback.mediumImpact();
                                await SupabaseService().signInAnonymously();
                                await SupabaseService().createOrUpdateProfile(
                                  fullName: 'Guest Motorist',
                                  phone: normalized,
                                  role: 'motorist',
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) _proceedToHome();
                              } catch (e) {
                                setSheetState(() {
                                  isSubmitting = false;
                                  localError = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.caliperCrimson,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'CONTINUE TO EMERGENCY MAP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setSheetState(() => isSubmitting = true);
                              try {
                                await SupabaseService().signInAnonymously();
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) _proceedToHome();
                              } catch (_) {
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) _proceedToHome();
                              }
                            },
                      child: const Text(
                        'Skip phone entry (Proceed directly)',
                        style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handlePhoneOtp() async {
    final rawPhone = _phoneController.text.trim();
    final normalized = PhoneUtils.normalize(rawPhone);
    if (!PhoneUtils.isValidBangladeshPhone(normalized)) {
      _showError('Please enter a valid 11-digit Bangladesh phone (e.g. 01712345678)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      HapticFeedback.lightImpact();
      await SupabaseService().sendPhoneOtp(rawPhone);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phoneNumber: normalized.replaceAll('+880', ''),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
        _showError(msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      HapticFeedback.lightImpact();
      if (_isSignUp) {
        final res = await SupabaseService().signUpWithEmail(
          email: email,
          password: password,
          fullName: _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : null,
        );
        if (res.session == null && res.user != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account created! Please check your email to verify before signing in.',
                ),
                backgroundColor: AppColors.emeraldGps,
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() => _isSignUp = false);
            return;
          }
        }
      } else {
        await SupabaseService().signInWithEmail(
          email: email,
          password: password,
        );
      }
      if (mounted) {
        await _proceedBasedOnRole();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
        _showError(msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      HapticFeedback.lightImpact();
      if (!AppConfig.isGoogleAuthConfigured) {
        await _performGoogleFallback();
        return;
      }

      final initiated = await SupabaseService().signInWithGoogle();
      if (!initiated) {
        await _performGoogleFallback();
        return;
      }
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && mounted) {
        await _proceedBasedOnRole();
      }
    } on AuthException catch (_) {
      if (mounted) await _performGoogleFallback();
    } catch (_) {
      if (mounted) await _performGoogleFallback();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performGoogleFallback() async {
    setState(() => _isDemoActionInProgress = true);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google OAuth unconfigured. Continuing with Google Demo Account...'),
          backgroundColor: AppColors.chassisText,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await SupabaseService().signInWithGoogleFallback(role: _selectedRole);
      if (!mounted) return;
      if (_selectedRole == 'mechanic') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MechanicHomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmergencyHomeScreen()),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDemoActionInProgress = false;
        });
      }
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.caliperCrimson,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header with Automotive Red Embellishment
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.slateBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.caliperCrimson.withAlpha(25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.car_crash_outlined,
                            color: AppColors.caliperCrimson,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'ROADIX',
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Rapid Highway Emergency Assistance • Bangladesh',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Guest SOS Quick Access Pill (Instant Highway Dispatch)
                  InkWell(
                    onTap: _isLoading ? null : _openGuestSosSheet,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.crimsonLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.crimsonBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.caliperCrimson.withAlpha(15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.caliperCrimson,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.flash_on, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EMERGENCY BREAKDOWN?',
                                  style: TextStyle(
                                    color: AppColors.caliperCrimson,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Continue as Guest • Instant Triage',
                                  style: TextStyle(
                                    color: AppColors.chassisText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: AppColors.caliperCrimson, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Demo One-Tap Access Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.slateBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.caliperCrimson.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.bolt,
                                color: AppColors.caliperCrimson,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'DEMO ONE-TAP ACCESS',
                              style: TextStyle(
                                color: AppColors.chassisText,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Experience live flows instantly on test device or emulator without typing credentials.',
                          style: TextStyle(color: AppColors.slateMuted, fontSize: 10.5),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _isLoading ? null : _loginAsDemoMotorist,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardWhite,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.slateBorder),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(4),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: const [
                                      Icon(Icons.directions_car, color: AppColors.caliperCrimson, size: 18),
                                      SizedBox(height: 3),
                                      Text(
                                        'Motorist',
                                        style: TextStyle(
                                          color: AppColors.chassisText,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: _isLoading ? null : _loginAsDemoTechnician,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardWhite,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.slateBorder),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(4),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: const [
                                      Icon(Icons.engineering, color: Color(0xFF0F172A), size: 18),
                                      SizedBox(height: 3),
                                      Text(
                                        'Technician',
                                        style: TextStyle(
                                          color: AppColors.chassisText,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: _isLoading ? null : _loginAsGuest,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardWhite,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.slateBorder),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(4),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: const [
                                      Icon(Icons.flash_on, color: Color(0xFFD97706), size: 18),
                                      SizedBox(height: 3),
                                      Text(
                                        'Guest SOS',
                                        style: TextStyle(
                                          color: AppColors.chassisText,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Auth Card with Segmented Toggle (Phone OTP vs Email)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.slateBorder),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.chassisText.withAlpha(6),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Segmented Mode Switcher
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.porcelainBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.slateBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _usePhoneAuth = true);
                                  },
                                  borderRadius: BorderRadius.circular(9),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _usePhoneAuth ? AppColors.cardWhite : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: _usePhoneAuth
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withAlpha(8),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Mobile OTP',
                                        style: TextStyle(
                                          color: _usePhoneAuth ? AppColors.chassisText : AppColors.slateMuted,
                                          fontSize: 12,
                                          fontWeight: _usePhoneAuth ? FontWeight.w800 : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _usePhoneAuth = false);
                                  },
                                  borderRadius: BorderRadius.circular(9),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !_usePhoneAuth ? AppColors.cardWhite : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: !_usePhoneAuth
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withAlpha(8),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Email Account',
                                        style: TextStyle(
                                          color: !_usePhoneAuth ? AppColors.chassisText : AppColors.slateMuted,
                                          fontSize: 12,
                                          fontWeight: !_usePhoneAuth ? FontWeight.w800 : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.crimsonLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.crimsonBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.caliperCrimson, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: AppColors.caliperCrimson, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // ===================================
                        // TAB A: MOBILE NUMBER & SMS OTP
                        // ===================================
                        if (_usePhoneAuth) ...[
                          const Text(
                            'Enter your mobile number to sign in or register instantly.',
                            style: TextStyle(color: AppColors.slateMuted, fontSize: 11.5, height: 1.3),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Mobile Number',
                              labelStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
                              hintText: '017XXXXXXXX',
                              prefixText: '+880 ',
                              prefixStyle: const TextStyle(
                                color: AppColors.chassisText,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(Icons.phone_android, color: AppColors.slateMuted, size: 20),
                              filled: true,
                              fillColor: AppColors.porcelainBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.slateBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.slateBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.caliperCrimson, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handlePhoneOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.caliperCrimson,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Text(
                                            'SEND VERIFICATION CODE',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ]

                        // ===================================
                        // TAB B: EMAIL & PASSWORD
                        // ===================================
                        else ...[
                          Text(
                            _isSignUp
                                ? (_selectedRole == 'mechanic'
                                    ? 'Create Technician Account'
                                    : 'Create Motorist Account')
                                : 'Sign In with Email',
                            style: const TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_isSignUp) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.porcelainBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.slateBorder),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedRole = 'motorist'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _selectedRole == 'motorist'
                                              ? AppColors.cardWhite
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(9),
                                          boxShadow: _selectedRole == 'motorist'
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors.chassisText.withAlpha(10),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.directions_car,
                                              size: 15,
                                              color: _selectedRole == 'motorist'
                                                  ? AppColors.caliperCrimson
                                                  : AppColors.slateMuted,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Motorist',
                                              style: TextStyle(
                                                color: _selectedRole == 'motorist'
                                                    ? AppColors.chassisText
                                                    : AppColors.slateMuted,
                                                fontSize: 12,
                                                fontWeight: _selectedRole == 'motorist'
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedRole = 'mechanic'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _selectedRole == 'mechanic'
                                              ? AppColors.cardWhite
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(9),
                                          boxShadow: _selectedRole == 'mechanic'
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors.chassisText.withAlpha(10),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.build,
                                              size: 14,
                                              color: _selectedRole == 'mechanic'
                                                  ? AppColors.caliperCrimson
                                                  : AppColors.slateMuted,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Technician',
                                              style: TextStyle(
                                                color: _selectedRole == 'mechanic'
                                                    ? AppColors.chassisText
                                                    : AppColors.slateMuted,
                                                fontSize: 12,
                                                fontWeight: _selectedRole == 'mechanic'
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(color: AppColors.chassisText, fontSize: 13.5),
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                labelStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
                                prefixIcon: const Icon(Icons.person_outline, color: AppColors.slateMuted, size: 20),
                                filled: true,
                                fillColor: AppColors.porcelainBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.slateBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.slateBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.caliperCrimson, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: AppColors.chassisText, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              labelStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
                              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.slateMuted, size: 20),
                              filled: true,
                              fillColor: AppColors.porcelainBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.slateBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.slateBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.caliperCrimson, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: AppColors.chassisText, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
                              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.slateMuted, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.slateMuted,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              filled: true,
                              fillColor: AppColors.porcelainBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.slateBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.slateBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.caliperCrimson, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleEmailAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.caliperCrimson,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isSignUp
                                    ? 'Already have an account? '
                                    : 'Need a new account? ',
                                style: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _isSignUp = !_isSignUp),
                                child: Text(
                                  _isSignUp ? 'Sign In' : 'Sign Up',
                                  style: const TextStyle(
                                    color: AppColors.caliperCrimson,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Premium Authentic Google Sign-In Button
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: const BrandLogo(brand: 'google', size: 22),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: AppColors.chassisText,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.slateBorder, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: AppColors.cardWhite,
                        elevation: 1,
                        shadowColor: Colors.black.withAlpha(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
