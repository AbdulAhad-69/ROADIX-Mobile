import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _countdownController;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();

    // Pulse animation for radar ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // 5-second countdown controller running at 60 fps
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _countdownController.reverse(from: 1.0);

    _countdownController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !_isCancelled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚨 999 Emergency Dispatch Initiated!'),
              backgroundColor: AppColors.caliperCrimson,
            ),
          );
        }
      }
    });
  }

  void _cancelSos() {
    _countdownController.stop();
    setState(() => _isCancelled = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emergency call cancelled.'),
        backgroundColor: AppColors.chassisText,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Emergency Mode',
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.chassisText, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // High-Visibility Emergency Red Alert Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.caliperCrimson,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      FadeTransition(
                        opacity: _pulseController,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'EMERGENCY SOS ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE GPS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Subtitle & Status
            const SizedBox(height: 12),
            const Text(
              'EMERGENCY 999 DISPATCH',
              style: TextStyle(
                color: AppColors.chassisText,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.slateBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.circle, color: AppColors.caliperCrimson, size: 7),
                  SizedBox(width: 6),
                  Text(
                    'Alerting Highway Control & Family Contacts',
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Centerpiece: Fluid 5-Second Circular Dial
            AnimatedBuilder(
              animation: _countdownController,
              builder: (context, child) {
                final int remainingSeconds = (_countdownController.value * 5).ceil().clamp(0, 5);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Pulsing Glow
                        FadeTransition(
                          opacity: _pulseController,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.caliperCrimson.withAlpha(90),
                                width: 2,
                              ),
                            ),
                          ),
                        ),

                        // Progress Ring
                        SizedBox(
                          width: 118,
                          height: 118,
                          child: CircularProgressIndicator(
                            value: _isCancelled ? 0.0 : _countdownController.value,
                            strokeWidth: 5.0,
                            strokeCap: StrokeCap.round,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.caliperCrimson),
                            backgroundColor: AppColors.slateBorder,
                          ),
                        ),

                        // 999 Dial Button
                        InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Connecting to 999 emergency services...'),
                                backgroundColor: AppColors.caliperCrimson,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(46),
                          child: Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.caliperCrimson,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.caliperCrimson.withAlpha(120),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  '999',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isCancelled
                                      ? 'CANCELLED'
                                      : (remainingSeconds > 0 ? 'CALLING (${remainingSeconds}s)' : 'CONNECTED'),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Tap to Cancel Pill Button
                    if (!_isCancelled)
                      InkWell(
                        onTap: _cancelSos,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.slateBorder),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.chassisText.withAlpha(6),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            'TAP TO CANCEL (${remainingSeconds}s)',
                            style: const TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 9.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            const Spacer(),

            // Dispatch Quick Action Cards (Highway Patrol & Ambulance)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  _buildEmergencyServiceCard(
                    icon: Icons.shield_outlined,
                    title: 'CALL HIGHWAY PATROL',
                    subtitle: 'Toll-Free • 24/7 Response',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Connecting to Highway Patrol Dispatch...')),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildEmergencyServiceCard(
                    icon: Icons.local_hospital_outlined,
                    title: 'CALL AMBULANCE',
                    subtitle: 'Critical Medical Response',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Dispatching nearest emergency ambulance...')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Live GPS Coordinates Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slateBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.crimsonLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_on, color: AppColors.caliperCrimson, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Uttara Sector 7, Dhaka',
                            style: TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '23.8759° N, 90.3795° E',
                            style: TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 9.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Text(
                        '±4m Acc',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 8.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Emergency Contacts Broadcast Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.circle, color: AppColors.emeraldGps, size: 6),
                          SizedBox(width: 6),
                          Text(
                            'EMERGENCY CONTACTS',
                            style: TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '3 Notified ✓',
                          style: TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildContactPill('Mom', 'P1', const Color(0xFF9F1239)),
                      const SizedBox(width: 8),
                      _buildContactPill('Shafin', 'P2', const Color(0xFF1E40AF)),
                      const SizedBox(width: 8),
                      _buildContactPill('Shafiur R.', 'P3', const Color(0xFFB45309)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyServiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slateBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.crimsonLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.caliperCrimson, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 8.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.crimsonLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.crimsonBorder),
              ),
              child: const Row(
                children: [
                  Text(
                    'DIRECT',
                    style: TextStyle(
                      color: AppColors.caliperCrimson,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, color: AppColors.caliperCrimson, size: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactPill(String name, String initials, Color avatarColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.slateBorder),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: avatarColor,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.emeraldGps,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.chassisText,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 1),
            const Text(
              'Sent 11:47',
              style: TextStyle(
                color: Color(0xFF059669),
                fontSize: 7.5,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}