import 'package:flutter/material.dart';
import 'package:musify/screens/first_screen.dart';
import 'package:musify/screens/library_screen.dart';
import 'package:musify/screens/upload_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    List<Widget> selectedPage = [
      const FirstScreen(),
      const UploadScreen(),
      const LikedSongsScreen()
    ];

    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music),
            label: 'Liked songs',
          ),
        ],
        selectedItemColor: Colors.purple,
        currentIndex: _selectedIndex,
        onTap: (value) {
          setState(() {
            _selectedIndex = value;
          });
        },
      ),
      body: selectedPage[_selectedIndex],
    );
  }
}
