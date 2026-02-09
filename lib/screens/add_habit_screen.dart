import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/notification_service.dart';
import '../services/local_task_service.dart';
import '../models/local_task.dart';

class AddHabitScreen extends StatefulWidget {
  final int userId;
  final Map? habit; // optional habit for editing
  const AddHabitScreen({required this.userId, this.habit, Key? key}) : super(key: key);

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController habitController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController targetController = TextEditingController(text: '1');

  TimeOfDay? selectedTime;
  final Set<String> selectedDays = {};
  bool hasReminder = false;
  String selectedIcon = 'directions_walk';
  String? selectedFrequency;
  late LocalTaskService localTaskService;
  bool isOnline = true;

  // Available frequency options
  final List<String> frequencyOptions = ['daily', 'weekly', 'monthly'];

  // Available icons for selection
  final List<Map<String, dynamic>> availableIcons = [
    {'name': 'directions_walk', 'icon': Icons.directions_walk},
    {'name': 'fitness_center', 'icon': Icons.fitness_center},
    {'name': 'local_drink', 'icon': Icons.local_drink},
    {'name': 'book', 'icon': Icons.book},
    {'name': 'self_improvement', 'icon': Icons.self_improvement},
    {'name': 'bedtime', 'icon': Icons.bedtime},
    {'name': 'restaurant', 'icon': Icons.restaurant},
    {'name': 'work', 'icon': Icons.work},
    {'name': 'school', 'icon': Icons.school},
    {'name': 'music_note', 'icon': Icons.music_note},
    {'name': 'brush', 'icon': Icons.brush},
    {'name': 'favorite', 'icon': Icons.favorite},
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    if (widget.habit != null) {
      _loadHabitData();
    }
  }

  Future<void> _initializeServices() async {
    localTaskService = LocalTaskService(userId: widget.userId);
    await localTaskService.init();
    
    final result = await Connectivity().checkConnectivity();
    setState(() {
      isOnline = result != ConnectivityResult.none;
    });
  }

  void _loadHabitData() {
    if (widget.habit == null) return;
    
    final habit = widget.habit!;
    habitController.text = habit['habit_name'] ?? habit['name'] ?? '';
    categoryController.text = habit['category'] ?? 'General';
    targetController.text = habit['target']?.toString() ?? '1';
    selectedFrequency = habit['frequency'] ?? 'daily';
    selectedIcon = habit['icon'] ?? 'directions_walk';
    hasReminder = (habit['has_reminder'] ?? 0) == 1 || habit['has_reminder'] == true;
    
    if (habit['reminder_time'] != null && habit['reminder_time'].toString().isNotEmpty) {
      try {
        final timeParts = habit['reminder_time'].toString().split(':');
        selectedTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      } catch (e) {
        print('Error parsing reminder time: $e');
      }
    }
    
    if (habit['reminder_days'] != null && habit['reminder_days'].toString().isNotEmpty) {
      setState(() {
        selectedDays.addAll(habit['reminder_days'].toString().split(',').map((d) => d.trim()));
      });
    }
  }

  /* -------------------- TIME PICKER -------------------- */

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  /* -------------------- DAY SELECT -------------------- */

  void _toggleDay(String day) {
    setState(() {
      selectedDays.contains(day)
          ? selectedDays.remove(day)
          : selectedDays.add(day);
    });
  }

  /* -------------------- FORMAT TIME FOR API -------------------- */

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
           '${time.minute.toString().padLeft(2, '0')}:00';
  }

  /* -------------------- NOTIFICATION HELPERS -------------------- */

  tz.TZDateTime _nextInstanceOfDay(TimeOfDay time, int weekday) {
    final now = tz.TZDateTime.now(tz.local);

    // Create today at the specified time
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    print('[Habit] _nextInstanceOfDay: time=$time, targetWeekday=$weekday');
    print('[Habit] Current: ${now.toString()}, scheduledStart: ${scheduled.toString()}');

    // If today is the target weekday and time is in future, use it
    if (scheduled.weekday == weekday && scheduled.isAfter(now)) {
      print('[Habit] Scheduling for TODAY at ${scheduled.toString()}');
      return scheduled;
    }

    // Find next occurrence of the target weekday
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
      print('[Habit] Searching... weekday=${scheduled.weekday}, date=${scheduled.toString()}');
    }

    // Ensure we don't schedule in the past (if we're on target weekday but time passed, go 7 days ahead)
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
      print('[Habit] Time was in past, moved 7 days forward');
    }

    print('[Habit] Final scheduled time: ${scheduled.toString()}');
    return scheduled;
  }

  /* -------------------- API CALL -------------------- */

  Future<void> addHabit() async {
    if (!_formKey.currentState!.validate()) return;
    if (hasReminder) {
      if (selectedTime == null || selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select reminder time & days")),
        );
        return;
      }
    }

    try {
      final isEditing = widget.habit != null;
      final reminderTime = hasReminder && selectedTime != null ? _formatTime(selectedTime!) : "";
      final reminderDays = hasReminder ? selectedDays.join(',') : "";

      // Create LocalTask object
      final localTask = LocalTask(
        id: isEditing ? int.tryParse(widget.habit!['id'].toString()) : null,
        userId: widget.userId,
        name: habitController.text,
        category: categoryController.text,
        frequency: selectedFrequency ?? 'daily',
        icon: selectedIcon,
        target: int.tryParse(targetController.text) ?? 1,
        reminderTime: reminderTime,
        hasReminder: hasReminder,
        daysSelected: reminderDays,
        createdAt: isEditing && widget.habit!['created_at'] != null
            ? DateTime.parse(widget.habit!['created_at'].toString())
            : DateTime.now(),
      );

      if (isOnline) {
        // Try online first
        await _addHabitOnline(localTask, isEditing);
      } else {
        // Save locally and mark for sync
        if (isEditing) {
          await localTaskService.updateTask(
            localTaskService.taskBox.values.toList().indexWhere(
              (t) => t.id == localTask.id && t.userId == widget.userId,
            ),
            localTask,
          );
        } else {
          await localTaskService.addTask(localTask);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Task saved offline. It will sync when you're online.")),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _addHabitOnline(LocalTask localTask, bool isEditing) async {
    final url = Uri.parse(isEditing
        ? "https://hackdefenders.com/Minahil/Habit/update_habit.php"
        : "https://hackdefenders.com/Minahil/Habit/add_habit.php");

    try {
      final body = {
        if (!isEditing) "user_id": widget.userId,
        if (isEditing) "habit_id": localTask.id,
        "habit_name": localTask.name,
        "category": localTask.category,
        "frequency_type": localTask.frequency,
        "target_count": localTask.target,
        "quantity": 1,
        "reminder_time": localTask.reminderTime,
        "reminder_days": localTask.daysSelected,
        "icon_name": localTask.icon,
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        final habitId = data['habit_id'] ?? localTask.id;

        // Save to local DB as synced
        if (!isEditing) {
          localTask.id = int.tryParse(habitId.toString());
          localTask.isSynced = true;
          localTask.syncStatus = 'synced';
          await localTaskService.addTask(localTask);
        } else {
          localTask.isSynced = true;
          localTask.syncStatus = 'synced';
          await localTaskService.updateTask(
            localTaskService.taskBox.values.toList().indexWhere(
              (t) => t.id == localTask.id && t.userId == widget.userId,
            ),
            localTask,
          );
        }

        // Schedule notifications if reminder enabled
        if (localTask.hasReminder && habitId != null) {
          await _scheduleNotifications(int.tryParse(habitId.toString()) ?? 0);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Success')),
        );

        Navigator.pop(context);
      } else {
        // Save locally and mark for sync
        await localTaskService.addTask(localTask);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Saved offline')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error adding habit online: $e");
      // Fallback to local save
      await localTaskService.addTask(localTask);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved offline. Will sync when online.")),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _scheduleNotifications(int habitId) async {
    final Map<String, int> dayMap = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    final List<String> dayOrder = [
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
    ];

    for (final day in selectedDays) {
      final dayIndex = dayOrder.indexOf(day);
      final notificationId = NotificationService().generateNotificationId(habitId, dayIndex);
      final scheduledDate = _nextInstanceOfDay(selectedTime!, dayMap[day]!);

      NotificationService().scheduleHabitReminder(
        id: notificationId,
        title: "Habit Reminder",
        body: "Time to do ${habitController.text}",
        scheduledTime: scheduledDate,
      );
    }
  }

  Future<void> _updateNotificationIds(int habitId, Map<String, int> notificationIds) async {
    final url = Uri.parse(
        "https://hackdefenders.com/Minahil/Habit/update_notification_ids.php");

    try {
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "habit_id": habitId,
          "notification_ids": jsonEncode(notificationIds),
        }),
      );
    } catch (e) {
      print("Error updating notification IDs: $e");
    }
  }

  /* -------------------- UI -------------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habit != null ? 'Edit Task' : 'Add New Task'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _input(
                        controller: habitController,
                        label: "Task Name",
                        icon: Icons.flag,
                        required: true,
                      ),
                      _input(
                        controller: categoryController,
                        label: "Category",
                        icon: Icons.category,
                      ),
                      _frequencyDropdown(),
                      _input(
                        controller: targetController,
                        label: "Target Count",
                        icon: Icons.format_list_numbered,
                        required: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _iconDropdown(),
                ),
              ),

              const SizedBox(height: 16),

              SwitchListTile(
                value: hasReminder,
                onChanged: (v) => setState(() => hasReminder = v),
                title: Text('Enable reminder'),
                secondary: Icon(Icons.notifications_active),
              ),

              if (hasReminder) ...[
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(
                    selectedTime == null
                        ? "Select reminder time"
                        : selectedTime!.format(context),
                  ),
                  onTap: _selectTime,
                ),

                const SizedBox(height: 8),
                _daySelector(),
              ],

              const SizedBox(height: 24),

                    Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: addHabit,
                      style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                      child: Text(widget.habit != null ? 'Save Changes' : 'Create Task'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* -------------------- WIDGET HELPERS -------------------- */

  Widget _input({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: required
            ? (v) => v!.isEmpty ? "Required" : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _frequencyDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: selectedFrequency,
        hint: const Text('Select Frequency'),
        decoration: InputDecoration(
          labelText: 'Frequency',
          prefixIcon: const Icon(Icons.repeat),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        items: frequencyOptions.map((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option.toUpperCase()),
          );
        }).toList(),
        onChanged: (String? value) {
          if (value != null) {
            setState(() => selectedFrequency = value);
          }
        },
        validator: (value) => value == null ? 'Please select a frequency' : null,
      ),
    );
  }

  Widget _iconDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        value: selectedIcon,
        decoration: InputDecoration(
          labelText: 'Select Icon',
          prefixIcon: const Icon(Icons.emoji_emotions),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        items: availableIcons.map((iconData) {
          return DropdownMenuItem<String>(
            value: iconData['name'],
            child: Row(
              children: [
                Icon(iconData['icon'], size: 20),
                const SizedBox(width: 8),
                Text(iconData['name']),
              ],
            ),
          );
        }).toList(),
        onChanged: (String? value) {
          if (value != null) {
            setState(() => selectedIcon = value);
          }
        },
      ),
    );
  }

  Widget _daySelector() {
    const days = [
      {'label': 'Mon', 'value': 'monday'},
      {'label': 'Tue', 'value': 'tuesday'},
      {'label': 'Wed', 'value': 'wednesday'},
      {'label': 'Thu', 'value': 'thursday'},
      {'label': 'Fri', 'value': 'friday'},
      {'label': 'Sat', 'value': 'saturday'},
      {'label': 'Sun', 'value': 'sunday'},
    ];

    return Wrap(
      spacing: 8,
      children: days.map((day) {
        final selected = selectedDays.contains(day['value']);
        return ChoiceChip(
          label: Text(day['label']!),
          selected: selected,
          onSelected: (_) => _toggleDay(day['value']!),
        );
      }).toList(),
    );
  }
}


