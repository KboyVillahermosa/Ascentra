import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';

class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This would normally come from a database
    // We're just creating dummy data for demonstration
    final List<Activity> activities = [
      // Example activities (in a real app, these would come from storage)
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: activities.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_run, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No activities yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start recording your first activity!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return ActivityListItem(activity: activity);
              },
            ),
    );
  }
}

class ActivityListItem extends StatelessWidget {
  final Activity activity;
  
  const ActivityListItem({super.key, required this.activity});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_run, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Trail Run',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, yyyy').format(activity.date),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActivityStat('Distance', '${activity.distance.toStringAsFixed(2)} km'),
                _buildActivityStat('Time', _formatDuration(activity.duration)),
                _buildActivityStat('Pace', activity.paceString),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActivityStat('Elevation', '+${activity.elevationGain.toStringAsFixed(0)} m'),
                _buildActivityStat('Avg Speed', '${activity.avgSpeed.toStringAsFixed(1)} km/h'),
                _buildActivityStat('Calories', '${activity.calories} kcal'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivityStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}