import 'package:flutter/material.dart';
import 'package:social/pages/home_page.dart';
import 'package:social/pages/sign_in_page.dart';
import 'package:social/widgets/navigation_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://rwglimsmxodfvidumqte.supabase.co',
    publishableKey: 'sb_publishable_5vUoRwT787jF4O0eTisStg_w64paGln',
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SocialApp',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: Supabase.instance.client.auth.currentSession != null
          ? AppNavigationBar()
          : SignInPage(),
    );
  }
}
