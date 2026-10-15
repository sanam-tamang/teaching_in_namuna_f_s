import 'package:flutter_test/flutter_test.dart';
import 'package:social/utils/app_utils.dart';

void main() {
  group('Profile Utilities & Formatting', () {
    test('displayName and initials fallback properly', () {
      final initials = AppUtils.getInitials('Sarah Connor');
      expect(initials, 'SC');

      final singleNameInitials = AppUtils.getInitials('Namuna');
      expect(singleNameInitials, 'N');

      final emptyInitials = AppUtils.getInitials('');
      expect(emptyInitials, '?');
    });

    test('resolveStorageUrl correctly handles relative paths and full URLs', () {
      expect(
        AppUtils.resolveStorageUrl('https://example.com/avatar.jpg'),
        'https://example.com/avatar.jpg',
      );
      expect(AppUtils.resolveStorageUrl(null), isNull);
      expect(AppUtils.resolveStorageUrl(''), isNull);
    });
  });
}
