import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social/widgets/custom_text_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostCreatePage extends StatefulWidget {
  const PostCreatePage({super.key}); // Fixed constructor name typo

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;

  // Image picker variables
  Uint8List? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Method to pick image from gallery
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _selectedImage = await pickedFile.readAsBytes();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create a post"),
        actions: [
          ElevatedButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Publish"),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Text Input
            TextField(
              maxLines: null,
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: "Enter your content...",
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16),

            // Image Preview & Remove Button
            if (_selectedImage != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _selectedImage!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                  ),
                ],
              ),

            const Spacer(),

            // Button to open gallery
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text("Add Image from Gallery"),
            ),
          ],
        ),
      ),
    );
  }

  // Handle post creation and image upload to Supabase
  Future<void> _createPost() async {
    final client = Supabase.instance.client;
    try {
      setState(() {
        _isLoading = true;
      });

      String? fileName;

      // 1. Upload image to Supabase Storage if selected
      if (_selectedImage != null) {
        fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        // Make sure you have created a public bucket named 'posts_bucket' in Supabase
        await client.storage
            .from('social_files')
            .uploadBinary(fileName, _selectedImage!); 

        // // Get public URL of the uploaded image
        // imageUrl = client.storage.from('posts_bucket').getPublicUrl(fileName);
      }

      // 2. Insert post data into 'posts' table
      await client.from("posts").insert({
        "content": _contentController.text,
        "image_url": fileName,
      });

      Fluttertoast.showToast(msg: "Post created successfully");
      Navigator.of(context).pop();
    } catch (e) {
      print(e.toString());
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
