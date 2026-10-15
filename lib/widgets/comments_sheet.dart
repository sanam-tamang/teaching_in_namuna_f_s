import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:social/pages/profile_page.dart';
import 'package:social/utils/app_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final int initialCommentCount;
  final ValueChanged<int> onCommentCountChanged;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.initialCommentCount,
    required this.onCommentCountChanged,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  RealtimeChannel? _commentsChannel;

  @override
  void initState() {
    super.initState();
    _fetchComments();
    _setupRealtime();
  }

  void _setupRealtime() {
    _commentsChannel = Supabase.instance.client
        .channel('comments_realtime_${widget.postId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: widget.postId,
          ),
          callback: (payload) async {
            final newId = payload.newRecord['id'];
            if (newId == null) return;
            // Avoid duplicate if already inserted optimistically
            if (_comments.any((c) => c['id'] == newId)) return;

            try {
              final fetched = await Supabase.instance.client
                  .from('comments')
                  .select('*, profiles(*)')
                  .eq('id', newId)
                  .maybeSingle();
              if (fetched != null && mounted) {
                setState(() {
                  _comments.add(fetched);
                });
                widget.onCommentCountChanged(_comments.length);
                _scrollToBottom();
              }
            } catch (_) {}
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: widget.postId,
          ),
          callback: (payload) {
            final oldId = payload.oldRecord['id'];
            if (oldId != null && mounted) {
              setState(() {
                _comments.removeWhere((c) => c['id'] == oldId);
              });
              widget.onCommentCountChanged(_comments.length);
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    if (_commentsChannel != null) {
      Supabase.instance.client.removeChannel(_commentsChannel!);
    }
    _commentController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await Supabase.instance.client
          .from('comments')
          .select('*, profiles(*)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
        widget.onCommentCountChanged(_comments.length);
        _scrollToBottom();
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

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) {
      Fluttertoast.showToast(msg: "Please sign in to comment");
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final inserted = await client
          .from('comments')
          .insert({
            'post_id': widget.postId,
            'user_id': currentUserId,
            'content': text,
          })
          .select('*, profiles(*)')
          .single();

      _commentController.clear();
      HapticFeedback.lightImpact();

      if (mounted) {
        setState(() {
          _comments.add(inserted);
        });
        widget.onCommentCountChanged(_comments.length);
        _scrollToBottom();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to post comment: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      HapticFeedback.mediumImpact();
      await Supabase.instance.client
          .from('comments')
          .delete()
          .eq('id', commentId);

      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c['id'] == commentId);
        });
        widget.onCommentCountChanged(_comments.length);
        Fluttertoast.showToast(msg: "Comment deleted");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to delete comment: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
            // Top Drag Handle & Title Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
              child: Row(
                children: [
                  Text(
                    'Comments',
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
                      '${_comments.length}',
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

            // Comments List Content
            Expanded(
              child: _buildBody(colorScheme, theme, currentUserId),
            ),

            const Divider(height: 1),

            // Bottom Comment Input Box (adjusts for on-screen keyboard)
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom: bottomInset + 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 14,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSubmitting ? null : _submitComment,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    ColorScheme colorScheme,
    ThemeData theme,
    String? currentUserId,
  ) {
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
                'Could not load comments',
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
                onPressed: _fetchComments,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No comments yet',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to share your thoughts!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _comments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final comment = _comments[index];
        final profileData = comment['profiles'];
        final profile = profileData is Map<String, dynamic>
            ? profileData
            : (profileData is Map ? Map<String, dynamic>.from(profileData) : null);

        final fullName = (profile?['full_name'] as String?)?.trim();
        final displayName = (fullName != null && fullName.isNotEmpty)
            ? fullName
            : 'Anonymous User';
        final avatarUrl = AppUtils.resolveStorageUrl(
          profile?['image_url'] as String?,
        );
        final timeAgo = AppUtils.formatTimeAgo(comment['created_at']);
        final content = comment['content'] as String? ?? '';
        final isOwner = currentUserId != null &&
            comment['user_id'] == currentUserId;

        final commenterUserId = comment['user_id'] as String?;
        void openCommenterProfile() {
          if (commenterUserId != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProfilePage(userId: commenterUserId),
              ),
            );
          }
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: openCommenterProfile,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        AppUtils.getInitials(displayName),
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: openCommenterProfile,
                        child: Text(
                          displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (timeAgo.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (isOwner)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: colorScheme.outline,
                          ),
                          onPressed: () => _deleteComment(comment['id']),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.35,
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
