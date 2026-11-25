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
import '../widgets/roadix_pressable.dart';
import 'emergency_home_screen.dart';
import 'mechanic_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isSignUp = false;
  String _selectedRole = 'motorist';
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
        // Offline / anonymous sign-in disabled -> fall back to DemoSession
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

  Future<void> _loginAsGuest({String? phone}) => _enterDemoMode(
        actionKey: 'demo_guest',
        role: 'motorist',
        fullName: 'Guest Motorist',
        phone: (phone != null && phone.isNotEmpty) ? phone : '+8801700000000',
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
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.slateBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Instant Guest Dispatch',
                        style: TextStyle(
                          color: AppColors.chassisText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: AppColors.slateMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter an optional callback phone so the assigned mechanic can call you on arrival.',
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: guestPhoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Callback Mobile Number (Optional)',
                      hintText: '017XXXXXXXX',
                      prefixText: '+880 ',
                      prefixIcon: Icon(
                        Icons.phone_in_talk_outlined,
                        color: AppColors.slateMuted,
                        size: 20,
                      ),
                    ),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      localError!,
                      style: const TextStyle(
                        color: AppColors.crimsonHover,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final rawPhone = guestPhoneController.text.trim();
                              String normalized = '+8801700000000';
                              if (rawPhone.isNotEmpty) {
                                normalized = PhoneUtils.normalize(rawPhone);
                                if (!PhoneUtils.isValidBangladeshPhone(normalized)) {
                                  setSheetState(() {
                                    localError =
                                        'Enter a valid 11-digit Bangladesh number (01XXXXXXXXX).';
                                  });
                                  return;
                                }
                              }
                              setSheetState(() {
                                isSubmitting = true;
                                localError = null;
                              });
                              Navigator.pop(ctx);
                              await _loginAsGuest(phone: normalized);
                            },
                      child: const Text('CONTINUE AS GUEST'),
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

  String _friendlyAuthError(Object e) {
    final raw = e
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('AuthException: ', '')
        .replaceAll('AuthApiException(', '')
        .trim();
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Incorrect email or password. Double-check your credentials or create an account.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email confirmation link before signing in.';
    }
    return raw;
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

      if (mounted) {
        await _proceedBasedOnRole();
      }
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
      final launched = await SupabaseService().signInWithGoogle();
      if (!launched && mounted) {
        _showError('Could not launch Google sign-in browser.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Google Sign-In failed: ${_friendlyAuthError(e)}');
      }
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.slateBorder),
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
                            size: 30,
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
                      'Rapid Highway Emergency Assistance',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Guest Access
                  RoadixPressable(
                    onTap: _isLoading ? null : _openGuestSosSheet,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.crimsonLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.crimsonBorder),
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
                                  'Continue as Guest',
                                  style: TextStyle(
                                    color: AppColors.chassisText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'No signup required for emergency dispatch',
                                  style: TextStyle(
                                    color: AppColors.crimsonHover,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.crimsonHover,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Primary Email Account Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.slateBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isSignUp
                              ? (_selectedRole == 'mechanic'
                                  ? 'Create Technician Account'
                                  : 'Create Motorist Account')
                              : 'Sign In with Email',
                          style: const TextStyle(
                            color: AppColors.chassisText,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),

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
                        const SizedBox(height: 6),
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
                          : const BrandLogo(brand: 'google', size: 20),
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
                  const SizedBox(height: 14),

                  // Non-blocking evaluation access links
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      const Text(
                        'Preview:',
                        style: TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        key: const Key('demo_motorist_btn'),
                        onPressed: _isLoading ? null : _loginAsDemoMotorist,
                        child: const Text('Demo Motorist'),
                      ),
                      TextButton(
                        key: const Key('demo_technician_btn'),
                        onPressed: _isLoading ? null : _loginAsDemoTechnician,
                        child: const Text('Demo Technician'),
                      ),
                      TextButton(
                        key: const Key('demo_guest_btn'),
                        onPressed: _isLoading ? null : _openGuestSosSheet,
                        child: const Text('Guest SOS'),
                      ),
                    ],
                  ),
                ],
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
