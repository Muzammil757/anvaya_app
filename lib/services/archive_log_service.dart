// archive_log_service.dart
//
// ANVAYA — local activity log backing the Archive / Vault screen.
//
// Persists a lightweight trail of real classroom activity (lecture
// delivery, worksheet generation/export, interactive commands) into the
// `activity_logs` table of the same on-device SQLite database
// DatabaseService already manages — entirely offline, no network call
// involved. This file owns reads/writes to that table; DatabaseService
// owns its schema/migration (see [DatabaseService.activityLogsTable]).
//
// HomeDashboard's Archive / Vault tab reads this back to replace what used
// to be static mock data for its three sections.

import 'database_service.dart';

/// One logged activity entry.
class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.details,
    required this.timestamp,
  });

  final int id;

  /// One of [ArchiveLogService.typeLecture],
  /// [ArchiveLogService.typeWorksheet], [ArchiveLogService.typeInteractive].
  final String type;

  final String title;
  final String? details;
  final DateTime timestamp;

  factory ActivityLogEntry.fromMap(Map<String, dynamic> map) {
    return ActivityLogEntry(
      id: map['id'] as int,
      type: map['type'] as String,
      title: map['title'] as String,
      details: map['details'] as String?,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ArchiveLogService {
  ArchiveLogService._();

  static const String typeLecture = 'lecture';
  static const String typeWorksheet = 'worksheet';
  static const String typeInteractive = 'interactive';

  static const String _table = DatabaseService.activityLogsTable;

  /// Records one activity entry. Failures are swallowed rather than
  /// rethrown — activity logging is a nice-to-have record of what
  /// happened, and must never crash or interrupt the actual classroom
  /// action (a lecture card turning, a worksheet exporting, a command
  /// firing) that triggered it.
  static Future<void> logActivity({
    required String type,
    required String title,
    String? details,
  }) async {
    try {
      final db = await DatabaseService.database;
      await db.insert(_table, {
        'type': type,
        'title': title,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Swallow — see doc comment above.
    }
  }

  /// The [limit] most recent entries of [type], newest first.
  static Future<List<ActivityLogEntry>> getRecentActivitiesByType(
    String type, {
    int limit = 20,
  }) async {
    final db = await DatabaseService.database;
    final rows = await db.query(
      _table,
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map(ActivityLogEntry.fromMap).toList();
  }

  /// The [limit] most recent entries across every type, newest first.
  static Future<List<ActivityLogEntry>> getRecentActivities({int limit = 20}) async {
    final db = await DatabaseService.database;
    final rows = await db.query(_table, orderBy: 'id DESC', limit: limit);
    return rows.map(ActivityLogEntry.fromMap).toList();
  }
}
