// ignore_for_file: unused_element

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  PlannerScreenState createState() => PlannerScreenState();
}

enum RepeatFrequency { none, daily, weekly }

class Task {
  final DateTime day;
  final TimeOfDay start;
  final TimeOfDay end;
  final String name;
  final String description;
  final int reminderMinutesBefore;
  final RepeatFrequency repeat;

  Task({
    required this.day,
    required this.start,
    required this.end,
    required this.name,
    required this.description,
    required this.reminderMinutesBefore,
    this.repeat = RepeatFrequency.none,
  });

  Map<String, dynamic> toJson() => {
        'day': day.toIso8601String(),
        'start': '${start.hour}:${start.minute}',
        'end': '${end.hour}:${end.minute}',
        'name': name,
        'description': description,
        'reminderMinutes': reminderMinutesBefore,
        'repeat': repeat.name,
      };

  static Task fromJson(Map<String, dynamic> json) {
    final day = DateTime.parse(json['day']);
    final startParts = json['start'].split(':');
    final endParts = json['end'].split(':');
    return Task(
      day: day,
      start: TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1])),
      end: TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1])),
      name: json['name'],
      description: json['description'],
      reminderMinutesBefore: json['reminderMinutes'] ?? 10,
      repeat: RepeatFrequency.values.firstWhere(
        (e) => e.name == json['repeat'],
        orElse: () => RepeatFrequency.none,
      ),
    );
  }
}

class PlannerScreenState extends State<PlannerScreen> {
  final List<Task> _tasks = [];
  DateTime _selectedDate = DateTime.now();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    loadTasks();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    tzdata.initializeTimeZones();
    await _notificationsPlugin.initialize(settings);
  }

  Future<void> _scheduleNotification(Task task) async {
    final startDateTime = DateTime(task.day.year, task.day.month, task.day.day, task.start.hour, task.start.minute);
    final preNotifyTime = startDateTime.subtract(Duration(minutes: task.reminderMinutesBefore));

    await _notificationsPlugin.zonedSchedule(
      startDateTime.hashCode,
      'Task Reminder',
      task.name,
      tz.TZDateTime.from(preNotifyTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'planner_channel',
          'Planner Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );

    await _notificationsPlugin.zonedSchedule(
      startDateTime.hashCode + 1,
      'Task Starts Now',
      task.name,
      tz.TZDateTime.from(startDateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'planner_channel',
          'Planner Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final taskList = _tasks.map((t) => t.toJson()).toList();
    prefs.setString('task_list', jsonEncode(taskList));
  }

  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('task_list');
    if (raw == null) return;
    final List decoded = jsonDecode(raw);
    final now = DateTime.now();

    _tasks.clear();
    for (var item in decoded) {
      final task = Task.fromJson(item);

      // If repeating and not for today, clone it
      if (task.repeat == RepeatFrequency.daily && !_isSameDay(task.day, now)) {
        final cloned = Task(
          day: DateTime(now.year, now.month, now.day),
          start: task.start,
          end: task.end,
          name: task.name,
          description: task.description,
          reminderMinutesBefore: task.reminderMinutesBefore,
          repeat: RepeatFrequency.daily,
        );
        _tasks.add(cloned);
      } else if (task.repeat == RepeatFrequency.weekly &&
          task.day.weekday == now.weekday &&
          !_isSameDay(task.day, now)) {
        final cloned = Task(
          day: DateTime(now.year, now.month, now.day),
          start: task.start,
          end: task.end,
          name: task.name,
          description: task.description,
          reminderMinutesBefore: task.reminderMinutesBefore,
          repeat: RepeatFrequency.weekly,
        );
        _tasks.add(cloned);
      } else {
        _tasks.add(task);
      }
    }
    setState(() {});
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showTaskStats() {
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final tasksToday = _tasks.where((t) =>
        t.day.year == selected.year &&
        t.day.month == selected.month &&
        t.day.day == selected.day).toList();

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final upcoming = tasksToday.where((t) => t.start.hour * 60 + t.start.minute >= nowMinutes).length;
    final past = tasksToday.length - upcoming;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Planner Stats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tasks Today: ${tasksToday.length}'),
            Text('Upcoming: $upcoming'),
            Text('Past: $past'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final tasksToday = _tasks.where((t) =>
        t.day.year == selected.year &&
        t.day.month == selected.month &&
        t.day.day == selected.day).toList();

    tasksToday.sort((a, b) =>
        (a.start.hour * 60 + a.start.minute) - (b.start.hour * 60 + b.start.minute));

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        setState(() {
          if (details.primaryVelocity! < 0) {
            _selectedDate = _selectedDate.add(const Duration(days: 1));
          } else if (details.primaryVelocity! > 0) {
            _selectedDate = _selectedDate.subtract(const Duration(days: 1));
          }
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(DateFormat('EEEE, d MMMM').format(_selectedDate)),
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: _showTaskStats,
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime.now();
                });
              },
              icon: const Icon(Icons.today),
            )
          ],
        ),
        body: ListView.builder(
          itemCount: 24,
          itemBuilder: (_, hour) {
            final hourTasks = tasksToday.where((t) {
              final taskStartMinutes = t.start.hour * 60 + t.start.minute;
              final thisHourStart = hour * 60;
              final thisHourEnd = (hour + 1) * 60;
              return taskStartMinutes >= thisHourStart && taskStartMinutes < thisHourEnd;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  color: Colors.grey.shade200,
                  width: double.infinity,
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...hourTasks.map((t) => ListTile(
                      onLongPress: () => editOrDeleteTask(t),
                      title: Text(t.name),
                      subtitle: Text(
                        '${t.description}\n${t.start.format(context)}–${t.end.format(context)}'
                        '${t.repeat != RepeatFrequency.none ? '\nRepeats: ${t.repeat.name}' : ''}',
                      ),
                      isThreeLine: true,
                    )),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addTaskDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _addTaskDialog() {
    // Not included here — implemented previously with dialog inputs
    // Add a DropdownButton<RepeatFrequency> for user to pick repeat
  }

  void editOrDeleteTask(Task task) {
    // Also allow editing repeat frequency
  }
}
