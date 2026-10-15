import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:social/pages/profile_page.dart';
import 'package:social/utils/app_utils.dart';
import 'package:social/widgets/comments_sheet.dart';
import 'package:social/widgets/likes_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with TickerProviderStateMixin {
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _isLiking = false;

  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartOpacityAnimation;
  bool _showBurstHeart = false;

  late AnimationController _likeBtnAnimController;
  late Animation<double> _likeBtnScaleAnimation;

  RealtimeChannel? _postChannel;

  @override
  void initState() {
    super.initState();
    _initLikesAndComments();
    _initAnimations();
    _setupRealtime();
  }

  void _initAnimations() {
    // Burst heart animation on image double-tap
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_heartAnimController);

    _heartOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_heartAnimController);

    _heartAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _showBurstHeart = false;
        });
      }
    });

    // Like button bounce animation
    _likeBtnAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _likeBtnScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_likeBtnAnimController);
  }

  void _setupRealtime() {
    final postId = widget.post['id'].toString();
    _postChannel = Supabase.instance.client
        .channel('post_realtime_$postId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) {
            _syncLikesCount();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) {
            _syncCommentsCount();
          },
        )
        .subscribe();
  }

  Future<void> _syncLikesCount() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final likes = await Supabase.instance.client
          .from('likes')
          .select('user_id')
          .eq('post_id', widget.post['id']);
      if (mounted) {
        final list = List<Map<String, dynamic>>.from(likes);
        setState(() {
          _likeCount = list.length;
          _isLiked = currentUserId != null &&
              list.any((item) => item['user_id'] == currentUserId);
        });
      }
    } catch (_) {}
  }

  Future<void> _syncCommentsCount() async {
    try {
      final count = await Supabase.instance.client
          .from('comments')
          .count(CountOption.exact)
          .eq('post_id', widget.post['id']);
      if (mounted) {
        setState(() {
          _commentCount = count;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _initLikesAndComments();
    }
  }

  @override
  void dispose() {
    _heartAnimController.dispose();
    _likeBtnAnimController.dispose();
    if (_postChannel != null) {
      Supabase.instance.client.removeChannel(_postChannel!);
    }
    super.dispose();
  }

  void _initLikesAndComments() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final likesList = widget.post['likes'] as List?;
    if (likesList != null) {
      _likeCount = likesList.length;
      _isLiked = currentUserId != null &&
          likesList.any((item) => item['user_id'] == currentUserId);
    } else {
      _likeCount = 0;
      _isLiked = false;
    }

    final commentsList = widget.post['comments'] as List?;
    _commentCount = commentsList?.length ?? 0;
  }

  void _triggerBurstHeart() {
    HapticFeedback.mediumImpact();
    setState(() {
      _showBurstHeart = true;
    });
    _heartAnimController.forward(from: 0.0);
    if (!_isLiked) {
      _toggleLike();
    }
  }

  Future<void> _toggleLike() async {
    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to like posts')),
        );
      }
      return;
    }

    if (_isLiking) return;
    _isLiking = true;

    final wasLiked = _isLiked;
    final previousCount = _likeCount;

    // Trigger bounce animation & haptic feedback
    _likeBtnAnimController.forward(from: 0.0);
    HapticFeedback.lightImpact();

    // Optimistic UI update
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final postId = widget.post['id'];
      if (_isLiked) {
        await client.from('likes').insert({
          'post_id': postId,
          'user_id': currentUserId,
        });
      } else {
        await client
            .from('likes')
            .delete()
            .match({'post_id': postId, 'user_id': currentUserId});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = previousCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: $e')),
        );
      }
    } finally {
      _isLiking = false;
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(
        postId: widget.post['id'].toString(),
        initialCommentCount: _commentCount,
        onCommentCountChanged: (newCount) {
          if (mounted) {
            setState(() {
              _commentCount = newCount;
            });
          }
        },
      ),
    );
  }

  void _openLikes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LikesSheet(
        postId: widget.post['id'].toString(),
        initialLikeCount: _likeCount,
      ),
    );
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

    final profileAvatarUrl = AppUtils.resolveStorageUrl(
      profile?['image_url'] as String?,
    );
    final postImageUrl = AppUtils.resolveStorageUrl(
      widget.post['image_url'] as String?,
    );
    final content = widget.post['content'] as String? ?? '';
    final createdAt = widget.post['created_at'];
    final timeAgo = AppUtils.formatTimeAgo(createdAt);

    final authorUserId =
        (widget.post['user_id'] as String?) ?? (profile?['id'] as String?);

    void openAuthorProfile() {
      if (authorUserId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProfilePage(userId: authorUserId),
          ),
        );
      }
    }

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
                GestureDetector(
                  onTap: openAuthorProfile,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: profileAvatarUrl != null
                        ? NetworkImage(profileAvatarUrl)
                        : null,
                    child: profileAvatarUrl == null
                        ? Text(
                            AppUtils.getInitials(displayName),
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: openAuthorProfile,
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
                onDoubleTap: _triggerBurstHeart,
                onTap: () => _showImagePreview(context, postImageUrl),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 420),
                  width: double.infinity,
                  color: colorScheme.surfaceContainerHighest,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.network(
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
                      if (_showBurstHeart)
                        FadeTransition(
                          opacity: _heartOpacityAnimation,
                          child: ScaleTransition(
                            scale: _heartScaleAnimation,
                            child: const Icon(
                              Icons.favorite,
                              size: 96,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 20,
                                  color: Colors.black45,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Footer Actions: Like, Comment, Share, Bookmark
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                // Like Button (Animated Icon + Clickable Count)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _toggleLike,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: ScaleTransition(
                          scale: _likeBtnScaleAnimation,
                          child: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 22,
                            color: _isLiked
                                ? Colors.red
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        if (_likeCount > 0) {
                          _openLikes();
                        } else {
                          _toggleLike();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Text(
                          '$_likeCount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _isLiked
                                ? Colors.red
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Comment Button
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _openComments,
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
                          _commentCount > 0 ? '$_commentCount' : 'Reply',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
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
