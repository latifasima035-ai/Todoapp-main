import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/notification_service.dart';

class StepCounterScreen extends StatefulWidget {
  final int userId;
  const StepCounterScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<StepCounterScreen> createState() => _StepCounterScreenState();
}

class _StepCounterScreenState extends State<StepCounterScreen> {
  late Stream<StepCount> _stepCountStream;
  int _sensorSteps = 0;  // Raw sensor value (from boot)
  int _todaySteps = 0;   // Today's steps (from DB)
  int _dailyTargetSteps = 5000;
  int _lastLoggedSteps = 0;  // Last value sent to backend
  bool isLoading = false;  // Not loading anything
  bool _targetCompleted = false;
  late TextEditingController _targetController;

  @override
  void initState() {
    super.initState();
    _targetController = TextEditingController(text: _dailyTargetSteps.toString());
    _initializeStepCounter();
    _fetchTodaySteps();
  }

  Future<void> _initializeStepCounter() async {
    // Request Activity Recognition permission (Android 10+)
    final statusActivity = await Permission.activityRecognition.request();
    
    if (statusActivity.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activity Recognition permission denied. Step counter requires this permission.'))
      );
      return;
    }

    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(
      (StepCount event) async {
        int prevSensorSteps = _sensorSteps;
        _sensorSteps = event.steps; // Raw sensor value
        int delta = _sensorSteps - prevSensorSteps;

        print('📊 SENSOR UPDATE:');
        print('   Previous: $prevSensorSteps, New: ${event.steps}, Delta: $delta');
        print('   Today steps: $_todaySteps');
        print('   Last logged: $_lastLoggedSteps');

        // Check if we need to log steps (every 20 steps)
        if ((_sensorSteps - _lastLoggedSteps) >= 20) {
          print('   ⚠️ DELTA >= 20, calling _logStepsToBackend()');
          await _logStepsToBackend();
        }

        // Update UI
        if (mounted) {
          setState(() {});
        }

        // Check target after steps are updated
        _checkIfTargetReached();
      },
      onError: (error) {
        print('❌ Step counter error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Step counter error: $error'))
          );
        }
      },
    ).onError((error) {
      print('❌ Stream error: $error');
    });
  }

  Future<void> _fetchTodaySteps() async {
    try {
      final today = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD
      final url = Uri.parse(
        'https://hackdefenders.com/Minahil/Habit/get_step_target.php?user_id=${widget.userId}&date=$today'
      );
      
      final resp = await http.get(url);
      final data = jsonDecode(resp.body);
      
      if (data['status'] == 'success' && data['data'] != null) {
        setState(() {
          _dailyTargetSteps = int.parse(data['data']['target_steps'].toString());
          _targetController.text = _dailyTargetSteps.toString();
        });
      }
      
      // Also fetch today's logged steps
      _fetchLoggedStepsForToday();
    } catch (e) {
      print('Error fetching daily target: $e');
    }
  }

  Future<void> _fetchLoggedStepsForToday() async {
    try {
      final today = DateTime.now().toString().split(' ')[0];
      final url = Uri.parse(
        'https://hackdefenders.com/Minahil/Habit/get_logged_steps.php?user_id=${widget.userId}&date=$today'
      );
      
      final resp = await http.get(url);
      final data = jsonDecode(resp.body);
      
      if (data['status'] == 'success' && data['data'] != null) {
        setState(() {
          _todaySteps = int.parse(data['data']['steps'].toString());
          _lastLoggedSteps = _sensorSteps;  // Track sensor value, not daily total
          _targetCompleted = _todaySteps >= _dailyTargetSteps;
          print('📥 Fetched today: $_todaySteps steps, sensor: $_sensorSteps');
        });
      } else {
        // No steps logged yet for today - reset last logged to current sensor
        setState(() {
          _todaySteps = 0;
          _lastLoggedSteps = _sensorSteps;
          _targetCompleted = false;
          print('📥 No steps logged yet for today, reset tracking');
        });
      }
    } catch (e) {
      print('Error fetching logged steps: $e');
    }
  }

  void _checkIfTargetReached() {
    print('🔔 CHECK TARGET: _targetCompleted=$_targetCompleted, _todaySteps=$_todaySteps, target=$_dailyTargetSteps');

    // Check if target is reached
    bool targetReached = _todaySteps >= _dailyTargetSteps;

    // Only show notification if this is the FIRST time reaching target
    if (targetReached && !_targetCompleted) {
      print('🎉 TARGET REACHED! Showing notification...');

      // Update state first
      setState(() => _targetCompleted = true);

      // Show notification
      _showTargetCompletedNotification();

      // Show snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Congratulations! You completed $_dailyTargetSteps steps!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          )
        );
      }
    } else {
      if (_targetCompleted) {
        print('   Already completed');
      }
      if (_todaySteps < _dailyTargetSteps) {
        print('   Still need ${_dailyTargetSteps - _todaySteps} more steps');
      }
    }
  }

  Future<void> _showTargetCompletedNotification() async {
    try {
      print('📤 Sending notification...');
      await NotificationService().showNotification(
        title: 'Daily Goal Reached!',
        body: 'Congratulations! You completed $_dailyTargetSteps steps today!',
        id: 9999,
      );
      print('✅ Notification sent successfully');
    } catch (e) {
      print('❌ Notification error: $e');
    }
  }

  Future<void> _logStepsToBackend() async {
    try {
      final today = DateTime.now().toString().split(' ')[0];
      final url = Uri.parse('https://hackdefenders.com/Minahil/Habit/log_steps.php');
      
      // Calculate steps to add (increment from last log)
      int stepsToAdd = _todaySteps + (_sensorSteps - _lastLoggedSteps);
      
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'steps': stepsToAdd,
          'date': today
        })
      );
      
      final data = jsonDecode(resp.body);
      if (data['status'] == 'success') {
        setState(() {
          _todaySteps = stepsToAdd;
          _lastLoggedSteps = _sensorSteps;
        });
        print('✅ Logged $_todaySteps steps to backend');
      }
    } catch (e) {
      print('Error logging steps: $e');
    }
  }

  Future<void> _setDailyTarget(int targetSteps) async {
    try {
      final today = DateTime.now().toString().split(' ')[0];
      final url = Uri.parse('https://hackdefenders.com/Minahil/Habit/set_step_target.php');
      
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'target_steps': targetSteps,
          'date': today
        })
      );
      
      final data = jsonDecode(resp.body);
      if (data['status'] == 'success') {
        setState(() {
          _dailyTargetSteps = targetSteps;
          _targetCompleted = _todaySteps >= targetSteps;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Target updated to $targetSteps steps'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          )
        );
      }
    } catch (e) {
      print('Error setting target: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update target'))
      );
    }
  }

  void _showEditTargetDialog() {
    _targetController.text = _dailyTargetSteps.toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Daily Step Target', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _targetController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Target Steps',
            hintText: 'Enter step target',
            prefixIcon: const Icon(Icons.directions_walk, color: Colors.deepPurple),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final newTarget = int.tryParse(_targetController.text);
              if (newTarget != null && newTarget > 0) {
                _setDailyTarget(newTarget);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number'))
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step Counter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Daily Step Display Card - Enhanced
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF9F7AEA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.directions_walk, size: 56, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '$_todaySteps',
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Steps Today',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Progress Section - Enhanced
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Goal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_dailyTargetSteps steps',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                            if (_targetCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green, width: 2),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Completed!',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${((_todaySteps / _dailyTargetSteps) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            value: (_todaySteps / _dailyTargetSteps).clamp(0.0, 1.0),
                            minHeight: 12,
                            color: _targetCompleted ? Colors.green : const Color(0xFF7C3AED),
                            backgroundColor: Colors.grey[200],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$_todaySteps / $_dailyTargetSteps steps',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Target Setting Card - Enhanced
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adjust Daily Target',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Set your personal daily step goal',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF7C3AED).withOpacity(0.3),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: const Color(0xFF7C3AED).withOpacity(0.05),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.directions_walk,
                                      color: Colors.deepPurple,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '$_dailyTargetSteps',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'steps',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7C3AED), Color(0xFF9F7AEA)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _showEditTargetDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.edit, size: 20),
                                label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }
}
