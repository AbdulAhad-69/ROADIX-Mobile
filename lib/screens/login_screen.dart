import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../src/core/utils/phone_utils.dart';
import '../theme/app_colors.dart';
import 'emergency_home_screen.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _phoneNumber = '';
  bool _isLoading = false;
  String? _errorMessage;

  void _onKeyPress(String digit) {
    if (_phoneNumber.length < 10) {
      setState(() => _phoneNumber += digit);
    }
  }

  void _onBackspace() {
    if (_phoneNumber.isNotEmpty) {
      setState(
        () => _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1),
      );
    }
  }

  String get _maskedDisplay {
    if (_phoneNumber.isEmpty) return '••••• ••••••';
    if (_phoneNumber.length <= 5) {
      return '${_phoneNumber.padRight(5, '•')} ••••••';
    }
    final firstPart = _phoneNumber.substring(0, 5);
    final secondPart = _phoneNumber.substring(5).padRight(5, '•');
    return '$firstPart $secondPart';
  }

  void _proceedToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const EmergencyHomeScreen()),
    );
  }

  Future<void> _proceedToOtp() async {
    final rawInput = _phoneNumber.isEmpty ? '1712345678' : _phoneNumber;
    final normalized = PhoneUtils.normalize(rawInput);
    if (!PhoneUtils.isValidBangladeshPhone(normalized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number starting with 1.'),
          backgroundColor: AppColors.caliperCrimson,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService().sendPhoneOtp(normalized);
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(phoneNumber: normalized),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e
              .toString()
              .replaceAll('Exception: ', '')
              .replaceAll('AuthException: ', '');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _errorMessage ?? 'Failed to send OTP code. Please check configuration.',
            ),
            backgroundColor: AppColors.caliperCrimson,
          ),
        );
      }
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
        setState(() {
          _isLoading = false;
          _errorMessage = e
              .toString()
              .replaceAll('Exception: ', '')
              .replaceAll('AuthException: ', '');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? 'Google Sign-In failed.'),
            backgroundColor: AppColors.caliperCrimson,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Top Bar: Skip to SOS Pill
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: _proceedToHome,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.crimsonLight,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.crimsonBorder,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bolt,
                                      color: AppColors.caliperCrimson,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'SKIP TO SOS',
                                      style: TextStyle(
                                        color: AppColors.caliperCrimson,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Title & Subtitle
                        const Text(
                          'Get Started',
                          style: TextStyle(
                            color: AppColors.chassisText,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const SizedBox(
                          width: 220,
                          child: Text(
                            'Enter your mobile number to connect with roadside assistance',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),

                        const SizedBox(height: 26),

                        // Input Box Container
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mobile number',
                              style: TextStyle(
                                color: AppColors.slateMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cardWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.slateBorder,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.chassisText.withAlpha(6),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Bangladesh Flag
                                  Container(
                                    width: 20,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF006A4E),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF42A41),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '+880',
                                    style: TextStyle(
                                      color: AppColors.chassisText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.slateMuted,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 1,
                                    height: 18,
                                    color: AppColors.slateBorder,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _maskedDisplay,
                                      style: TextStyle(
                                        color: _phoneNumber.isEmpty
                                            ? AppColors.slateMuted
                                            : AppColors.chassisText,
                                        fontSize: 13.5,
                                        letterSpacing: 2.2,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Send OTP Button
                            InkWell(
                              onTap: (_phoneNumber.length >= 10 && !_isLoading)
                                  ? _proceedToOtp
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 48,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: _phoneNumber.length >= 10
                                      ? AppColors.caliperCrimson
                                      : const Color(0xFFFCA5A5),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _phoneNumber.length >= 10
                                      ? [
                                          BoxShadow(
                                            color: AppColors.caliperCrimson
                                                .withAlpha(90),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Send OTP Code',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Divider
                            Row(
                              children: const [
                                Expanded(child: Divider(color: AppColors.slateBorder)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: AppColors.slateMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: AppColors.slateBorder)),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Continue with Google Button
                            InkWell(
                              onTap: _isLoading ? null : _handleGoogleSignIn,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 46,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.cardWhite,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.slateBorder),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.g_mobiledata,
                                        color: AppColors.chassisText, size: 28),
                                    SizedBox(width: 4),
                                    Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        color: AppColors.chassisText,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Tactile White Keypad
                        Container(
                          margin: const EdgeInsets.only(bottom: 18.0),
                          child: Column(
                            children: [
                              _buildKeypadRow(['1', '2', '3']),
                              const SizedBox(height: 8),
                              _buildKeypadRow(['4', '5', '6']),
                              const SizedBox(height: 8),
                              _buildKeypadRow(['7', '8', '9']),
                              const SizedBox(height: 8),
                              _buildKeypadRow(['', '0', 'backspace']),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        if (key.isEmpty) {
          return const Expanded(child: SizedBox(height: 48));
        }
        if (key == 'backspace') {
          return Expanded(
            child: InkWell(
              onTap: _onBackspace,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.backspace_outlined,
                  color: AppColors.slateMuted,
                  size: 20,
                ),
              ),
            ),
          );
        }
        return Expanded(
          child: InkWell(
            onTap: () => _onKeyPress(key),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.slateBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.chassisText.withAlpha(4),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                key,
                style: const TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}