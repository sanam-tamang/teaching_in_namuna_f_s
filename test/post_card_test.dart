import 'package:flutter_test/flutter_test.dart';
import 'package:social/utils/app_utils.dart';

void main() {
  group('Post and Interaction Helpers', () {
    test('Correctly extracts initials for various display names', () {
      expect(AppUtils.getInitials('John Doe'), 'JD');
      expect(AppUtils.getInitials('Sanam Tamang'), 'ST');
      expect(AppUtils.getInitials('SingleName'), 'S');
      expect(AppUtils.getInitials(''), '?');
    });

    test('Formats time ago strings cleanly', () {
      final now = DateTime.now().toUtc();
      expect(
        AppUtils.formatTimeAgo(now.subtract(const Duration(seconds: 15))),
        'Just now',
      );
      expect(
        AppUtils.formatTimeAgo(now.subtract(const Duration(minutes: 10))),
        '10m ago',
      );
      expect(
        AppUtils.formatTimeAgo(now.subtract(const Duration(hours: 4))),
        '4h ago',
      );
      expect(
        AppUtils.formatTimeAgo(now.subtract(const Duration(days: 3))),
        '3d ago',
      );
    });

    test('Extracts like counts and user like status from post map', () {
      final postData = {
        'id': 'post-123',
        'content': 'Test post content',
        'likes': [
          {'user_id': 'user-1'},
          {'user_id': 'user-2'},
        ],
        'comments': [
          {'id': 'comm-1'},
          {'id': 'comm-2'},
          {'id': 'comm-3'},
        ],
      };

      final likesList = postData['likes'] as List;
      final commentsList = postData['comments'] as List;

      expect(likesList.length, 2);
      expect(commentsList.length, 3);
      expect(likesList.any((l) => l['user_id'] == 'user-1'), isTrue);
      expect(likesList.any((l) => l['user_id'] == 'user-3'), isFalse);
    });
  });
}
