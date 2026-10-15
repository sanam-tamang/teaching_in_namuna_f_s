import 'package:flutter_test/flutter_test.dart';
import 'package:social/utils/app_utils.dart';

void main() {
  group('AppUtils Tests', () {
    test('getInitials formats names correctly', () {
      expect(AppUtils.getInitials('John Doe'), 'JD');
      expect(AppUtils.getInitials('Alice'), 'A');
      expect(AppUtils.getInitials('  Bob   Marley  '), 'BM');
      expect(AppUtils.getInitials(''), '?');
    });

    test('formatTimeAgo handles relative times', () {
      final now = DateTime.now().toUtc();
      expect(AppUtils.formatTimeAgo(now.subtract(const Duration(seconds: 10))), 'Just now');
      expect(AppUtils.formatTimeAgo(now.subtract(const Duration(minutes: 5))), '5m ago');
      expect(AppUtils.formatTimeAgo(now.subtract(const Duration(hours: 3))), '3h ago');
      expect(AppUtils.formatTimeAgo(now.subtract(const Duration(days: 2))), '2d ago');
      expect(AppUtils.formatTimeAgo(null), '');
    });

    test('resolveStorageUrl returns direct urls as-is', () {
      expect(AppUtils.resolveStorageUrl('https://example.com/image.png'), 'https://example.com/image.png');
      expect(AppUtils.resolveStorageUrl('http://example.com/image.png'), 'http://example.com/image.png');
      expect(AppUtils.resolveStorageUrl(null), isNull);
      expect(AppUtils.resolveStorageUrl('   '), isNull);
    });
  });
}
