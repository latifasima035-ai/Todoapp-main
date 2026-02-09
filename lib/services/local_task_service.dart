import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/local_task.dart';

class LocalTaskService {
  static const String taskBoxName = 'tasks';
  static const String syncBoxName = 'sync_status';
  static LocalTaskService? _instance;
  
  late Box<LocalTask> taskBox;
  late Box syncBox;
  final int userId;

  factory LocalTaskService({required int userId}) {
    _instance ??= LocalTaskService._internal(userId);
    return _instance!;
  }

  LocalTaskService._internal(this.userId);

  // Initialize Hive
  Future<void> init() async {
    await Hive.initFlutter();
    
    // Register adapter if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LocalTaskAdapter());
    }

    // Check if box is already open
    if (!Hive.isBoxOpen(taskBoxName)) {
      taskBox = await Hive.openBox<LocalTask>(taskBoxName);
    } else {
      taskBox = Hive.box<LocalTask>(taskBoxName);
    }
    
    if (!Hive.isBoxOpen(syncBoxName)) {
      syncBox = await Hive.openBox(syncBoxName);
    } else {
      syncBox = Hive.box(syncBoxName);
    }
  }

  // Check connectivity
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Add new task (locally)
  Future<void> addTask(LocalTask task) async {
    // Create a new instance to avoid Hive key conflicts
    final newTask = LocalTask(
      id: task.id,
      userId: userId,
      name: task.name,
      category: task.category,
      frequency: task.frequency,
      icon: task.icon,
      target: task.target,
      reminderTime: task.reminderTime,
      hasReminder: task.hasReminder,
      daysSelected: task.daysSelected,
      createdAt: task.createdAt,
      isSynced: false,
      syncStatus: 'pending',
      operationType: 'create',
    );
    await taskBox.add(newTask);
  }

  // Update existing task (locally)
  Future<void> updateTask(int index, LocalTask task) async {
    // Create a new instance to avoid conflicts
    final updatedTask = LocalTask(
      id: task.id,
      userId: userId,
      name: task.name,
      category: task.category,
      frequency: task.frequency,
      icon: task.icon,
      target: task.target,
      reminderTime: task.reminderTime,
      hasReminder: task.hasReminder,
      daysSelected: task.daysSelected,
      createdAt: task.createdAt,
      isSynced: false,
      syncStatus: 'pending',
      operationType: 'update',
    );
    await taskBox.putAt(index, updatedTask);
  }

  // Delete task (mark as pending delete)
  Future<void> deleteTask(int index) async {
    final task = taskBox.getAt(index);
    if (task != null) {
      final deletedTask = LocalTask(
        id: task.id,
        userId: task.userId,
        name: task.name,
        category: task.category,
        frequency: task.frequency,
        icon: task.icon,
        target: task.target,
        reminderTime: task.reminderTime,
        hasReminder: task.hasReminder,
        daysSelected: task.daysSelected,
        createdAt: task.createdAt,
        isSynced: false,
        syncStatus: 'pending',
        operationType: 'delete',
      );
      await taskBox.putAt(index, deletedTask);
    }
  }

  // Get all local tasks for user (excluding deleted ones)
  List<LocalTask> getAllTasks() {
    return taskBox.values
        .where((task) => task.userId == userId && task.operationType != 'delete')
        .toList();
  }

  // Get pending sync tasks
  List<LocalTask> getPendingSyncTasks() {
    return taskBox.values
        .where((task) => task.userId == userId && task.syncStatus == 'pending')
        .toList();
  }

  // Sync all pending tasks to backend
  Future<bool> syncAllTasks() async {
    final isOnlineNow = await isOnline();
    if (!isOnlineNow) {
      print('No internet connection. Sync will be attempted later.');
      return false;
    }

    final pendingTasks = getPendingSyncTasks();
    bool allSynced = true;

    for (var i = 0; i < taskBox.length; i++) {
      final task = taskBox.getAt(i);
      if (task == null || task.userId != userId || task.syncStatus != 'pending') continue;

      try {
        if (task.operationType == 'create') {
          final result = await _syncCreateTask(task);
          if (result) {
            // Create new instance with synced status
            final syncedTask = LocalTask(
              id: task.id,
              userId: task.userId,
              name: task.name,
              category: task.category,
              frequency: task.frequency,
              icon: task.icon,
              target: task.target,
              reminderTime: task.reminderTime,
              hasReminder: task.hasReminder,
              daysSelected: task.daysSelected,
              createdAt: task.createdAt,
              isSynced: true,
              syncStatus: 'synced',
              operationType: task.operationType,
            );
            await taskBox.putAt(i, syncedTask);
          } else {
            // Create new instance with failed status
            final failedTask = LocalTask(
              id: task.id,
              userId: task.userId,
              name: task.name,
              category: task.category,
              frequency: task.frequency,
              icon: task.icon,
              target: task.target,
              reminderTime: task.reminderTime,
              hasReminder: task.hasReminder,
              daysSelected: task.daysSelected,
              createdAt: task.createdAt,
              isSynced: false,
              syncStatus: 'failed',
              operationType: task.operationType,
            );
            await taskBox.putAt(i, failedTask);
            allSynced = false;
          }
        } else if (task.operationType == 'update' && task.id != null) {
          final result = await _syncUpdateTask(task);
          if (result) {
            final syncedTask = LocalTask(
              id: task.id,
              userId: task.userId,
              name: task.name,
              category: task.category,
              frequency: task.frequency,
              icon: task.icon,
              target: task.target,
              reminderTime: task.reminderTime,
              hasReminder: task.hasReminder,
              daysSelected: task.daysSelected,
              createdAt: task.createdAt,
              isSynced: true,
              syncStatus: 'synced',
              operationType: task.operationType,
            );
            await taskBox.putAt(i, syncedTask);
          } else {
            final failedTask = LocalTask(
              id: task.id,
              userId: task.userId,
              name: task.name,
              category: task.category,
              frequency: task.frequency,
              icon: task.icon,
              target: task.target,
              reminderTime: task.reminderTime,
              hasReminder: task.hasReminder,
              daysSelected: task.daysSelected,
              createdAt: task.createdAt,
              isSynced: false,
              syncStatus: 'failed',
              operationType: task.operationType,
            );
            await taskBox.putAt(i, failedTask);
            allSynced = false;
          }
        } else if (task.operationType == 'delete' && task.id != null) {
          final result = await _syncDeleteTask(task);
          if (result) {
            // Remove from local DB after successful delete
            await taskBox.deleteAt(i);
          } else {
            final failedTask = LocalTask(
              id: task.id,
              userId: task.userId,
              name: task.name,
              category: task.category,
              frequency: task.frequency,
              icon: task.icon,
              target: task.target,
              reminderTime: task.reminderTime,
              hasReminder: task.hasReminder,
              daysSelected: task.daysSelected,
              createdAt: task.createdAt,
              isSynced: false,
              syncStatus: 'failed',
              operationType: task.operationType,
            );
            await taskBox.putAt(i, failedTask);
            allSynced = false;
          }
        }
      } catch (e) {
        print('Error syncing task: $e');
        try {
          final failedTask = LocalTask(
            id: task.id,
            userId: task.userId,
            name: task.name,
            category: task.category,
            frequency: task.frequency,
            icon: task.icon,
            target: task.target,
            reminderTime: task.reminderTime,
            hasReminder: task.hasReminder,
            daysSelected: task.daysSelected,
            createdAt: task.createdAt,
            isSynced: false,
            syncStatus: 'failed',
            operationType: task.operationType,
          );
          await taskBox.putAt(i, failedTask);
        } catch (_) {}
        allSynced = false;
      }
    }

    return allSynced;
  }

  // Sync create task to backend
  Future<bool> _syncCreateTask(LocalTask task) async {
    try {
      final response = await http.post(
        Uri.parse('https://hackdefenders.com/Minahil/Habit/add_habit.php'),
        body: {
          'user_id': task.userId.toString(),
          'name': task.name,
          'category': task.category,
          'frequency': task.frequency,
          'icon': task.icon,
          'target': task.target.toString(),
          'reminder_time': task.reminderTime,
          'has_reminder': task.hasReminder ? '1' : '0',
          'days_selected': task.daysSelected,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          task.id = int.tryParse(data['habit_id'].toString()) ?? task.id;
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error syncing create task: $e');
      return false;
    }
  }

  // Sync update task to backend
  Future<bool> _syncUpdateTask(LocalTask task) async {
    if (task.id == null) return false;

    try {
      final response = await http.post(
        Uri.parse('https://hackdefenders.com/Minahil/Habit/update_habit.php'),
        body: {
          'habit_id': task.id.toString(),
          'user_id': task.userId.toString(),
          'name': task.name,
          'category': task.category,
          'frequency': task.frequency,
          'icon': task.icon,
          'target': task.target.toString(),
          'reminder_time': task.reminderTime,
          'has_reminder': task.hasReminder ? '1' : '0',
          'days_selected': task.daysSelected,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      print('Error syncing update task: $e');
      return false;
    }
  }

  // Sync delete task to backend
  Future<bool> _syncDeleteTask(LocalTask task) async {
    if (task.id == null) return false;

    try {
      final response = await http.post(
        Uri.parse('https://hackdefenders.com/Minahil/Habit/delete_habit.php'),
        body: {
          'habit_id': task.id.toString(),
          'user_id': task.userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      print('Error syncing delete task: $e');
      return false;
    }
  }

  // Merge backend tasks with local tasks
  Future<List<LocalTask>> mergeWithBackendTasks(List<dynamic> backendTasks) async {
    final localTaskIds = <int?>{};
    for (var task in getAllTasks()) {
      if (task.id != null) {
        localTaskIds.add(task.id);
      }
    }

    // Add backend tasks that don't exist locally
    for (var backendTask in backendTasks) {
      final backendId = int.tryParse(backendTask['id'].toString());
      if (backendId != null && !localTaskIds.contains(backendId)) {
        final localTask = LocalTask.fromMap(backendTask, userId);
        await taskBox.add(localTask);
      }
    }

    return getAllTasks();
  }

  // Periodically attempt sync when online
  void startAutoSync() {
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        print('Connection restored. Attempting sync...');
        await Future.delayed(Duration(seconds: 2)); // Wait for connection to stabilize
        await syncAllTasks();
      }
    });
  }

  // Clear all tasks
  Future<void> clearAll() async {
    await taskBox.clear();
  }

  // Close boxes
  Future<void> close() async {
    await taskBox.close();
    await syncBox.close();
  }
}
