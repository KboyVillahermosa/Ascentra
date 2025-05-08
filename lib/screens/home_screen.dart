import 'package:flutter/material.dart';
import '../data/trails_data.dart';
import '../models/trail.dart';
import 'trail_detail_screen.dart';
import 'login_screen.dart';
import 'record_screen.dart';
import 'activity_history_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  
  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Trail> trails = []; // Initialize with empty list
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    trails = TrailsData.getTrails(); // Load the data
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    // Navigate to different screens based on the selected tab
    switch (index) {
      case 0: // Home tab - stay on this screen
        setState(() {
          _selectedIndex = 0;
        });
        break;
      case 1: // Record tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RecordScreen()),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
      case 2: // History tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ActivityHistoryScreen()),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
      case 3: // Profile tab
        // You can create a separate profile screen or show a dialog
        _showProfileDialog();
        break;
    }
  }
  
  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.username}\'s Profile'),
        content: const Text('Profile details coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Welcome, ${widget.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Cebu Hiking Trails',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: trails.isEmpty 
                ? const Center(child: Text('No trails available'))
                : ListView.builder(
                    itemCount: trails.length,
                    itemBuilder: (context, index) {
                      final trail = trails[index];
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Add image at the top of the card
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              child: Image.asset(
                                trail.image,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 150,
                                    color: Colors.grey[300],
                                    child: const Center(child: Text('Image not available')),
                                  );
                                },
                              ),
                            ),
                            ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                trail.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text('📍 ${trail.location}'),
                                  const SizedBox(height: 4),
                                  Text('🗻 Elevation: ${trail.elevation} meters'),
                                  const SizedBox(height: 4),
                                  Text('⚠️ Difficulty: ${trail.difficulty}'),
                                ],
                              ),
                              isThreeLine: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TrailDetailScreen(trail: trail),
                                  ),
                                );
                              },
                              trailing: const Icon(Icons.arrow_forward_ios),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Important for 4+ items
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}