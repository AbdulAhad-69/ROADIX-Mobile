import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/demo_session.dart';
import '../services/supabase_service.dart';
import '../src/core/router/app_router.dart';
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
  String? _activeAction;
  bool _obscurePassword = true;
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isDemoActionInProgress = false;
  bool _hasNavigated = false;

  bool get _isLoading => _activeAction != null;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (data.session != null &&
            mounted &&
            !_isDemoActionInProgress &&
            !_hasNavigated) {
          _proceedBasedOnRole();
        }
      },
      onError: (_) {},
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
    if (_hasNavigated) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null && !DemoSession.isActive) return;

    String? role;
    try {
      role = await SupabaseService().getUserRole();
    } catch (_) {}

    if (role == null && user != null) {
      final meta = user.userMetadata;
      final metaRole = meta?['role']?.toString();
      final assignedRole = (metaRole == 'mechanic' || _selectedRole == 'mechanic')
          ? 'mechanic'
          : 'motorist';
      final fullName = meta?['full_name'] as String? ??
          meta?['name'] as String? ??
          (_nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : user.email?.split('@').first ?? 'Motorist');
      try {
        await SupabaseService().createOrUpdateProfile(
          fullName: fullName,
          phone: user.phone,
          role: assignedRole,
          avatarUrl: meta?['avatar_url']?.toString() ??
              meta?['picture']?.toString(),
        );
      } catch (_) {}
      role = assignedRole;
    }
    role ??= DemoSession.isActive ? DemoSession.role : 'motorist';

    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
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
  }

  Future<void> _enterDemoMode({
    required String actionKey,
    required String role,
    required String fullName,
    required String phone,
    String? workshopName,
    String? workshopAddress,
  }) async {
    if (_isLoading || _isDemoActionInProgress || _hasNavigated) return;
    setState(() {
      _activeAction = actionKey;
      _isDemoActionInProgress = true;
      _errorMessage = null;
    });
    try {
      HapticFeedback.mediumImpact();
      try {
        await SupabaseService().signInAnonymously();
      } catch (_) {
        // Anonymous auth may be disabled in dashboard; use explicit local demo session.
      }

      if (SupabaseService().currentUser == null) {
        DemoSession.startDemo(
          demoRole: role,
          name: fullName,
          phoneNumber: phone,
        );
      } else {
        try {
          await SupabaseService().createOrUpdateProfile(
            fullName: fullName,
            phone: phone,
            role: role,
          );
          if (role == 'mechanic') {
            await SupabaseService().ensureMechanicProfile(
              workshopName: workshopName,
              workshopAddress: workshopAddress,
            );
          }
        } catch (_) {}
      }

      if (!mounted || _hasNavigated) return;
      _hasNavigated = true;
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
    } finally {
      if (mounted) {
        setState(() {
          _activeAction = null;
          _isDemoActionInProgress = false;
        });
      }
    }
  }

  Future<void> _loginAsDemoMotorist() => _enterDemoMode(
        actionKey: 'demo_motorist',
        role: 'motorist',
        fullName: 'Tanvir Ahmed',
        phone: '+8801711000001',
      );

  Future<void> _loginAsDemoTechnician() => _enterDemoMode(
        actionKey: 'demo_technician',
        role: 'mechanic',
        fullName: 'Rahim Uddin',
        phone: '+8801811000011',
        workshopName: 'Gulshan Auto Clinic',
        workshopAddress: 'Plot 14, Road 45, Gulshan 2, Dhaka',
      );

  Future<void> _loginAsGuest() => _enterDemoMode(
        actionKey: 'demo_guest',
        role: 'motorist',
        fullName: 'Guest Motorist',
        phone: '+8801700000000',
      );

  void _openGuestSosSheet() {
    if (_isLoading || _isDemoActionInProgress || _hasNavigated) return;
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
                              color: AppColors.crimsonLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.flash_on,
                              color: AppColors.crimsonHover,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'GUEST SOS DISPATCH',
                            style: TextStyle(
                              color: AppColors.crimsonHover,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Close Guest SOS',
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.slateMuted,
                          size: 22,
                        ),
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
                    'Provide an active callback number so dispatched technicians can reach you quickly.',
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.crimsonLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.crimsonBorder),
                      ),
                      child: Text(
                        localError!,
                        style: const TextStyle(
                          color: AppColors.crimsonHover,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: guestPhoneController,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    style: const TextStyle(
                      color: AppColors.chassisText,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Callback Mobile Number',
                      hintText: '017XXXXXXXX',
                      prefixText: '+880 ',
                      prefixIcon: Icon(Icons.phone, color: AppColors.slateMuted, size: 20),
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
                                  localError =
                                      'Enter a valid 11-digit Bangladesh phone (e.g. 01712345678).';
                                });
                                return;
                              }
                              setSheetState(() {
                                isSubmitting = true;
                                localError = null;
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _enterDemoMode(
                                actionKey: 'demo_guest_sheet',
                                role: 'motorist',
                                fullName: 'Guest Motorist',
                                phone: normalized,
                              );
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('CONTINUE TO EMERGENCY MAP'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _loginAsGuest();
                            },
                      child: const Text(
                        'Skip phone entry (Proceed in Guest Demo)',
                        style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        guestPhoneController.dispose();
      });
    });
  }

  String _friendlyAuthError(Object e, {bool isPhone = false}) {
    final raw = e
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('AuthException: ', '')
        .replaceAll('AuthApiException(', '')
        .trim();
    final lower = raw.toLowerCase();
    if (isPhone &&
        (lower.contains('phone') && lower.contains('disabled') ||
            lower.contains('unsupported phone provider') ||
            lower.contains('sms'))) {
      return 'SMS OTP is not yet enabled on Supabase Auth. Sign in via Email Account, Google, or Demo Mode.';
    }
    if (lower.contains('invalid login credentials')) {
      return 'Incorrect email or password. Double-check your credentials or sign up.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email link before signing in.';
    }
    return raw;
  }

  Future<void> _handlePhoneOtp() async {
    if (_isLoading || _isDemoActionInProgress) return;
    final rawPhone = _phoneController.text.trim();
    final normalized = PhoneUtils.normalize(rawPhone);
    if (!PhoneUtils.isValidBangladeshPhone(normalized)) {
      _showError('Enter a valid 11-digit Bangladesh phone (e.g. 01712345678).');
      return;
    }

    setState(() {
      _activeAction = 'otp';
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
      if (mounted) _showError(_friendlyAuthError(e, isPhone: true));
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  Future<void> _handleEmailAuth() async {
    if (_isLoading || _isDemoActionInProgress) return;
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
      _activeAction = 'email';
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
          role: _selectedRole,
        );
        if (res.session == null && res.user != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account created! Verify the confirmation email before signing in.',
                ),
                backgroundColor: AppColors.emeraldDark,
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() => _isSignUp = false);
          }
          return;
        }
      } else {
        await SupabaseService().signInWithEmail(
          email: email,
          password: password,
        );
      }
      if (mounted) await _proceedBasedOnRole();
    } catch (e) {
      if (mounted) _showError(_friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading || _isDemoActionInProgress) return;
    setState(() {
      _activeAction = 'google';
      _errorMessage = null;
    });
    try {
      HapticFeedback.lightImpact();
      final initiated = await SupabaseService().signInWithGoogle();
      if (!mounted) return;
      if (!initiated) {
        _showError(
          'Could not open browser for Google Sign-In. Check network connectivity or use Email / Demo Mode.',
        );
        return;
      }
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await _proceedBasedOnRole();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete Google Sign-In in the browser tab to return to ROADIX.'),
            backgroundColor: AppColors.chassisText,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError(
          'Google Sign-In unavailable right now (${_friendlyAuthError(e)}). Try Email or Demo Mode.',
        );
      }
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.crimsonHover,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.slateBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.caliperCrimson.withAlpha(22),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 38,
                          height: 38,
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
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Rapid Highway Emergency Assistance • Bangladesh',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Guest SOS Quick Access Banner
                  Semantics(
                    button: true,
                    label: 'Emergency breakdown? Continue as guest',
                    child: InkWell(
                      onTap: _isLoading ? null : _openGuestSosSheet,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.crimsonLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.crimsonBorder,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.caliperCrimson,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.flash_on,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'EMERGENCY BREAKDOWN?',
                                    style: TextStyle(
                                      color: AppColors.crimsonHover,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Continue as Guest • Instant Triage',
                                    style: TextStyle(
                                      color: AppColors.chassisText,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: AppColors.crimsonHover,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Explicit Demo One-Tap Access Card (strictly separated from Account Auth)
                  Container(
                    key: const Key('demo_access_card'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
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
                                color: AppColors.crimsonLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.bolt,
                                color: AppColors.crimsonHover,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'DEMO ONE-TAP ACCESS',
                                style: TextStyle(
                                  color: AppColors.chassisText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.porcelainBg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.slateBorder),
                              ),
                              child: const Text(
                                'DEMO MODE',
                                style: TextStyle(
                                  color: AppColors.slateMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Preview Motorist, Technician, or Guest flows immediately without credentials.',
                          style: TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildDemoTile(
                              tileKey: const Key('demo_motorist_btn'),
                              label: 'Demo Motorist',
                              icon: Icons.directions_car,
                              iconColor: AppColors.caliperCrimson,
                              isBusy: _activeAction == 'demo_motorist',
                              onTap: _loginAsDemoMotorist,
                            ),
                            const SizedBox(width: 8),
                            _buildDemoTile(
                              tileKey: const Key('demo_technician_btn'),
                              label: 'Demo Technician',
                              icon: Icons.engineering,
                              iconColor: AppColors.chassisText,
                              isBusy: _activeAction == 'demo_technician',
                              onTap: _loginAsDemoTechnician,
                            ),
                            const SizedBox(width: 8),
                            _buildDemoTile(
                              tileKey: const Key('demo_guest_btn'),
                              label: 'Guest SOS',
                              icon: Icons.flash_on,
                              iconColor: AppColors.amberDark,
                              isBusy: _activeAction == 'demo_guest',
                              onTap: _loginAsGuest,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Live Account Auth Card (Mobile OTP vs Email Account)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.slateBorder),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.chassisText.withAlpha(8),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.porcelainBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.slateBorder),
                          ),
                          child: Row(
                            children: [
                              _buildAuthTab(
                                label: 'Mobile OTP',
                                selected: _usePhoneAuth,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _usePhoneAuth = true;
                                    _errorMessage = null;
                                  });
                                },
                              ),
                              _buildAuthTab(
                                label: 'Email Account',
                                selected: !_usePhoneAuth,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _usePhoneAuth = false;
                                    _errorMessage = null;
                                  });
                                },
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.crimsonHover,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.crimsonHover,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        if (_usePhoneAuth) ...[
                          const Text(
                            'Enter your Bangladesh mobile number to sign in or register.',
                            style: TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 12,
                              height: 1.35,
                            ),
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
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number',
                              hintText: '017XXXXXXXX',
                              prefixText: '+880 ',
                              prefixIcon: Icon(
                                Icons.phone_android,
                                color: AppColors.slateMuted,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handlePhoneOtp,
                              child: _activeAction == 'otp'
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('SEND VERIFICATION CODE'),
                                          SizedBox(width: 6),
                                          Icon(Icons.arrow_forward, size: 16),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ] else ...[
                          Text(
                            _isSignUp
                                ? (_selectedRole == 'mechanic'
                                    ? 'Create Technician Account'
                                    : 'Create Motorist Account')
                                : 'Sign In with Email',
                            style: const TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                  _buildRoleChip(
                                    chipKey: const Key('signup_role_motorist'),
                                    label: 'Motorist',
                                    icon: Icons.directions_car,
                                    selected: _selectedRole == 'motorist',
                                    onTap: () =>
                                        setState(() => _selectedRole = 'motorist'),
                                  ),
                                  _buildRoleChip(
                                    chipKey: const Key('signup_role_technician'),
                                    label: 'Technician',
                                    icon: Icons.build,
                                    selected: _selectedRole == 'mechanic',
                                    onTap: () =>
                                        setState(() => _selectedRole = 'mechanic'),
                                  ),
                                ],
                              ),
                            ),
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(
                                color: AppColors.chassisText,
                                fontSize: 14,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  color: AppColors.slateMuted,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: AppColors.slateMuted,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: AppColors.slateMuted,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppColors.slateMuted,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleEmailAuth,
                              child: _activeAction == 'email'
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(_isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() {
                                _isSignUp = !_isSignUp;
                                _errorMessage = null;
                              }),
                              child: Text(
                                _isSignUp
                                    ? 'Already have an account? Sign In'
                                    : 'Need a new account? Sign Up',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: _activeAction == 'google'
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const BrandLogo(brand: 'google', size: 22),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: AppColors.chassisText,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.cardWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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

  Widget _buildDemoTile({
    required Key tileKey,
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isBusy,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          key: tileKey,
          onTap: _isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.porcelainBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.slateBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isBusy)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  else
                    Icon(icon, color: iconColor, size: 18),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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

  Widget _buildAuthTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.cardWhite : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.chassisText : AppColors.slateMuted,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip({
    required Key chipKey,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label role',
        child: InkWell(
          key: chipKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.cardWhite : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: selected
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
                    icon,
                    size: 16,
                    color: selected
                        ? AppColors.caliperCrimson
                        : AppColors.slateMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? AppColors.chassisText
                          : AppColors.slateMuted,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
