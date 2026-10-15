import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social/utils/app_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  final String currentFullName;
  final String? currentBio;
  final String? currentImageUrl;

  const EditProfilePage({
    super.key,
    required this.currentFullName,
    this.currentBio,
    this.currentImageUrl,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;

  final ImagePicker _picker = ImagePicker();
  Uint8List? _newImageBytes;
  bool _removeCurrentImage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentFullName);
    _bioController = TextEditingController(text: widget.currentBio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _newImageBytes = bytes;
          _removeCurrentImage = false;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Could not select image: $e");
    }
  }

  void _showImageOptions() {
    final hasImage = (_newImageBytes != null) ||
        (widget.currentImageUrl != null && !_removeCurrentImage);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove Current Photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _newImageBytes = null;
                    _removeCurrentImage = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) {
      Fluttertoast.showToast(msg: "You must be logged in to update profile");
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? finalImagePath = widget.currentImageUrl;

      // 1. If photo was explicitly removed
      if (_removeCurrentImage) {
        finalImagePath = null;
      }

      // 2. If new image selected, upload binary
      if (_newImageBytes != null) {
        final ext = 'jpg';
        final fileName = 'avatar_${currentUserId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await client.storage
            .from('social_files')
            .uploadBinary(
              fileName,
              _newImageBytes!,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        finalImagePath = fileName;
      }

      final updatedName = _nameController.text.trim();
      final updatedBio = _bioController.text.trim();

      // 3. Update public.profiles table
      await client.from('profiles').update({
        'full_name': updatedName,
        'bio': updatedBio.isEmpty ? null : updatedBio,
        'image_url': finalImagePath,
      }).eq('id', currentUserId);

      // 4. Update auth user metadata for consistency
      try {
        await client.auth.updateUser(
          UserAttributes(data: {'full_name': updatedName}),
        );
      } catch (_) {
        // Metadata update failure is non-fatal
      }

      Fluttertoast.showToast(msg: "Profile updated successfully");
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update profile: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedUrl = AppUtils.resolveStorageUrl(widget.currentImageUrl);

    ImageProvider? imageProvider;
    if (_newImageBytes != null) {
      imageProvider = MemoryImage(_newImageBytes!);
    } else if (!_removeCurrentImage && resolvedUrl != null) {
      imageProvider = CachedNetworkImageProvider(resolvedUrl);
    }

    final displayName = _nameController.text.isNotEmpty
        ? _nameController.text
        : widget.currentFullName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with camera badge
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: imageProvider,
                      child: imageProvider == null
                          ? Text(
                              AppUtils.getInitials(displayName),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _isSaving ? null : _showImageOptions,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surface,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSaving ? null : _showImageOptions,
                child: const Text('Change Profile Picture'),
              ),
              const SizedBox(height: 24),

              // Full Name field
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter your name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (val) {
                  final text = val?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Please enter your name';
                  }
                  if (text.length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Bio field
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                maxLength: 160,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell the world a little about yourself...',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 58),
                    child: Icon(Icons.info_outline),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Bottom Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Saving Changes...' : 'Save Profile'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
