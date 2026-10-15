import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    // Simple initial like placeholder simulation
    _likeCount = (widget.post['id'].hashCode.abs() % 12);
  }

  String? _resolveStorageUrl(String? path) {
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

  String _formatTimeAgo(dynamic rawDate) {
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

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              clipBehavior: Clip.none,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const Center(child: Text("Loading")),
                  errorWidget: (context, url, error) {
                    return const Icon(Icons.broken_image_outlined);
                  },
                ),
              ),
            ),
            IconButton.filled(
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Extract profile information joined via foreign key
    final profileData = widget.post['profiles'];
    final profile = profileData is Map<String, dynamic>
        ? profileData
        : (profileData is Map ? Map<String, dynamic>.from(profileData) : null);

    final fullName = (profile?['full_name'] as String?)?.trim();
    final displayName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : 'Anonymous User';

    final profileAvatarUrl = _resolveStorageUrl(
      profile?['image_url'] as String?,
    );
    final postImageUrl = _resolveStorageUrl(
      widget.post['image_url'] as String?,
    );
    final content = widget.post['content'] as String? ?? '';
    final createdAt = widget.post['created_at'];
    final timeAgo = _formatTimeAgo(createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Profile Avatar, Name, Time, and More Options
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: profileAvatarUrl != null
                      ? NetworkImage(profileAvatarUrl)
                      : null,
                  child: profileAvatarUrl == null
                      ? Text(
                          _getInitials(displayName),
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (timeAgo.isNotEmpty)
                        Text(
                          timeAgo,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  color: colorScheme.onSurfaceVariant,
                  onPressed: () {
                    // Context action sheet / dialog can be added here
                  },
                ),
              ],
            ),
          ),

          // Post Text Content
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  fontSize: 15,
                ),
              ),
            ),

          // Post Image (if present)
          if (postImageUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () => _showImagePreview(context, postImageUrl),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 420),
                  width: double.infinity,
                  color: colorScheme.surfaceContainerHighest,
                  child: Image.network(
                    postImageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        height: 220,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                      (progress.expectedTotalBytes ?? 1)
                                : null,
                            strokeWidth: 2.5,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 160,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 40,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Unable to load image',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // Footer Actions: Like, Comment, Share, Bookmark
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                // Like Button
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      _isLiked = !_isLiked;
                      _likeCount += _isLiked ? 1 : -1;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: _isLiked
                              ? Colors.red
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_likeCount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _isLiked
                                ? Colors.red
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Comment Button
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 19,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Reply',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Share Button
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  color: colorScheme.onSurfaceVariant,
                  tooltip: 'Share',
                  onPressed: () {},
                ),

                const Spacer(),

                // Bookmark / Save
                IconButton(
                  icon: const Icon(Icons.bookmark_border, size: 20),
                  color: colorScheme.onSurfaceVariant,
                  tooltip: 'Save',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
