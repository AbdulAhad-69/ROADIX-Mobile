import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../src/core/router/app_router.dart';
import '../theme/app_colors.dart';
import 'emergency_home_screen.dart';
import 'mechanic_home_screen.dart';
import 'profile_setup_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _resendCountdown = 59;
  Timer? _timer;
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    if (mounted) setState(() => _resendCountdown = 59);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_enteredOtp.length != 6 || _isVerifying) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService().verifyPhoneOtp(
        rawPhone: widget.phoneNumber,
        token: _enteredOtp,
      );

      if (!mounted) return;
      final profile = await SupabaseService().getProfile();
      if (!mounted) return;
      final fullName = profile?['full_name'] as String?;
      final hasFullName =
          fullName != null && fullName.isNotEmpty && fullName != 'Motorist';

      if (hasFullName) {
        final role = profile?['role'] as String?;
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(phoneNumber: widget.phoneNumber),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('AuthException: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _errorMessage ?? 'Invalid verification code. Please try again.',
          ),
          backgroundColor: AppColors.crimsonHover,
        ),
      );
    }
  }

  Future<void> _handleResend() async {
    _startCountdown();
    try {
      await SupabaseService().resendPhoneOtp(widget.phoneNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new 6-digit verification code has been dispatched.'),
            backgroundColor: AppColors.chassisText,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e
                  .toString()
                  .replaceAll('Exception: ', '')
                  .replaceAll('AuthException: ', ''),
            ),
            backgroundColor: AppColors.crimsonHover,
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
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 16).clamp(0, double.infinity),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.chassisText,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Verify Phone Number',
                          style: TextStyle(
                            color: AppColors.chassisText,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Enter the 6-digit verification code sent to ',
                              ),
                              TextSpan(
                                text: '+880 ${widget.phoneNumber}',
                                style: const TextStyle(
                                  color: AppColors.chassisText,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.crimsonLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.crimsonBorder),
                            ),
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
                        const SizedBox(height: 28),
                        Row(
                          children: List.generate(6, (index) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index < 5 ? 6 : 0,
                                ),
                                child: Semantics(
                                  label: 'OTP digit ${index + 1}',
                                  child: SizedBox(
                                    height: 54,
                                    child: TextField(
                                      controller: _controllers[index],
                                      focusNode: _focusNodes[index],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 1,
                                      style: const TextStyle(
                                        color: AppColors.chassisText,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      decoration: const InputDecoration(
                                        counterText: '',
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (value) {
                                        if (value.isNotEmpty && index < 5) {
                                          _focusNodes[index + 1].requestFocus();
                                        } else if (value.isEmpty && index > 0) {
                                          _focusNodes[index - 1].requestFocus();
                                        }
                                        setState(() {});
                                        if (_enteredOtp.length == 6) {
                                          _verifyOtp();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: _resendCountdown > 0
                              ? Text(
                                  'Resend code in ${_resendCountdown}s',
                                  style: const TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : TextButton(
                                  onPressed: _handleResend,
                                  child: const Text('Resend Verification Code'),
                                ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (_enteredOtp.length == 6 && !_isVerifying)
                              ? _verifyOtp
                              : null,
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('VERIFY & CONTINUE'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
