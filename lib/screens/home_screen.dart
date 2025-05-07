import 'package:flutter/material.dart';
import '../data/trails_data.dart';
import '../models/trail.dart';
import 'trail_detail_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  
  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Trail> trails = []; // Initialize with empty list
  
  @override
  void initState() {
    super.initState();
    trails = TrailsData.getTrails(); // Load the data
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
              child: ListView.builder(
                itemCount: trails.length,
                itemBuilder: (context, index) {
                  final trail = trails[index];
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: ListTile(
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}