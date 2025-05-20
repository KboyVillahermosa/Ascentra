import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';

class SaveActivityScreen extends StatefulWidget {
  final Activity activity;

  const SaveActivityScreen({
    Key? key,
    required this.activity,
  }) : super(key: key);

  @override
  State<SaveActivityScreen> createState() => _SaveActivityScreenState();
}

class _SaveActivityScreenState extends State<SaveActivityScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _privateNotesController = TextEditingController();
  bool _isSaving = false;
  String _selectedActivityType = 'Run';
  String _selectedFeeling = '';

  @override
  void initState() {
    super.initState();
    // Initialize controllers with any existing data
    _titleController.text = widget.activity.name;
    _descriptionController.text = widget.activity.description;
    _privateNotesController.text = widget.activity.privateNotes;
    _selectedActivityType = widget.activity.activityType;
    _selectedFeeling = widget.activity.feeling;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _privateNotesController.dispose();
    super.dispose();
  }
  
  Future<void> _saveActivity() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Create a new Activity with the updated values instead of modifying directly
      final updatedActivity = Activity(
        id: widget.activity.id,
        userId: widget.activity.userId,
        name: _titleController.text.isNotEmpty
            ? _titleController.text
            : 'Activity ${DateTime.now().toString().substring(0, 16)}',
        date: widget.activity.date,
        durationInSeconds: widget.activity.durationInSeconds,
        distance: widget.activity.distance,
        elevationGain: widget.activity.elevationGain,
        avgPace: widget.activity.avgPace,
        routePoints: widget.activity.routePoints,
        description: _descriptionController.text,
        activityType: _selectedActivityType,
        feeling: _selectedFeeling,
        privateNotes: _privateNotesController.text,
        likedBy: widget.activity.likedBy,
      );
      
      final activityService = ActivityService();
      final result = await activityService.saveActivity(updatedActivity);
      
      if (result > 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity saved successfully!')),
        );
        
        // Instead of going back to the first route (login),
        // navigate to the activity history or just go back one screen
        Navigator.pop(context); // This goes back one screen
        
        // Or navigate to the activity history screen:
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (context) => ActivityHistoryScreen()),
        // );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save activity')),
        );
      }
    } catch (e) {
      print('Error saving activity: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Save Activity', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveActivity,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: _isSaving ? Colors.grey : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Activity title
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Title your run',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[800]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[800]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Activity description
              TextField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'How\'d it go? Share more about your activity and use @ to tag someone.',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[800]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[800]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Activity type selector
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[800]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: const Icon(Icons.directions_run, color: Colors.white),
                  title: Text(
                    _selectedActivityType,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  onTap: () => _showActivityTypeSelector(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Add photos/videos section
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.orange, 
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, color: Colors.orange, size: 40),
                      const SizedBox(height: 8),
                      const Text(
                        'Add Photos/Videos',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Change map type button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // Show map type selector
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Change Map Type'),
                ),
              ),
              const SizedBox(height: 24),
              
              // Details header
              const Text(
                'Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Type of run selector
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[800]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: const Icon(Icons.timeline, color: Colors.white),
                  title: const Text(
                    'Type of run',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  onTap: () {
                    // Show run type selector
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // How did that activity feel selector
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[800]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: const Icon(Icons.emoji_emotions, color: Colors.white),
                  title: const Text(
                    'How did that activity feel?',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  onTap: () => _showFeelingSelector(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Private notes
              TextField(
                controller: _privateNotesController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Jot down private notes here. Only you can see these.',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[800]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[800]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showActivityTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Run', style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    _selectedActivityType = 'Run';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Trail Run', style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    _selectedActivityType = 'Trail Run';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Walk', style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    _selectedActivityType = 'Walk';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Hike', style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    _selectedActivityType = 'Hike';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _showFeelingSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('😃 Great', style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    _selectedFeeling = 'Great';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('🙂 Good', style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    _selectedFeeling = 'Good';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('😐 Okay', style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    _selectedFeeling = 'Okay';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('😞 Bad', style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    _selectedFeeling = 'Bad';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}