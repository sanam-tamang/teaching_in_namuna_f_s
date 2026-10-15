import 'package:supabase_flutter/supabase_flutter.dart';

class AppUtils {
  AppUtils._();

  /// Resolves relative Supabase storage paths or full URLs to a valid public URL.
  static String? resolveStorageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    try {
      return Supabase.instance.client.storage
          .from('social_files')
          .getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  /// Formats raw timestamp into human-readable relative time string.
  static String formatTimeAgo(dynamic rawDate) {
    if (rawDate == null) return '';
    DateTime? date;
    if (rawDate is DateTime) {
      date = rawDate;
    } else if (rawDate is String) {
      date = DateTime.tryParse(rawDate);
    }
    if (date == null) return '';

    final now = DateTime.now().toUtc();
    final diff = now.difference(date.toUtc());

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// Extracts up to 2 uppercase initials from a full name.
  static String getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
