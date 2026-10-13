import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NotificationsBottomSheet extends StatefulWidget {
  final VoidCallback? onMarkAllRead;

  const NotificationsBottomSheet({super.key, this.onMarkAllRead});

  @override
  State<NotificationsBottomSheet> createState() => _NotificationsBottomSheetState();
}

class _NotificationsBottomSheetState extends State<NotificationsBottomSheet> {
  final List<Map<String, dynamic>> _alerts = [
    {
      'id': '1',
      'title': 'Severe Waterlogging Crawl',
      'location': 'Airport Road (Kawla to Jasimuddin)',
      'desc': 'Slow moving traffic due to monsoon drainage backflow. Average speed below 10 km/h.',
      'time': '12 mins ago',
      'severity': 'CRITICAL',
      'isRead': false,
      'icon': Icons.flood_outlined,
    },
    {
      'id': '2',
      'title': 'Stalled Heavy Truck in Left Lane',
      'location': 'Kuril Flyover (Airport exit ramp)',
      'desc': 'Wrecker en route to clear stalled container carrier. Exercise extreme caution.',
      'time': '28 mins ago',
      'severity': 'HAZARD',
      'isRead': false,
      'icon': Icons.warning_amber_rounded,
    },
    {
      'id': '3',
      'title': 'Rain Traction Advisory',
      'location': 'Dhaka North Met Area',
      'desc': 'Wet asphalt reduces braking grip by up to 40%. Maintain 3-car safety gap.',
      'time': '1 hour ago',
      'severity': 'ADVISORY',
      'isRead': true,
      'icon': Icons.grain_outlined,
    },
    {
      'id': '4',
      'title': 'Rescue Service Receipt Issued',
      'location': 'Ticket #RDX-2026-9041',
      'desc': 'Digital invoice for Jumpstart service is ready. Total paid: ৳ 1,250 via bKash.',
      'time': '2 days ago',
      'severity': 'SERVICE',
      'isRead': true,
      'icon': Icons.receipt_long_outlined,
    },
  ];

  void _markAllAsRead() {
    setState(() {
      for (var a in _alerts) {
        a['isRead'] = true;
      }
    });
    widget.onMarkAllRead?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
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
          const SizedBox(height: 14),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Highway Advisories',
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Live road condition & rescue alerts',
                      style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _markAllAsRead,
                  child: const Text(
                    'Mark all as read',
                    style: TextStyle(
                      color: AppColors.caliperCrimson,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: AppColors.slateBorder, height: 1),

          // Alerts List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: _alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final alert = _alerts[idx];
                final bool isUnread = !(alert['isRead'] as bool);

                Color badgeColor;
                Color badgeBg;
                switch (alert['severity']) {
                  case 'CRITICAL':
                    badgeColor = AppColors.caliperCrimson;
                    badgeBg = AppColors.crimsonLight;
                    break;
                  case 'HAZARD':
                    badgeColor = const Color(0xFFD97706);
                    badgeBg = const Color(0xFFFEF3C7);
                    break;
                  case 'ADVISORY':
                    badgeColor = const Color(0xFF2563EB);
                    badgeBg = const Color(0xFFDBEAFE);
                    break;
                  default:
                    badgeColor = AppColors.emeraldGps;
                    badgeBg = const Color(0xFFECFDF5);
                }

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUnread ? const Color(0xFFFFF7ED) : AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isUnread ? const Color(0xFFFDBA74) : AppColors.slateBorder,
                      width: isUnread ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(alert['icon'] as IconData, color: badgeColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    alert['severity'] as String,
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                Text(
                                  alert['time'] as String,
                                  style: const TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 9.5,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              alert['title'] as String,
                              style: const TextStyle(
                                color: AppColors.chassisText,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              alert['location'] as String,
                              style: const TextStyle(
                                color: AppColors.caliperCrimson,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alert['desc'] as String,
                              style: const TextStyle(
                                color: AppColors.slateMuted,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}