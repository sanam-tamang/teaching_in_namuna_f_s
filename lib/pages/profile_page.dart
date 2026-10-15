import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:social/pages/edit_profile_page.dart';
import 'package:social/pages/post_create_page.dart';
import 'package:social/pages/sign_in_page.dart';
import 'package:social/utils/app_utils.dart';
import 'package:social/widgets/post_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  bool _isGridView = false;

  String? get _targetUserId =>
      widget.userId ?? Supabase.instance.client.auth.currentUser?.id;

  bool get _isOwner {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return currentUserId != null && _targetUserId == currentUserId;
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadProfileData();
    }
  }

  Future<void> _loadProfileData() async {
    final targetId = _targetUserId;
    if (targetId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "No user specified and not signed in.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;

      // 1. Fetch profile info
      final profileResponse = await client
          .from('profiles')
          .select('*')
          .eq('id', targetId)
          .maybeSingle();

      // 2. Fetch user's posts
      final postsResponse = await client
          .from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .eq('user_id', targetId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _profile = profileResponse;
          _posts = List<Map<String, dynamic>>.from(postsResponse);
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

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignInPage()),
          (route) => false,
        );
      }
    }
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image, size: 60, color: Colors.white),
                  ),
                ),
              ),
            ),
            IconButton.filled(
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatJoinDate(dynamic createdAt) {
    if (createdAt == null) return '';
    DateTime? date;
    if (createdAt is DateTime) {
      date = createdAt;
    } else if (createdAt is String) {
      date = DateTime.tryParse(createdAt);
    }
    if (date == null) return '';

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return 'Joined ${months[date.month - 1]} ${date.year}';
  }

  int get _totalLikesReceived {
    int total = 0;
    for (final post in _posts) {
      final likes = post['likes'] as List?;
      if (likes != null) total += likes.length;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canPop = Navigator.of(context).canPop();

    final fullName = (_profile?['full_name'] as String?)?.trim();
    final displayName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : (_isOwner
            ? (Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'] as String? ?? 'My Profile')
            : 'User Profile');

    final avatarUrl = AppUtils.resolveStorageUrl(_profile?['image_url'] as String?);
    final bio = (_profile?['bio'] as String?)?.trim();
    final joinDate = _formatJoinDate(_profile?['created_at']);
    final currentUserEmail = _isOwner ? Supabase.instance.client.auth.currentUser?.email : null;

    return Scaffold(
      appBar: AppBar(
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          _isOwner ? 'My Profile' : displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.of(context)
                      .push(
                    MaterialPageRoute(
                      builder: (context) => EditProfilePage(
                        currentFullName: displayName,
                        currentBio: bio,
                        currentImageUrl: _profile?['image_url'] as String?,
                      ),
                    ),
                  )
                      .then((updated) {
                    if (updated == true) {
                      _loadProfileData();
                    }
                  });
                } else if (value == 'sign_out') {
                  _confirmSignOut();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Edit Profile'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'sign_out',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Sign Out', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfileData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                          const SizedBox(height: 12),
                          Text('Failed to load profile', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.outline)),
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            onPressed: _loadProfileData,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      // Header details
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar & Name Row
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: avatarUrl != null ? () => _showImagePreview(avatarUrl) : null,
                                    child: CircleAvatar(
                                      radius: 42,
                                      backgroundColor: colorScheme.primaryContainer,
                                      backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                                      child: avatarUrl == null
                                          ? Text(
                                              AppUtils.getInitials(displayName),
                                              style: TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onPrimaryContainer,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: theme.textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (currentUserEmail != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.email_outlined, size: 14, color: colorScheme.outline),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  currentUserEmail,
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: colorScheme.outline,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (joinDate.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today_outlined, size: 13, color: colorScheme.outline),
                                              const SizedBox(width: 4),
                                              Text(
                                                joinDate,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: colorScheme.outline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Bio Section
                              if (bio != null && bio.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    bio,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),

                              // Stats Row
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      theme,
                                      colorScheme,
                                      title: 'Posts',
                                      value: _posts.length.toString(),
                                      icon: Icons.grid_on_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatCard(
                                      theme,
                                      colorScheme,
                                      title: 'Likes',
                                      value: _totalLikesReceived.toString(),
                                      icon: Icons.favorite_border,
                                    ),
                                  ),
                                ],
                              ),

                              // Edit Profile button for owner
                              if (_isOwner) ...[
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context)
                                          .push(
                                        MaterialPageRoute(
                                          builder: (context) => EditProfilePage(
                                            currentFullName: displayName,
                                            currentBio: bio,
                                            currentImageUrl: _profile?['image_url'] as String?,
                                          ),
                                        ),
                                      )
                                          .then((updated) {
                                        if (updated == true) {
                                          _loadProfileData();
                                        }
                                      });
                                    },
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    label: const Text('Edit Profile'),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 10),

                              // Posts tab header & view toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.photo_library_outlined, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Posts',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_posts.length}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_posts.isNotEmpty)
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.feed_outlined,
                                            color: !_isGridView ? colorScheme.primary : colorScheme.outline,
                                          ),
                                          onPressed: () => setState(() => _isGridView = false),
                                          tooltip: 'Feed View',
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.grid_view_rounded,
                                            color: _isGridView ? colorScheme.primary : colorScheme.outline,
                                          ),
                                          onPressed: () => setState(() => _isGridView = true),
                                          tooltip: 'Grid View',
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Posts display
                      if (_posts.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.article_outlined,
                                    size: 56,
                                    color: colorScheme.outline.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _isOwner ? "You haven't posted anything yet" : "No posts yet",
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (_isOwner) ...[
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      onPressed: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(builder: (context) => const PostCreatePage()),
                                        );
                                        _loadProfileData();
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('Create a Post'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (_isGridView)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final post = _posts[index];
                                final imageUrl = AppUtils.resolveStorageUrl(post['image_url'] as String?);
                                final content = post['content'] as String? ?? '';

                                return GestureDetector(
                                  onTap: () {
                                    setState(() => _isGridView = false);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: imageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => const Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                                          )
                                        : Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text(
                                                content,
                                                maxLines: 4,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                  ),
                                );
                              },
                              childCount: _posts.length,
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final post = _posts[index];
                              return PostCard(
                                key: ValueKey(post['id']),
                                post: post,
                              );
                            },
                            childCount: _posts.length,
                          ),
                        ),

                      const SliverToBoxAdapter(
                        child: SizedBox(height: 32),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    ColorScheme colorScheme, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
