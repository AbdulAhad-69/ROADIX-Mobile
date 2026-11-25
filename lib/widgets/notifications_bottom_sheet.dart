import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notifications_service.dart';
import '../theme/app_colors.dart';

class NotificationsBottomSheet extends StatefulWidget {
  final Future<List<RoadixNotificationItem>> Function()? loadOverride;
  final Future<void> Function(Iterable<String> ids)? markAllOverride;

  const NotificationsBottomSheet({
    super.key,
    this.loadOverride,
    this.markAllOverride,
  });

  @override
  State<NotificationsBottomSheet> createState() =>
      _NotificationsBottomSheetState();
}

class _NotificationsBottomSheetState extends State<NotificationsBottomSheet> {
  List<RoadixNotificationItem> _alerts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = widget.loadOverride != null
          ? await widget.loadOverride!()
          : await NotificationsService.loadNotifications();
      if (mounted) {
        setState(() {
          _alerts = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load notifications: $e';
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.selectionClick();
    final unreadIds =
        _alerts.where((a) => a.isUnread).map((a) => a.id).toList();
    setState(() {
      _alerts = _alerts.map((a) => a.copyWith(isUnread: false)).toList();
    });
    if (unreadIds.isNotEmpty) {
      if (widget.markAllOverride != null) {
        await widget.markAllOverride!(unreadIds);
      } else {
        await NotificationsService.markAllAsRead(unreadIds);
      }
    }
  }

  Future<void> _markSingleRead(int index) async {
    final item = _alerts[index];
    if (!item.isUnread) return;
    setState(() {
      _alerts[index] = item.copyWith(isUnread: false);
    });
    if (widget.markAllOverride != null) {
      await widget.markAllOverride!([item.id]);
    } else {
      await NotificationsService.markAsRead(item.id);
    }
  }

  IconData _iconForCategory(String category) {
    return switch (category.toLowerCase()) {
      'dispatch' => Icons.local_shipping_outlined,
      'receipt' => Icons.receipt_long_outlined,
      _ => Icons.shield_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _alerts.any((a) => a.isUnread);

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Notifications & Updates',
                    style: TextStyle(
                      color: AppColors.chassisText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (hasUnread)
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: const Text('Mark all read'),
                  ),
                IconButton(
                  tooltip: 'Close notifications',
                  onPressed: () => Navigator.pop(context, hasUnread),
                  icon: const Icon(Icons.close, color: AppColors.slateMuted),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.slateBorder, height: 1),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.caliperCrimson,
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.slateMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: _loadNotifications,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _alerts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final alert = _alerts[idx];
                          final isUnread = alert.isUnread;
                          return InkWell(
                            onTap: () => _markSingleRead(idx),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isUnread
                                    ? AppColors.porcelainBg
                                    : AppColors.cardWhite,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isUnread
                                      ? AppColors.crimsonBorder
                                      : AppColors.slateBorder,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isUnread
                                          ? AppColors.crimsonLight
                                          : AppColors.surfaceTint,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _iconForCategory(alert.category),
                                      color: isUnread
                                          ? AppColors.crimsonHover
                                          : AppColors.slateMuted,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isUnread
                                                    ? AppColors.crimsonLight
                                                    : AppColors.surfaceTint,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                alert.category,
                                                style: TextStyle(
                                                  color: isUnread
                                                      ? AppColors.crimsonHover
                                                      : AppColors.slateMuted,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              alert.timestampLabel,
                                              style: const TextStyle(
                                                color: AppColors.slateMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          alert.title,
                                          style: const TextStyle(
                                            color: AppColors.chassisText,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          alert.body,
                                          style: const TextStyle(
                                            color: AppColors.slateMuted,
                                            fontSize: 12.5,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
