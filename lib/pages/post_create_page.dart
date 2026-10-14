import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:social/widgets/custom_text_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostCreatePage extends StatefulWidget {
  const new({super.key});

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create a post"),
        actions: [
          ElevatedButton(
            onPressed: () async {
              // print("inside");

              final client = Supabase.instance.client;
              try {
                setState(() {
                  _isLoading = true;
                });

                await client.from("posts").insert({
                  "content": _contentController.text,
                });

                Fluttertoast.showToast(msg: "Post created successful");
                Navigator.of(context).pop();
              } catch (e) {
                print(e.toString());
                Fluttertoast.showToast(msg: e.toString());
              } finally {
                // print("called finaly");
                setState(() {
                  _isLoading = false;
                });
              }
            },
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : Text("Publish"),
          ),

          SizedBox(width: 12),
        ],
      ),

      body: Padding(
        padding: .all(12),
        child: Column(
          children: [
            TextField(
              maxLines: null,
              controller: _contentController,
              decoration: InputDecoration(
                hintText: "Enter your content...",
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
