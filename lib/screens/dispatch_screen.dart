import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DispatchScreen extends StatefulWidget {
  final String selectedFault;
  final String vehicleType;
  final String licensePlate;
  final List<String> symptoms;
  final bool isHighPriority;

  const DispatchScreen({
    super.key,
    required this.selectedFault,
    required this.vehicleType,
    required this.licensePlate,
    required this.symptoms,
    required this.isHighPriority,
  });

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

enum DispatchPhase { searching, quotePending, enRoute, completed }

class _DispatchScreenState extends State<DispatchScreen> with TickerProviderStateMixin {
  DispatchPhase _phase = DispatchPhase.searching;
  late AnimationController _sonarController;
  Timer? _searchTimer;
  int _etaMinutes = 9;

  @override
  void initState() {
    super.initState();
    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Simulate search resolving into an active mechanic match in 3 seconds
    _searchTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _phase = DispatchPhase.quotePending);
      }
    });
  }

  @override
  void dispose() {
    _sonarController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _approveQuote() {
    setState(() => _phase = DispatchPhase.enRoute);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quote approved! Md. Rafiqul Islam is en route.'),
        backgroundColor: AppColors.emeraldGps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.chassisText),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    _phase == DispatchPhase.searching ? 'Locating Mechanics' : 'Rescue Active',
                    style: const TextStyle(
                      color: AppColors.chassisText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.isHighPriority ? AppColors.crimsonLight : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.isHighPriority ? 'PRIORITY' : 'STANDBY',
                      style: TextStyle(
                        color: widget.isHighPriority ? AppColors.caliperCrimson : AppColors.slateMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Step Progress: Step 4 of 4 (100%)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 2.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'STEP 4 OF 4',
                        style: TextStyle(
                          color: AppColors.caliperCrimson,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'DISPATCH & TELEMETRY',
                        style: TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.caliperCrimson,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),

            // Dynamic Body by Phase
            Expanded(
              child: _phase == DispatchPhase.searching
                  ? _buildSearchingView()
                  : (_phase == DispatchPhase.quotePending
                      ? _buildQuotePendingView()
                      : _buildEnRouteView()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _sonarController,
                builder: (context, child) {
                  return Container(
                    width: 140 + (_sonarController.value * 60),
                    height: 140 + (_sonarController.value * 60),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.caliperCrimson.withOpacity(1.0 - _sonarController.value),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.crimsonLight,
                  border: Border.all(color: AppColors.crimsonBorder),
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.caliperCrimson,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.radar, color: Colors.white, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Broadcasting Breakdown Beacon',
            style: TextStyle(
              color: AppColors.chassisText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Querying verified mobile workshops within 3.5 km of Uttara Sector 7...',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotePendingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Technician Profile Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slateBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF1E293B),
                  child: const Text('MR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Text(
                            'Md. Rafiqul Islam',
                            style: TextStyle(color: AppColors.chassisText, fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.verified, color: AppColors.emeraldGps, size: 14),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Master Automotive Tech • 4.9 ★ (342 rescues)',
                        style: TextStyle(color: AppColors.slateMuted, fontSize: 10.5),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Icons.timer_outlined, size: 12, color: AppColors.caliperCrimson),
                          SizedBox(width: 4),
                          Text(
                            'ETA: 7-9 mins (Mobile Workshop Van)',
                            style: TextStyle(color: AppColors.caliperCrimson, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Diagnostic Pre-Service Quote
          const Text(
            'Pre-Service Diagnostic Quote',
            style: TextStyle(color: AppColors.chassisText, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Transparent estimate per ROADIX standard schedule of rates',
            style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.slateBorder),
            ),
            child: Column(
              children: [
                _buildQuoteRow('Roadside Rapid Inspection Fee', '৳ 300'),
                const SizedBox(height: 8),
                _buildQuoteRow('Standard Labor & Diagnostic Scan', '৳ 500'),
                const SizedBox(height: 8),
                _buildQuoteRow('Estimated Hardware / Consumables', '৳ 450'),
                const Divider(color: AppColors.slateBorder, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Total Estimated Authorization', style: TextStyle(color: AppColors.chassisText, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    Text('৳ 1,250', style: TextStyle(color: AppColors.caliperCrimson, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Payment Badges
          Row(
            children: const [
              Icon(Icons.shield_outlined, color: AppColors.emeraldGps, size: 16),
              SizedBox(width: 6),
              Text(
                'Funds held securely until job sign-off via bKash / Nagad',
                style: TextStyle(color: AppColors.slateMuted, fontSize: 10.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Approve CTA
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _approveQuote,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.caliperCrimson,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
              child: const Text(
                'APPROVE QUOTE & DISPATCH',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnRouteView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slateBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$_etaMinutes MINS AWAY', style: const TextStyle(color: AppColors.caliperCrimson, fontSize: 18, fontWeight: FontWeight.w900)),
                        const Text('Technician en route to Uttara Sector 7', style: TextStyle(color: AppColors.slateMuted, fontSize: 11)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('DISPATCHED', style: TextStyle(color: AppColors.emeraldGps, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const LinearProgressIndicator(
                  value: 0.65,
                  backgroundColor: AppColors.slateBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.caliperCrimson),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Calling Md. Rafiqul Islam (+8801700-000000)...')),
                          );
                        },
                        icon: const Icon(Icons.phone, size: 16, color: AppColors.chassisText),
                        label: const Text('Call Tech', style: TextStyle(color: AppColors.chassisText, fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.slateBorder)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Chat messaging open')),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.chassisText),
                        label: const Text('Message', style: TextStyle(color: AppColors.chassisText, fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.slateBorder)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Return to Home Dashboard', style: TextStyle(color: AppColors.slateMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.slateMuted, fontSize: 11.5)),
        Text(amount, style: const TextStyle(color: AppColors.chassisText, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
      ],
    );
  }
}