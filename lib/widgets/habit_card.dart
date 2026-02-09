import 'package:flutter/material.dart';

class HabitCard extends StatelessWidget {
  final String habitName;
  final String category;
  final String frequency;
  final int quantity;
  final String? reminderTime;
  final String? categoryLabel;
  final String? iconName;
  final bool isCompletedToday;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onMark;

  const HabitCard({
    Key? key,
    required this.habitName,
    required this.category,
    required this.frequency,
    required this.quantity,
    this.reminderTime,
    this.categoryLabel,
    this.iconName,
    this.isCompletedToday = false,
    this.onEdit,
    this.onDelete,
    this.onTap,
    this.onMark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Different colors for different categories
    final categoryColors = {
      'health': Colors.green,
      'productivity': Colors.blue,
      'mindfulness': Colors.purple,
      'fitness': Colors.orange,
      'learning': Colors.teal,
    };

    Color categoryColor = categoryColors[category.toLowerCase()] ?? Colors.deepPurple;

    String displayCategory = categoryLabel?.trim().isNotEmpty == true ? categoryLabel! : category;

    // Map icon names to IconData
    final iconMap = {
      'directions_walk': Icons.directions_walk,
      'fitness_center': Icons.fitness_center,
      'local_drink': Icons.local_drink,
      'book': Icons.book,
      'self_improvement': Icons.self_improvement,
      'bedtime': Icons.bedtime,
      'restaurant': Icons.restaurant,
      'work': Icons.work,
      'school': Icons.school,
      'music_note': Icons.music_note,
      'brush': Icons.brush,
      'favorite': Icons.favorite,
    };

    IconData displayIcon = iconMap[iconName] ?? Icons.directions_walk;

    String? displayReminder;
    if (reminderTime != null && reminderTime!.trim().isNotEmpty) {
      // attempt to format HH:MM:SS or HH:MM into 12-hour format
      try {
        final parts = reminderTime!.split(':');
        int h = int.tryParse(parts[0]) ?? 0;
        int m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        final dt = DateTime(2000, 1, 1, h, m);
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final minute = dt.minute.toString().padLeft(2, '0');
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        displayReminder = '$hour:$minute $ampm';
      } catch (_) {
        displayReminder = reminderTime;
      }
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      margin: EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  displayIcon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habitName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          displayCategory,
                          style: TextStyle(
                            color: categoryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      if (displayReminder != null) ...[
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.notifications_none, size: 14, color: categoryColor),
                              SizedBox(width: 6),
                              Text(
                                displayReminder,
                                style: TextStyle(
                                  color: categoryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onMark,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isCompletedToday
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey[300],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompletedToday
                          ? Colors.green[700]!
                          : Colors.grey[400]!,
                        width: 2,
                      ),
                      boxShadow: isCompletedToday
                        ? [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.2),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ]
                        : [],
                    ),
                    child: Center(
                      child: AnimatedScale(
                        duration: Duration(milliseconds: 300),
                        scale: isCompletedToday ? 1.0 : 1.0,
                        child: Icon(
                          isCompletedToday ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isCompletedToday ? Colors.green[700] : Colors.grey[600],
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 4),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
                  onSelected: (v) {
                    if (v == 'edit' && onEdit != null) onEdit!();
                    if (v == 'delete' && onDelete != null) onDelete!();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}
