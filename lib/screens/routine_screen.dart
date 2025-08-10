import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Routine {
  final String name;
  final TimeOfDay time;
  String date;
  bool completed;

  Routine({
    required this.name,
    required this.time,
    required this.date,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'time': '${time.hour}:${time.minute}',
        'date': date,
        'completed': completed,
      };

  static Routine fromJson(Map<String, dynamic> json) {
    final timeParts = json['time'].split(':');
    return Routine(
      name: json['name'],
      time: TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1])),
      date: json['date'],
      completed: json['completed'],
    );
  }
}

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  final List<Routine> _routines = [];
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadRoutines();
    _loadStreak();
  }

  Future<void> _loadRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('routine_list');
    if (raw == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final List decoded = jsonDecode(raw);

    _routines.clear();
    for (var item in decoded) {
      final routine = Routine.fromJson(item);
      if (routine.date != today) {
        routine.completed = false;
        routine.date = today;
      }
      _routines.add(routine);
    }

    setState(() {});
  }

  Future<void> _saveRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final list = _routines
        .map((r) => Routine(
              name: r.name,
              time: r.time,
              date: today,
              completed: r.completed,
            ).toJson())
        .toList();
    prefs.setString('routine_list', jsonEncode(list));

    // Update streak
    final allComplete = _routines.isNotEmpty && _routines.every((r) => r.completed);
    if (allComplete) {
      _streak++;
      prefs.setInt('routine_streak', _streak);
    }
  }

  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    _streak = prefs.getInt('routine_streak') ?? 0;
  }

  void _addOrEditRoutine({Routine? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    TimeOfDay? selectedTime = existing?.time;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Routine' : 'Edit Routine'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLength: 30,
                decoration: const InputDecoration(labelText: 'Routine Name'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime ?? TimeOfDay.now(),
                  );
                  if (picked != null) setState(() => selectedTime = picked);
                },
                child: Text('Time: ${selectedTime != null ? selectedTime!.format(context) : 'Pick Time'}'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty && selectedTime != null) {
                  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                  setState(() {
                    if (existing != null) _routines.remove(existing);
                    _routines.add(Routine(name: name, time: selectedTime!, date: today));
                    _saveRoutines();
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteRoutine(Routine r) {
    setState(() {
      _routines.remove(r);
      _saveRoutines();
    });
  }

  void _showRoutineStats() {
    final total = _routines.length;
    final completed = _routines.where((r) => r.completed).length;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Routine Stats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total routines: $total'),
            Text('Completed today: $completed'),
            Text('Streak: $_streak day${_streak == 1 ? '' : 's'}'),
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
    _routines.sort((a, b) =>
        (a.time.hour * 60 + a.time.minute) - (b.time.hour * 60 + b.time.minute));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Routines'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: _showRoutineStats,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addOrEditRoutine(),
          )
        ],
      ),
      body: _routines.isEmpty
          ? const Center(child: Text('No routines added yet.'))
          : ListView.builder(
              itemCount: _routines.length,
              itemBuilder: (_, i) {
                final r = _routines[i];
                return ListTile(
                  leading: Checkbox(
                    value: r.completed,
                    onChanged: (val) {
                      setState(() {
                        r.completed = val ?? false;
                        _saveRoutines();
                      });
                    },
                  ),
                  title: Text(r.name),
                  subtitle: Text(r.time.format(context)),
                  onTap: () => _addOrEditRoutine(existing: r),
                  onLongPress: () => _deleteRoutine(r),
                );
              },
            ),
    );
  }
}
