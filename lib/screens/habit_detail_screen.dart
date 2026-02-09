import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HabitDetailScreen extends StatefulWidget {
  final Map habit;
  final int userId;
  const HabitDetailScreen({Key? key, required this.habit, required this.userId}) : super(key: key);

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  bool isLoading = true;
  double progress = 0.0;
  int completed = 0;
  int target = 1;

  List<int> completedDays = [];
  int currentMonth = DateTime.now().month;
  int currentYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    await _fetchProgress();
    await _fetchCalendarData();
    setState(() => isLoading = false);
  }

  Future<void> _fetchProgress() async {
    try {
      final url = Uri.parse(
        'https://hackdefenders.com/Minahil/Habit/get_habit_progress.php?habit_id=${widget.habit['id']}&user_id=${widget.userId}'
      );
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        setState(() {
          completed = data['completed_count'] ?? 0;
          target = data['target_count'] ?? 1;
          progress = (data['progress'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      print('Error fetching progress: $e');
    }
  }

  Future<void> _fetchCalendarData() async {
    try {
      final habitId = widget.habit['id'].toString();
      final url = Uri.parse(
        'https://hackdefenders.com/Minahil/Habit/get_month_calendar.php?user_id=${widget.userId}&habit_id=$habitId&month=$currentMonth&year=$currentYear'
      );

      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data['status'] == 'success' && data['data'] != null) {
        List<int> days = [];
        final rawData = data['data'];

        if (rawData is Map) {
          rawData.forEach((key, value) {
            if (value == true) {
              days.add(int.parse(key.toString()));
            }
          });
        }

        setState(() {
          completedDays = days;
        });
      }
    } catch (e) {
      print('Error fetching calendar: $e');
    }
  }

  Future<void> _markComplete() async {
    try {
      final url = Uri.parse('https://hackdefenders.com/Minahil/Habit/mark_habit_complete.php');
      final habitId = int.parse(widget.habit['id'].toString());

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'habit_id': habitId,
          'user_id': widget.userId,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked complete!'), backgroundColor: Colors.green)
        );
        await _loadAllData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Error'), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error'), backgroundColor: Colors.red)
      );
    }
  }

  void _previousMonth() {
    setState(() {
      currentMonth--;
      if (currentMonth < 1) {
        currentMonth = 12;
        currentYear--;
      }
      completedDays = [];
    });
    _fetchCalendarData();
  }

  void _nextMonth() {
    setState(() {
      currentMonth++;
      if (currentMonth > 12) {
        currentMonth = 1;
        currentYear++;
      }
      completedDays = [];
    });
    _fetchCalendarData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habit['habit_name'] ?? 'Habit'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.habit['category'] != null)
                      Text(
                        widget.habit['category'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    SizedBox(height: 16),
                    _buildProgressSection(),
                    SizedBox(height: 24),
                    _buildCalendarSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProgressSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: _markComplete,
                  icon: Icon(Icons.check),
                  label: Text('Mark Done'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ],
            ),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$completed / $target completed'),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                Column(
                  children: [
                    Text(
                      _getMonthName(currentMonth),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      '$currentYear',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.green, 'Completed'),
                SizedBox(width: 16),
                _buildLegendItem(Colors.red, 'Missed'),
              ],
            ),
            SizedBox(height: 12),
            _buildCalendarGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final today = DateTime.now();
    final firstDayOfMonth = DateTime(currentYear, currentMonth, 1);
    final daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday;

    return Column(
      children: [
        Row(
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: ((startWeekday - 1) + daysInMonth + (7 - ((startWeekday - 1 + daysInMonth) % 7)) % 7),
          itemBuilder: (context, index) {
            if (index < startWeekday - 1) {
              return Container();
            }

            final day = index - (startWeekday - 2);

            if (day > daysInMonth) {
              return Container();
            }

            final isCompleted = completedDays.contains(day);
            final isToday = day == today.day &&
                           currentMonth == today.month &&
                           currentYear == today.year;

            final dayDate = DateTime(currentYear, currentMonth, day);
            final todayDate = DateTime(today.year, today.month, today.day);
            final isPast = dayDate.isBefore(todayDate);
            final isMissed = isPast && !isCompleted;

            Color bgColor;
            Color textColor;

            if (isCompleted) {
              bgColor = Colors.green;
              textColor = Colors.white;
            } else if (isMissed) {
              bgColor = Colors.red;
              textColor = Colors.white;
            } else if (isToday) {
              bgColor = Colors.blue.withOpacity(0.2);
              textColor = Colors.blue[700]!;
            } else {
              bgColor = Colors.grey[100]!;
              textColor = Colors.grey[700]!;
            }

            return Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
                border: isToday ? Border.all(color: Colors.blue, width: 2) : null,
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: textColor,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}
