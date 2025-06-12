import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
PlannerScreenState createState() => PlannerScreenState();

}

class Task {
  final DateTime day;
  final TimeOfDay start;
  final TimeOfDay end;
  final String name;
  final String description;

  Task({
    required this.day,
    required this.start,
    required this.end,
    required this.name,
    required this.description,
  });
}

class PlannerScreenState extends State<PlannerScreen> 
 {
  final List<Task> _tasks = [];
  DateTime _selectedDate = DateTime.now();

  void _addTaskDialog() async {
    TimeOfDay? start;
    TimeOfDay? end;
    // Strip time component from today's date
DateTime selectedDay = DateTime(
  _selectedDate.year,
  _selectedDate.month,
  _selectedDate.day,
);




// Generate clean day list: today + next 6 days, all at 00:00
final List<DateTime> upcomingDays = List.generate(
  7,
  (i) {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day + i);
  },
);

    final nameController = TextEditingController();
    final descController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Task'),
          content: SingleChildScrollView(
            child: Column(
              children: [


DropdownButton<DateTime>(
  value: selectedDay,
  onChanged: (DateTime? newDay) {
    if (newDay != null) setState(() => selectedDay = newDay);
  },
  items: upcomingDays.map((day) {
    return DropdownMenuItem(
      value: day,
      child: Text(DateFormat('EEE, MMM d').format(day)),
    );
  }).toList(),
),

                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                        context: context, initialTime: TimeOfDay.now());
                    if (picked != null) setState(() => start = picked);
                  },
                  child: Text(start != null
                      ? 'Start: ${start!.format(context)}'
                      : 'Pick Start Time'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                        context: context, initialTime: TimeOfDay.now());
                    if (picked != null) setState(() => end = picked);
                  },
                  child: Text(end != null
                      ? 'End: ${end!.format(context)}'
                      : 'Pick End Time'),
                ),
                TextField(
                  controller: nameController,
                  maxLength: 30,
                  decoration: const InputDecoration(labelText: 'Task Name'),
                ),
                TextField(
                  controller: descController,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (start != null &&
                    end != null &&
                    nameController.text.trim().isNotEmpty) {
                  setState(() {
                    _tasks.add(Task(
                      day: selectedDay,
                      start: start!,
                      end: end!,
                      name: nameController.text.trim(),
                      description: descController.text.trim(),
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Save Task'),
            ),
          ],
        ),
      ),
    );
  }
  void editOrDeleteTask(Task task) async {
  final nameController = TextEditingController(text: task.name);
  final descController = TextEditingController(text: task.description);
  TimeOfDay start = task.start;
  TimeOfDay end = task.end;

  await showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Edit Task'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                      context: context, initialTime: start);
                  if (picked != null) setState(() => start = picked);
                },
                child: Text('Start: ${start.format(context)}'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                      context: context, initialTime: end);
                  if (picked != null) setState(() => end = picked);
                },
                child: Text('End: ${end.format(context)}'),
              ),
              TextField(
                controller: nameController,
                maxLength: 30,
                decoration: const InputDecoration(labelText: 'Task Name'),
              ),
              TextField(
                controller: descController,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                setState(() {
                  _tasks.remove(task);
                });
                Navigator.pop(context);
              },
              child: const Text("Delete")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _tasks.remove(task);
                _tasks.add(Task(
                  day: task.day,
                  start: start,
                  end: end,
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                ));
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    ),
  );
}

   @override
  Widget build(BuildContext context) {
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    final tasksToday = _tasks
        .where((t) =>
            t.day.year == selected.year &&
            t.day.month == selected.month &&
            t.day.day == selected.day)
        .toList();

    tasksToday.sort((a, b) =>
        (a.start.hour * 60 + a.start.minute) -
        (b.start.hour * 60 + b.start.minute));

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
          itemCount: tasksToday.length,
          itemBuilder: (_, i) {
            final t = tasksToday[i];
            return ListTile(
              onLongPress: () => editOrDeleteTask(t),
              leading: Text('${t.start.format(context)}–${t.end.format(context)}'),
              title: Text(t.name),
              subtitle: Text(t.description),
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
 }