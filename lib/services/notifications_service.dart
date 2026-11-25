import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'demo_session.dart';
import 'supabase_service.dart';

/// Persistent notification entry displayed in [NotificationsBottomSheet].
class RoadixNotificationItem {
  final String id;
  final String category;
  final String title;
  final String body;
  final String timestampLabel;
  final bool isUnread;

  const RoadixNotificationItem({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.timestampLabel,
    required this.isUnread,
  });

  RoadixNotificationItem copyWith({bool? isUnread}) {
    return RoadixNotificationItem(
      id: id,
      category: category,
      title: title,
      body: body,
      timestampLabel: timestampLabel,
      isUnread: isUnread ?? this.isUnread,
    );
  }
}

/// Manages live user notifications derived from recent rescue activity and
/// persistent read-state stored via `flutter_secure_storage`.
class NotificationsService {
  NotificationsService._();

  static const _storageKey = 'roadix_read_notification_ids';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Loads live notifications from the user's Supabase rescue requests (or
  /// active demo session), preserving persisted read state across launches.
  static Future<List<RoadixNotificationItem>> loadNotifications({
    SupabaseService? db,
    Set<String>? readIdsOverride,
  }) async {
    final service = db ?? SupabaseService();
    final readIds = readIdsOverride ?? await _loadReadIds();
    final items = <RoadixNotificationItem>[];

    if (service.isAuthenticated || DemoSession.isActive) {
      final active = await service.getActiveServiceRequest();
      if (active != null) {
        final code = active['request_code']?.toString() ?? 'Active Rescue';
        final fault = active['fault_type']?.toString() ?? 'Roadside Assistance';
        final status = active['status']?.toString() ?? 'searching';
        final id = 'req_active_${active['id'] ?? code}_$status';
        items.add(
          RoadixNotificationItem(
            id: id,
            category: 'Dispatch',
            title: '$fault ($code)',
            body: 'Current dispatch status: ${status.replaceAll('_', ' ')}.',
            timestampLabel: 'Active now',
            isUnread: !readIds.contains(id),
          ),
        );
      }

      final history = await service.getServiceRequestHistory();
      for (final row in history.take(10)) {
        final code = row['request_code']?.toString() ?? row['id']?.toString() ?? 'RDX';
        final fault = row['fault_type']?.toString() ?? 'Roadside Service';
        final status = row['status']?.toString() ?? 'completed';
        final id = 'req_hist_${row['id'] ?? code}_$status';
        final createdAt = row['created_at']?.toString() ?? '';
        final label = createdAt.length >= 10 ? createdAt.substring(0, 10) : 'Recent';
        items.add(
          RoadixNotificationItem(
            id: id,
            category: status == 'completed' ? 'Receipt' : 'Update',
            title: '$fault — $code',
            body: 'Status: ${status.replaceAll('_', ' ')} at ${row['breakdown_address'] ?? 'roadside location'}.',
            timestampLabel: label,
            isUnread: !readIds.contains(id),
          ),
        );
      }
    }

    // Highway safety baseline notice when account has no recent events yet
    if (items.isEmpty) {
      const welcomeId = 'roadix_safety_999_notice';
      items.add(
        RoadixNotificationItem(
          id: welcomeId,
          category: 'Safety',
          title: 'Bangladesh Highway 999 Ready',
          body: 'GPS breakdown dispatch and National Emergency 999 SOS are active.',
          timestampLabel: 'System',
          isUnread: !readIds.contains(welcomeId),
        ),
      );
    }

    return items;
  }

  /// Marks all given notification IDs as read persistently.
  static Future<void> markAllAsRead(Iterable<String> ids) async {
    final existing = await _loadReadIds();
    existing.addAll(ids);
    await _saveReadIds(existing);
  }

  /// Marks a single notification ID as read persistently.
  static Future<void> markAsRead(String id) async {
    final existing = await _loadReadIds();
    existing.add(id);
    await _saveReadIds(existing);
  }

  /// Returns true when at least one notification is currently unread.
  static Future<bool> hasUnreadNotifications({SupabaseService? db}) async {
    final list = await loadNotifications(db: db);
    return list.any((item) => item.isUnread);
  }

  static Future<Set<String>> _loadReadIds() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  static Future<void> _saveReadIds(Set<String> ids) async {
    try {
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(ids.toList()),
      );
    } catch (_) {}
  }
}
