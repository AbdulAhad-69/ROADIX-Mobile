import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'emergency_home_screen.dart';

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
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _proceedToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const EmergencyHomeScreen()),
    );
  }

  Future<void> _handleGuestSos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService().signInAnonymously();
      if (mounted) {
        _proceedToHome();
      }
    } catch (e) {
      if (mounted) {
        // Fallback for offline/local simulation
        _proceedToHome();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAuth() async {
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
      if (_isSignUp) {
        await SupabaseService().signUpWithEmail(
          email: email,
          password: password,
          fullName: _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : null,
        );
      } else {
        await SupabaseService().signInWithEmail(
          email: email,
          password: password,
        );
      }
      if (mounted) {
        _proceedToHome();
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
      await SupabaseService().signInWithGoogle();
    } catch (e) {
      if (mounted) {
        _showError('Google Sign-In failed. Please try email login.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.caliperCrimson,
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
                  // Brand Header
                  Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.caliperCrimson.withAlpha(30),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.caliperCrimson, width: 2),
                      ),
                      child: const Icon(
                        Icons.car_crash_outlined,
                        color: AppColors.caliperCrimson,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'ROADIX',
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Rapid Highway Emergency Assistance',
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Guest SOS Quick Access Pill
                  InkWell(
                    onTap: _isLoading ? null : _handleGuestSos,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.crimsonLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.crimsonBorder, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flash_on, color: AppColors.caliperCrimson, size: 20),
                          const SizedBox(width: 10),
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
                                  'Continue as Guest • No Signup Required',
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
                  const SizedBox(height: 24),

                  // Auth Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.slateBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isSignUp ? 'Create Motorist Account' : 'Sign In to Account',
                          style: const TextStyle(
                            color: AppColors.chassisText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.crimsonLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.crimsonBorder),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.caliperCrimson, fontSize: 11),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        if (_isSignUp) ...[
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
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.slateBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.slateBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.caliperCrimson),
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
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.slateBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.slateBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.caliperCrimson),
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
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.slateBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.slateBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.caliperCrimson),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.caliperCrimson,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
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
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Google OAuth Button
                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: const Icon(Icons.g_mobiledata, size: 24, color: AppColors.chassisText),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: AppColors.chassisText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.slateBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: AppColors.cardWhite,
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
