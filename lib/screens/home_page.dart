import 'package:flutter/material.dart';
import 'today_screen.dart';
import 'add_habit_screen.dart';
import 'settings_screen.dart';
import 'step_counter_screen.dart';
import 'community_wall_screen.dart';

class HomePage extends StatefulWidget {
  final int userId;
  final String userName;
  final String userEmail;
  
  HomePage({required this.userId, this.userName = 'User', required this.userEmail});
  
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      TodayScreen(userId: widget.userId),
      Container(), // placeholder for FAB
      StepCounterScreen(userId: widget.userId),
      CommunityWallScreen(userId: widget.userId, userEmail: widget.userEmail),
      SettingsScreen(userId: widget.userId),
    ];
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AddHabitScreen(userId: widget.userId)))
          .then((_) {
        // Refresh the today screen when coming back from add habit
        setState(() {
          _selectedIndex = 0;
          _screens[0] = TodayScreen(userId: widget.userId, key: UniqueKey());
        });
      });
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 8,
        child: Container(
          height: 60,
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.today_rounded,
                label: "Tasks",
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.directions_walk_rounded,
                label: "Steps",
                index: 2,
              ),
              SizedBox(width: 60), // space for FAB
              _buildNavItem(
                icon: Icons.chat_bubble_rounded,
                label: "Wall",
                index: 3,
              ),
              _buildNavItem(
                icon: Icons.settings_rounded,
                label: "Settings",
                index: 4,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onItemTapped(1),
        child: Icon(Icons.add, size: 28),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // AppBar is provided by individual screens (Today, Settings)
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.deepPurple : Colors.grey[400],
              size: 28,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.deepPurple : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
