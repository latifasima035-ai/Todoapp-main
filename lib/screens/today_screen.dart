import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/habit_card.dart';
import 'add_habit_screen.dart';
import 'habit_detail_screen.dart';
import '../services/notification_service.dart';
import '../services/local_task_service.dart';
import '../models/local_task.dart';

class TodayScreen extends StatefulWidget {
  final int userId;
  TodayScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  List habits = [];
  bool isLoading = true;
  String selectedCategory = 'All';
  Map<int, bool> completedToday = {}; // Track completion status per habit ID
  late LocalTaskService localTaskService;
  bool isOnline = true;
  String? errorMessage; // Track error state

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    localTaskService = LocalTaskService(userId: widget.userId);
    await localTaskService.init();
    localTaskService.startAutoSync();
    
    // Check initial connectivity
    await _checkConnectivity();
    
    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      _handleConnectivityChange(result);
    });
    
    // Fetch habits and initialize notifications
    await fetchHabits();
    await _initializeNotifications();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      isOnline = result != ConnectivityResult.none;
    });
  }

  void _handleConnectivityChange(ConnectivityResult result) async {
    final wasOnline = isOnline;
    setState(() {
      isOnline = result != ConnectivityResult.none;
    });

    if (isOnline && !wasOnline) {
      print('Back online! Syncing tasks...');
      await localTaskService.syncAllTasks();
      await fetchHabits();
    }
  }

  Future<void> fetchHabits() async {
    setState(() {
      isLoading = true;
      errorMessage = null; // Clear previous errors
    });

    try {
      if (isOnline) {
        // Try to fetch from backend
        await _fetchFromBackend();
      } else {
        // Offline: Load from local DB
        await _loadFromLocal();
      }
    } catch (e) {
      print("Error fetching habits, falling back to local: $e");
      setState(() {
        errorMessage = e.toString();
      });
      await _loadFromLocal();
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _fetchFromBackend() async {
    final url = Uri.parse("https://hackdefenders.com/Minahil/Habit/get_habits.php?user_id=${widget.userId}");
    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print("Parsed habits data: $responseData");

        if (responseData['status'] == 'success') {
          var habitsData = responseData['data'] ?? responseData['habits'];
          print("Habits data: $habitsData");

          setState(() {
            habits = habitsData ?? [];
          });

          // Merge with local tasks and sync new backend tasks
          final mergedHabits = await localTaskService.mergeWithBackendTasks(habits);
          print("Final habits count: ${habits.length}");

          // Fetch completion status for each habit
          await _fetchCompletionStatus();
        } else {
          print("API Error: ${responseData['message']}");
          throw Exception(responseData['message']);
        }
      } else {
        print("HTTP Error: ${response.statusCode}");
        throw Exception("HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching from backend: $e");
      rethrow;
    }
  }

  Future<void> _loadFromLocal() async {
    final localTasks = localTaskService.getAllTasks();
    setState(() {
      habits = localTasks.map((task) => {
        'id': task.id ?? 0,
        'user_id': task.userId,
        'habit_name': task.name,
        'category': task.category,
        'frequency': task.frequency,
        'icon': task.icon,
        'target': task.target,
        'reminder_time': task.reminderTime,
        'reminder_days': task.daysSelected,
        'has_reminder': task.hasReminder ? 1 : 0,
        'is_local': true,
        'sync_status': task.syncStatus,
      }).toList();
    });
    print("Loaded ${habits.length} tasks from local DB");
  }

  Future<void> _fetchCompletionStatus() async {
    final tempMap = <int, bool>{};
    for (var habit in habits) {
      final habitId = int.tryParse(habit['id'].toString()) ?? 0;
      if (habitId > 0) {
        try {
          final url = Uri.parse('https://hackdefenders.com/Minahil/Habit/get_habit_progress.php?habit_id=$habitId&user_id=${widget.userId}');
          final resp = await http.get(url);
          final data = jsonDecode(resp.body);
          if (data['status'] == 'success') {
            // If completed_count > 0 for daily habit, mark as completed today
            final completed = (data['completed_count'] ?? 0) > 0;
            tempMap[habitId] = completed;
          }
        } catch (e) {
          print('Error fetching completion for habit $habitId: $e');
          tempMap[habitId] = false;
        }
      }
    }
    setState(() {
      completedToday = tempMap;
    });
  }

  Future<void> _initializeNotifications() async {
    await _resyncNotifications();
  }

  Future<void> _resyncNotifications() async {
    // Cancel all existing notifications first
    await NotificationService().cancelAllNotifications();

    // Re-schedule notifications for all habits with reminders
    for (var habit in habits) {
      if (habit['reminder_time'] != null &&
          habit['reminder_days'] != null &&
          habit['id'] != null) {

        final reminderTime = habit['reminder_time'].toString();
        final reminderDays = habit['reminder_days'].toString().split(',');
        final habitId = int.tryParse(habit['id'].toString()) ?? 0;

        if (habitId > 0) {
          _scheduleNotificationsForHabit(
            habitId: habitId,
            habitName: habit['habit_name'] ?? 'Habit',
            reminderTime: reminderTime,
            reminderDays: reminderDays,
          );
        }
      }
    }

    print("Notifications re-synced for user ${widget.userId}");
  }

  void _scheduleNotificationsForHabit({
    required int habitId,
    required String habitName,
    required String reminderTime,
    required List<String> reminderDays,
  }) {
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

    // Parse time from HH:MM:SS format
    final timeParts = reminderTime.split(':');
    if (timeParts.length < 2) return;

    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts[1]) ?? 0;

    for (final day in reminderDays) {
      final dayTrimmed = day.trim();
      if (dayMap.containsKey(dayTrimmed)) {
        final dayIndex = dayOrder.indexOf(dayTrimmed);
        final notificationId = NotificationService().generateNotificationId(habitId, dayIndex);

        final scheduledDate = _nextInstanceOfDay(hour, minute, dayMap[dayTrimmed]!);

        NotificationService().scheduleHabitReminder(
          id: notificationId,
          title: "Habit Reminder",
          body: "Time to do $habitName",
          scheduledTime: scheduledDate,
        );
      }
    }
  }

  tz.TZDateTime _nextInstanceOfDay(int hour, int minute, int weekday) {
    final now = tz.TZDateTime.now(tz.local);

    // Create today at the specified time
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If today is the target weekday and time is in future, use it
    if (scheduled.weekday == weekday && scheduled.isAfter(now)) {
      return scheduled;
    }

    // Find next occurrence of the target weekday
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // Ensure we don't schedule in the past (if we're on target weekday but time passed, go 7 days ahead)
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    return scheduled;
  }

  Widget _buildErrorState() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 40),
              // Error Image
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/bnn.jpg',
                  width: 240,
                  height: 240,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 36),

              // Error Title
              Text(
                "Oops! Something went wrong",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey[800],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Error Description
              Text(
                "We couldn't load your tasks. Please try again.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              // Retry Button
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF9F7AEA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: fetchHabits,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 24, color: Colors.white),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // derive categories from loaded habits (non-empty category values)
    final Set<String> categorySet = {};
    for (var h in habits) {
      final c = h['category']?.toString().trim();
      if (c != null && c.isNotEmpty) categorySet.add(c);
    }

    final List<String> categories = categorySet.toList();
    // ensure 'All' is available when there are categories
    final bool hasCategories = categories.isNotEmpty;
    final filteredHabitsTop = _filteredHabits(categories, selectedCategory);
    return Scaffold(
      appBar: AppBar(
        title: Text(habits.isEmpty ? "To do task" : "Tasks"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchHabits,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.deepPurple),
                  SizedBox(height: 16),
                  Text(
                    "Loading your habits...",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : errorMessage != null
              ? _buildErrorState()
              : habits.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Illustration Container
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.deepPurple.withOpacity(0.1),
                                  Colors.deepPurple.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.deepPurple.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Background decorative circles
                                Positioned(
                                  top: -20,
                                  right: -20,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.deepPurple.withOpacity(0.08),
                                    ),
                                  ),
                                ),
                                // Main icon
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.task_alt_rounded,
                                        size: 64,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Title
                          Text(
                            "No Tasks Yet",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey[800],
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Description
                          Text(
                            "Start building healthy routines by adding your first task",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[600],
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Add Task Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF9F7AEA)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddHabitScreen(userId: widget.userId),
                                  ),
                                ).then((_) {
                                  setState(() {
                                    fetchHabits();
                                  });
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 24, color: Colors.white),
                              label: const Text(
                                'Add Task',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                : RefreshIndicator(
                  color: Colors.deepPurple,
                  onRefresh: fetchHabits,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                    // first item is header; remaining are filtered habits
                    itemCount: _filteredHabits(categories, selectedCategory).length + 1,
                    itemBuilder: (context, index) {
                        // index 0 is header (date chips + progress bar)
                        if (index == 0) {
                          // Simple date chips and progress area
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              // Day row (computed for current week window)
                              Builder(builder: (context) {
                                final now = DateTime.now();
                                final monthNames = [
                                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                                ];
                                // show current date & month above category chips
                                final currentDatePill = Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  margin: EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${now.day} ${monthNames[now.month - 1]}',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800]),
                                  ),
                                );

                                // create a window of 7 days where index 2 is today
                                final start = now.subtract(Duration(days: 2));
                                final weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    currentDatePill,
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: List.generate(7, (i) {
                                          final d = start.add(Duration(days: i));
                                          final dayName = weekdayNames[d.weekday - 1];
                                          final dayNumber = d.day.toString();
                                          final bool isToday = d.day == now.day && d.month == now.month && d.year == now.year;
                                          return Container(
                                            margin: EdgeInsets.only(right: 8),
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isToday ? Colors.blue : Colors.grey[100],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(dayName, style: TextStyle(fontSize: 12, color: isToday ? Colors.white : Colors.grey[700])),
                                                SizedBox(height: 4),
                                                Text(dayNumber, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isToday ? Colors.white : Colors.grey[900])),
                                              ],
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              SizedBox(height: 8),
                              // category chips (show only when there are categories)
                              if (hasCategories)
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      // 'All' chip
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ChoiceChip(
                                          label: Text('All'),
                                          selected: selectedCategory == 'All',
                                          onSelected: (_) => setState(() => selectedCategory = 'All'),
                                        ),
                                      ),
                                      ...categories.map((cat) {
                                        final isSelected = selectedCategory == cat;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: ChoiceChip(
                                            label: Text(cat),
                                            selected: isSelected,
                                            onSelected: (_) => setState(() => selectedCategory = cat),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),
                              SizedBox(height: 16),
                              // Progress header removed
                              SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: 1.0,
                                  minHeight: 8,
                                  color: Colors.green,
                                  backgroundColor: Colors.green.withOpacity(0.2),
                                ),
                              ),
                              SizedBox(height: 12),
                            ],
                          );
                        }

                        final filtered = _filteredHabits(categories, selectedCategory);
                        final habit = filtered[index - 1];
                        final habitId = int.tryParse(habit['id'].toString()) ?? 0;
                        int quantity = 0;
                        if (habit['quantity'] != null) {
                          quantity = int.tryParse(habit['quantity'].toString()) ?? 0;
                        }
                        String? reminder = null;
                        if (habit['reminder_time'] != null && habit['reminder_time'].toString().trim().isNotEmpty) {
                          reminder = habit['reminder_time'].toString();
                        }
                        final isCompleted = completedToday[habitId] ?? false;

                        return HabitCard(
                          habitName: habit['habit_name'] ?? "",
                          category: habit['category'] ?? "",
                          categoryLabel: habit['category'] ?? "",
                          frequency: habit['frequency_type'] ?? "",
                          quantity: quantity,
                          reminderTime: reminder,
                          iconName: habit['icon_name'],
                          isCompletedToday: isCompleted,
                          onEdit: () async {
                            // Open AddHabitScreen in edit mode
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AddHabitScreen(userId: widget.userId, habit: habit)),
                            );
                            await fetchHabits();
                          },
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => HabitDetailScreen(habit: habit, userId: widget.userId)),
                            );
                            await fetchHabits();
                          },
                          onDelete: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text('Delete habit'),
                                content: Text('Are you sure you want to delete this habit?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.pop(c, true), child: Text('Delete')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _deleteHabit(habitId);
                            }
                          },
                          onMark: () async {
                            await _markHabitComplete(habitId);
                          },
                        );
                      },
                    ),
                ),
    );
  }

  List _filteredHabits(List<String> categories, String selectedCategory) {
    if (selectedCategory == 'All' || categories.isEmpty) return habits;
    return habits.where((h) {
      final c = h['category']?.toString().trim();
      return c != null && c == selectedCategory;
    }).toList();
  }

  Future<void> _deleteHabit(int habitId) async {
    if (habitId <= 0) return;

    try {
      // Find the local task
      final taskIndex = localTaskService.taskBox.values.toList().indexWhere(
        (t) => t.id == habitId && t.userId == widget.userId,
      );

      if (taskIndex == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit not found')),
        );
        return;
      }

      if (isOnline) {
        // Try to delete online
        final url = Uri.parse('https://hackdefenders.com/Minahil/Habit/delete_habit.php');
        try {
          final resp = await http.post(
            url,
            body: jsonEncode({'habit_id': habitId, 'user_id': widget.userId}),
            headers: {'Content-Type': 'application/json'},
          ).timeout(Duration(seconds: 10));

          final data = jsonDecode(resp.body);
          if (data['status'] == 'success') {
            // Cancel notifications
            final notif = data['notification_ids'];
            if (notif != null && notif.toString().trim().isNotEmpty) {
              try {
                final map = jsonDecode(notif.toString());
                map.forEach((k, v) {
                  try {
                    final id = int.tryParse(v.toString()) ?? 0;
                    if (id > 0) NotificationService().cancelNotification(id);
                  } catch (_) {}
                });
              } catch (_) {}
            }

            // Delete from local DB
            await localTaskService.deleteTask(taskIndex);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? 'Habit deleted')),
            );
            await fetchHabits();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? 'Delete failed')),
            );
          }
        } catch (e) {
          print("Error deleting online, falling back to local: $e");
          // Mark for sync deletion
          await localTaskService.deleteTask(taskIndex);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Habit marked for deletion. Will sync when online.')),
          );
          await fetchHabits();
        }
      } else {
        // Offline: Mark for deletion
        await localTaskService.deleteTask(taskIndex);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit deleted locally. Will sync when online.')),
        );
        await fetchHabits();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _markHabitComplete(int habitId) async {
    if (habitId <= 0) return;
    
    final isCurrentlyCompleted = completedToday[habitId] ?? false;
    
    // Toggle the state optimistically
    setState(() {
      completedToday[habitId] = !isCurrentlyCompleted;
    });
    
    // Choose correct endpoint based on current state
    final endpoint = isCurrentlyCompleted 
      ? 'unmark_habit_complete.php'
      : 'mark_habit_complete.php';
    
    final url = Uri.parse('https://hackdefenders.com/Minahil/Habit/$endpoint');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'habit_id': habitId, 'user_id': widget.userId}),
      );
      final data = jsonDecode(resp.body);
      if (data['status'] == 'success') {
        final message = isCurrentlyCompleted 
          ? 'Habit marked as incomplete'
          : 'Great! Habit marked as complete';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        await fetchHabits();
      } else {
        // Revert optimistic update on failure
        setState(() {
          completedToday[habitId] = isCurrentlyCompleted;
        });
        // Show specific error message from backend
        final errorMsg = data['message'] ?? 'Failed to update habit';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        completedToday[habitId] = isCurrentlyCompleted;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }
}
