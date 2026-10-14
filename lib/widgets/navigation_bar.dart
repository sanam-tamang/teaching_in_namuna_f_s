import 'package:flutter/material.dart';
import 'package:social/pages/home_page.dart';
import 'package:social/pages/post_create_page.dart';

class AppNavigationBar extends StatefulWidget {
  const new({super.key});

  @override
  State<AppNavigationBar> createState() => _AppNavigationBarState();
}

class _AppNavigationBarState extends State<AppNavigationBar> {
  final List<Widget> _bodyWidgets = [HomePage(), Container(color: Colors.red)];
  int _currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _bodyWidgets[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => PostCreatePage()));
        },
        child: Icon(Icons.add),
      ),
      floatingActionButtonLocation: .centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),

        color: Colors.grey.shade200,
        notchMargin: 10,

        child: NavigationBar(
          backgroundColor: Colors.transparent,

          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: [
            NavigationDestination(icon: Icon(Icons.home), label: "Home"),
            NavigationDestination(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }
}
