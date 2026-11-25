import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/demo_session.dart';
import '../services/invoice_pdf_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';
import 'dispatch_screen.dart';

class ActivityScreen extends StatefulWidget {
  final bool showBackButton;

  const ActivityScreen({super.key, this.showBackButton = true});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = true;
  Map<String, dynamic>? _activeRescue;
  List<Map<String, dynamic>> _pastRescues = [];

  // Verified demonstration incidents for educational/sample review when account has 0 past incidents
  final List<Map<String, dynamic>> _sampleFallbackHistory = [
    {
      'serviceId': 'RDX-2026-9041',
      'title': 'Dead Battery Jumpstart',
      'location': 'Jasimuddin Ave, Uttara, Dhaka',
      'date': 'Oct 11, 2026 • 04:15 PM',
      'techName': 'Md. Rafiqul Islam',
      'vehicle': 'Toyota Allion • GA-11-2034',
      'amount': '৳ 1,250',
      'diagFee': '৳ 300',
      'laborFee': '৳ 500',
      'partsTotal': '৳ 450',
      'status': 'Completed',
      'isSample': true,
      'icon': Icons.battery_charging_full,
    },
    {
      'serviceId': 'RDX-2026-8812',
      'title': 'Punctured Front-Left Tire',
      'location': 'Airport Road, Kawla, Dhaka',
      'date': 'Sep 29, 2026 • 11:20 AM',
      'techName': 'Al-Amin Shikder',
      'vehicle': 'Toyota Allion • GA-11-2034',
      'amount': '৳ 650',
      'diagFee': '৳ 200',
      'laborFee': '৳ 300',
      'partsTotal': '৳ 150',
      'status': 'Completed',
      'isSample': true,
      'icon': Icons.album_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadActivityData();
  }

  Future<void> _loadActivityData() async {
    setState(() => _isLoading = true);
    try {
      final active = await _db.getActiveServiceRequest();
      final history = await _db.getServiceRequestHistory();

      if (mounted) {
        setState(() {
          _activeRescue = active;
          _pastRescues = history;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showReceiptModal(BuildContext context, Map<String, dynamic> item) {
    HapticFeedback.lightImpact();
    bool isDownloading = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                  Expanded(
                    child: Column(
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
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((item['paymentMethod'] as String? ?? 'Pending')
                          .toLowerCase()
                          .contains('bkash'))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: AppColors.bkashPink.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.bkashCrimson.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BrandLogo(brand: 'bkash', size: 13),
                              SizedBox(width: 4),
                              Text(
                                'bKash',
                                style: TextStyle(
                                  color: AppColors.bkashCrimson,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Builder(
                        builder: (context) {
                          final statusText =
                              (item['status'] as String? ?? 'Completed')
                                  .toUpperCase();
                          final isCompleted = statusText.contains('COMPLET') ||
                              statusText.contains('PAID');
                          final isCancelled = statusText.contains('CANCEL');
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isCancelled
                                  ? AppColors.crimsonLight
                                  : (isCompleted
                                      ? AppColors.emeraldLight
                                      : AppColors.amberLight),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isCancelled
                                    ? AppColors.crimsonBorder
                                    : (isCompleted
                                        ? AppColors.emeraldBorder
                                        : AppColors.amberBorder),
                              ),
                            ),
                            child: Text(
                              isCompleted ? 'PAID & SETTLED' : statusText,
                              style: TextStyle(
                                color: isCancelled
                                    ? AppColors.crimsonHover
                                    : (isCompleted
                                        ? AppColors.emeraldDark
                                        : AppColors.amberDark),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.slateBorder, height: 1),
              const SizedBox(height: 14),
              _buildReceiptRow('Technician', item['techName'] as String? ?? 'Assigned Mechanic'),
              _buildReceiptRow('Location', item['location'] as String? ?? 'Dhaka Breakdown Site'),
              _buildReceiptRow('Vehicle', item['vehicle'] as String? ?? 'Registered Vehicle'),
              _buildReceiptRow('Timestamp', item['date'] as String? ?? 'Recently'),
              _buildReceiptRow(
                'Payment Method',
                item['paymentMethod'] as String? ?? 'Cash / Digital MFS',
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.slateBorder, height: 1),
              const SizedBox(height: 12),
              _buildReceiptRow('Diagnostic Inspection Fee', item['diagFee'] as String? ?? '৳ 300'),
              _buildReceiptRow('Labor & Repair Operations', item['laborFee'] as String? ?? '৳ 500'),
              _buildReceiptRow('Parts / Materials Replaced', item['partsTotal'] as String? ?? '৳ 0'),
              const Divider(color: AppColors.slateBorder, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Settled',
                    style: TextStyle(
                      color: AppColors.chassisText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    item['amount'] as String? ?? '৳ 800',
                    style: const TextStyle(
                      color: AppColors.caliperCrimson,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isDownloading
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          setModalState(() => isDownloading = true);
                          try {
                            final invoiceData = InvoiceData.fromItem(item);
                            final file = await InvoicePdfService.saveAndShareInvoice(
                              invoiceData,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            HapticFeedback.mediumImpact();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Invoice PDF saved: ${file.uri.pathSegments.last}',
                                ),
                                backgroundColor: AppColors.emeraldDark,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            if (ctx.mounted) {
                              setModalState(() => isDownloading = false);
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Could not export invoice PDF: $e'),
                                backgroundColor: AppColors.crimsonHover,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  icon: isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download, size: 16, color: Colors.white),
                  label: Text(
                    isDownloading ? 'GENERATING RECEIPT...' : 'DOWNLOAD PDF INVOICE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.caliperCrimson,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.slateMuted, fontSize: 11.5)),
          const SizedBox(width: 8),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailing != null) ...[
                  trailing,
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.chassisText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.porcelainBg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.caliperCrimson),
        ),
      );
    }

    final hasActiveRescue = _activeRescue != null;
    final List<Map<String, dynamic>> displayItems = _pastRescues.isNotEmpty
        ? _pastRescues.map((r) {
            final snapshot = r['vehicle_snapshot'] as Map<String, dynamic>?;
            final created =
                r['created_at'] != null ? DateTime.tryParse(r['created_at']) : null;
            final dateStr = created != null
                ? '${created.day}/${created.month}/${created.year} • ${created.hour}:${created.minute.toString().padLeft(2, '0')}'
                : 'Recent';

            IconData icon = Icons.build_circle_outlined;
            final fault = (r['fault_type'] as String? ?? '').toLowerCase();
            if (fault.contains('battery')) icon = Icons.battery_charging_full;
            if (fault.contains('tire')) icon = Icons.album_outlined;
            if (fault.contains('tow')) icon = Icons.local_shipping_outlined;
            if (fault.contains('fuel')) icon = Icons.local_gas_station_outlined;

            final quotes = r['quotations'];
            Map<String, dynamic>? q;
            if (quotes is List && quotes.isNotEmpty) {
              q = quotes.first as Map<String, dynamic>;
            } else if (quotes is Map<String, dynamic>) {
              q = quotes;
            }
            final txs = r['transactions'];
            Map<String, dynamic>? tx;
            if (txs is List && txs.isNotEmpty) {
              tx = txs.first as Map<String, dynamic>;
            } else if (txs is Map<String, dynamic>) {
              tx = txs;
            }

            final double diagFee = (q?['diagnostic_fee'] as num?)?.toDouble() ?? 0.0;
            final double laborFee = (q?['labor_fee'] as num?)?.toDouble() ?? 0.0;
            final double partsFee = (q?['parts_fee'] as num?)?.toDouble() ?? 0.0;
            final double totalAmount = (q?['total_amount'] as num?)?.toDouble() ??
                (tx?['amount'] as num?)?.toDouble() ??
                (diagFee + laborFee + partsFee);

            final rawId = r['id']?.toString() ?? 'RECORD';
            final shortId = rawId.length >= 8 ? rawId.substring(0, 8) : rawId;

            return {
              'serviceId': r['request_code'] ?? 'RDX-$shortId',
              'title': r['fault_type'] ?? 'Roadside Recovery',
              'location': r['breakdown_address'] ?? 'Dhaka Region',
              'date': dateStr,
              'techName': r['mechanic_name']?.toString() ?? 'Assigned Technician',
              'vehicle':
                  '${snapshot?['vehicle_type'] ?? 'Passenger Car'} • ${snapshot?['plate'] ?? ''}',
              'amount': '৳ ${totalAmount.toStringAsFixed(0)}',
              'diagFee': '৳ ${diagFee.toStringAsFixed(0)}',
              'laborFee': '৳ ${laborFee.toStringAsFixed(0)}',
              'partsTotal': '৳ ${partsFee.toStringAsFixed(0)}',
              'paymentMethod':
                  tx?['payment_method']?.toString() ?? 'Pending settlement',
              'paymentStatus': tx?['status']?.toString() ??
                  (r['status']?.toString() ?? 'Completed'),
              'status': r['status'] ?? 'Completed',
              'isSample': false,
              'icon': icon,
            };
          }).toList()
        : (DemoSession.isActive ? _sampleFallbackHistory : const []);

    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadActivityData,
          color: AppColors.caliperCrimson,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (widget.showBackButton && Navigator.of(context).canPop()) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.chassisText),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activity & History',
                            style: TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Real-time rescue tracking and verified digital settlement receipts',
                            style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Active Dispatch Telemetry Card
                if (hasActiveRescue) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.crimsonLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.caliperCrimson, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.caliperCrimson.withAlpha(20),
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
                                CircleAvatar(radius: 4, backgroundColor: AppColors.caliperCrimson),
                                SizedBox(width: 8),
                                Text(
                                  'ACTIVE RESCUE MISSION',
                                  style: TextStyle(
                                    color: AppColors.caliperCrimson,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.caliperCrimson),
                              ),
                              child: Text(
                                _activeRescue!['status']?.toString().toUpperCase() ?? 'IN PROGRESS',
                                style: const TextStyle(
                                  color: AppColors.caliperCrimson,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _activeRescue!['fault_type'] ?? 'Roadside Assistance',
                          style: const TextStyle(
                            color: AppColors.chassisText,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ref: ${_activeRescue!['request_code'] ?? 'RDX'} • ${_activeRescue!['breakdown_address'] ?? 'Dhaka Position'}',
                          style: const TextStyle(color: AppColors.slateMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              final snap = _activeRescue!['vehicle_snapshot'] as Map<String, dynamic>?;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DispatchScreen(
                                    selectedFault: _activeRescue!['fault_type'] ?? 'General',
                                    vehicleType: snap?['vehicle_type'] ?? 'Passenger Car',
                                    licensePlate: snap?['plate'] ?? '',
                                    symptoms: const [],
                                    isHighPriority: _activeRescue!['is_high_priority'] == true,
                                    existingRequestId: _activeRescue!['id'],
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.radar, color: Colors.white, size: 16),
                            label: const Text(
                              'OPEN LIVE RADAR & TELEMETRY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.caliperCrimson,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
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
                            const Expanded(
                              child: Row(
                                children: [
                                  CircleAvatar(radius: 4, backgroundColor: AppColors.emeraldDark),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'NO ACTIVE DISPATCH',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.emeraldDark,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'STANDBY READY',
                                style: TextStyle(
                                  color: AppColors.slateMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'All roadside rescues completed',
                          style: TextStyle(
                            color: AppColors.chassisText,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Your emergency radar is calibrated. If your vehicle breaks down, trigger SOS on Home.',
                          style: TextStyle(color: AppColors.slateMuted, fontSize: 11.5, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Past Rescues',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.chassisText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_pastRescues.isEmpty && displayItems.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceTint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Sample Data',
                          style: TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // History List Items or Honest Empty State
                if (displayItems.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.slateBorder),
                    ),
                    child: Column(
                      children: const [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 36,
                          color: AppColors.slateMuted,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No past rescues yet',
                          style: TextStyle(
                            color: AppColors.chassisText,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your completed dispatches and digital invoices will appear here once settled.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = displayItems[index];
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
                                  color: AppColors.crimsonHover,
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
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item['location']} • ${item['date']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.slateMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    item['amount'] as String,
                                    style: const TextStyle(
                                      color: AppColors.chassisText,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'View Receipt',
                                        style: TextStyle(
                                          color: AppColors.crimsonHover,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(
                                        Icons.chevron_right,
                                        color: AppColors.crimsonHover,
                                        size: 15,
                                      ),
                                    ],
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
      ),
    );
  }
}
