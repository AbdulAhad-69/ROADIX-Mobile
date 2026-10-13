import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  void _showReceiptModal(BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DIGITAL RESCUE INVOICE',
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['serviceId'] as String,
                      style: const TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PAID VIA BKASH',
                    style: TextStyle(
                      color: AppColors.emeraldGps,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.slateBorder, height: 1),
            const SizedBox(height: 14),
            _buildReceiptRow('Technician', item['techName'] as String),
            _buildReceiptRow('Location', item['location'] as String),
            _buildReceiptRow('Vehicle', item['vehicle'] as String),
            _buildReceiptRow('Date & Time', item['date'] as String),
            const SizedBox(height: 12),
            const Divider(color: AppColors.slateBorder, height: 1),
            const SizedBox(height: 12),
            _buildReceiptRow('Inspection & Callout Fee', '৳ 300'),
            _buildReceiptRow('Diagnostic Labor', '৳ 500'),
            _buildReceiptRow('Parts / Consumables', item['partsTotal'] as String),
            const Divider(color: AppColors.slateBorder, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Paid',
                  style: TextStyle(
                    color: AppColors.chassisText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  item['amount'] as String,
                  style: const TextStyle(
                    color: AppColors.caliperCrimson,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.download, size: 16, color: AppColors.chassisText),
                label: const Text(
                  'Download PDF Invoice',
                  style: TextStyle(color: AppColors.chassisText, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.slateBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.slateMuted, fontSize: 11.5)),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.chassisText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> historyItems = [
      {
        'serviceId': 'RDX-2026-9041',
        'title': 'Dead Battery Jumpstart',
        'location': 'Jasimuddin Ave, Uttara',
        'date': 'Oct 11, 2026 • 04:15 PM',
        'techName': 'Md. Rafiqul Islam',
        'vehicle': 'Toyota Allion • GA-11-2034',
        'amount': '৳ 1,250',
        'partsTotal': '৳ 450',
        'status': 'Completed',
        'icon': Icons.battery_charging_full,
      },
      {
        'serviceId': 'RDX-2026-8812',
        'title': 'Punctured Front-Left Tire',
        'location': 'Airport Road, Kawla',
        'date': 'Sep 29, 2026 • 11:20 AM',
        'techName': 'Al-Amin Shikder',
        'vehicle': 'Toyota Allion • GA-11-2034',
        'amount': '৳ 650',
        'partsTotal': '৳ 150',
        'status': 'Completed',
        'icon': Icons.album_outlined,
      },
      {
        'serviceId': 'RDX-2026-7901',
        'title': 'Emergency Towing to Garage',
        'location': 'Farmgate Flyover Ramp',
        'date': 'Aug 14, 2026 • 09:40 PM',
        'techName': 'Highway Patrol Logistics',
        'vehicle': 'Yamaha FZS • LA-24-9011',
        'amount': '৳ 2,400',
        'partsTotal': '৳ 1,600',
        'status': 'Completed',
        'icon': Icons.local_shipping_outlined,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Activity & History',
                style: TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Track current dispatches and download past roadside receipts',
                style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
              ),
              const SizedBox(height: 18),

              // Active Dispatch Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slateBorder),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.chassisText.withAlpha(6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            CircleAvatar(radius: 4, backgroundColor: AppColors.emeraldGps),
                            SizedBox(width: 6),
                            Text(
                              'NO ONGOING BREAKDOWN',
                              style: TextStyle(
                                color: AppColors.emeraldGps,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'STANDBY READY',
                            style: TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'All roadside requests resolved',
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Emergency telemetry beacon is armed and ready on Home tab.',
                      style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'PAST RESCUES (DHAKA REGION)',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // History List Items
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: historyItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = historyItems[index];
                  return InkWell(
                    onTap: () => _showReceiptModal(context, item),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.slateBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.porcelainBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.slateBorder),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              color: AppColors.caliperCrimson,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] as String,
                                  style: const TextStyle(
                                    color: AppColors.chassisText,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item['location']} • ${item['date']}',
                                  style: const TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                item['amount'] as String,
                                style: const TextStyle(
                                  color: AppColors.chassisText,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Receipt ›',
                                style: TextStyle(
                                  color: AppColors.caliperCrimson,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}