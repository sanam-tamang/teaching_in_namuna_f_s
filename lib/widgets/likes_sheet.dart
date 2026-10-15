import 'package:flutter/material.dart';
import 'package:social/utils/app_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LikesSheet extends StatefulWidget {
  final String postId;
  final int initialLikeCount;

  const LikesSheet({
    super.key,
    required this.postId,
    required this.initialLikeCount,
  });

  @override
  State<LikesSheet> createState() => _LikesSheetState();
}

class _LikesSheetState extends State<LikesSheet> {
  List<Map<String, dynamic>> _likers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLikers();
  }

  Future<void> _fetchLikers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await Supabase.instance.client
          .from('likes')
          .select('id, created_at, profiles(id, full_name, image_url)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _likers = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle & Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.red, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Likes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_isLoading ? widget.initialLikeCount : _likers.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: colorScheme.onSurfaceVariant,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Expanded(
              child: _buildBody(colorScheme, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Could not load likes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _fetchLikers,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_likers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 48,
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No likes yet',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to like this post!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _likers.length,
      separatorBuilder: (context, index) => const Divider(height: 16),
      itemBuilder: (context, index) {
        final item = _likers[index];
        final profileData = item['profiles'];
        final profile = profileData is Map<String, dynamic>
            ? profileData
            : (profileData is Map
                ? Map<String, dynamic>.from(profileData)
                : null);

        final fullName = (profile?['full_name'] as String?)?.trim();
        final displayName = (fullName != null && fullName.isNotEmpty)
            ? fullName
            : 'Anonymous User';
        final avatarUrl = AppUtils.resolveStorageUrl(
          profile?['image_url'] as String?,
        );
        final timeAgo = AppUtils.formatTimeAgo(item['created_at']);

        return Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      AppUtils.getInitials(displayName),
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (timeAgo.isNotEmpty)
                    Text(
                      'Liked $timeAgo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
