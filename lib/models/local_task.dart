import 'package:hive/hive.dart';

part 'local_task.g.dart';

@HiveType(typeId: 0)
class LocalTask extends HiveObject {
  @HiveField(0)
  int? id; // Null until synced with backend

  @HiveField(1)
  int userId;

  @HiveField(2)
  String name;

  @HiveField(3)
  String category;

  @HiveField(4)
  String frequency;

  @HiveField(5)
  String icon;

  @HiveField(6)
  int target;

  @HiveField(7)
  String reminderTime;

  @HiveField(8)
  bool hasReminder;

  @HiveField(9)
  String daysSelected; // Comma separated days

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  bool isSynced; // Track if synced with backend

  @HiveField(12)
  String syncStatus; // 'pending', 'synced', 'failed'

  @HiveField(13)
  String operationType; // 'create', 'update', 'delete'

  LocalTask({
    this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.frequency,
    required this.icon,
    required this.target,
    required this.reminderTime,
    required this.hasReminder,
    required this.daysSelected,
    required this.createdAt,
    this.isSynced = false,
    this.syncStatus = 'pending',
    this.operationType = 'create',
  });

  // Convert to Map for API
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'category': category,
      'frequency': frequency,
      'icon': icon,
      'target': target,
      'reminder_time': reminderTime,
      'has_reminder': hasReminder ? 1 : 0,
      'days_selected': daysSelected,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create from Map (from backend)
  factory LocalTask.fromMap(Map<String, dynamic> map, int userId) {
    return LocalTask(
      id: int.tryParse(map['id'].toString()),
      userId: userId,
      name: map['name'] ?? '',
      category: map['category'] ?? 'General',
      frequency: map['frequency'] ?? 'daily',
      icon: map['icon'] ?? 'directions_walk',
      target: int.tryParse(map['target'].toString()) ?? 1,
      reminderTime: map['reminder_time'] ?? '09:00:00',
      hasReminder: (map['has_reminder'] ?? 0) == 1 || map['has_reminder'] == true,
      daysSelected: map['days_selected'] ?? '',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      isSynced: true,
      syncStatus: 'synced',
      operationType: 'create',
    );
  }
}
