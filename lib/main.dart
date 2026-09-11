import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splash_screen_view/SplashScreenView.dart';
import 'package:table_calendar/table_calendar.dart';

import 'planner.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreenView(
        duration: 2500,
        imageSrc: 'assets/images/logo.png',
        imageSize: 500,
        text: 'PLDDY',
        textType: TextType.ColorizeAnimationText,
        textStyle: const TextStyle(fontSize: 50),
        colors: const [Colors.blue, Colors.lightBlue, Colors.cyan, Colors.blueGrey],
        backgroundColor: Colors.white,
        navigateRoute: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<Task> _taskList = <Task>[];
  SharedPreferences? _prefs;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  final List<Color> _gradientColors = <Color>[
    Colors.blue[400]!,
    Colors.blue[300]!,
    Colors.blue[200]!,
    Colors.blue[100]!,
    Colors.blue[50]!,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    _prefs = await SharedPreferences.getInstance();
    final List<String>? savedTasks = _prefs?.getStringList('tasks');
    if (savedTasks == null) return;

    final List<Task> loaded = <Task>[];
    for (final String taskJson in savedTasks) {
      try {
        loaded.add(Task.fromMap(json.decode(taskJson)));
      } catch (_) {
        // A malformed legacy task should not stop the rest of the schedule loading.
      }
    }

    if (!mounted) return;
    setState(() {
      _taskList
        ..clear()
        ..addAll(loaded);
      _sortTasks();
    });
    _deleteVeryOldTasks();
  }

  Future<void> _saveTasks() async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> encoded = _taskList
        .map((Task task) => json.encode(task.toMap()))
        .toList();
    await _prefs?.setStringList('tasks', encoded);
  }

  void _sortTasks() {
    _taskList.sort((Task a, Task b) => a.startDateTime.compareTo(b.startDateTime));
  }

  List<Task> get _visibleTasks => _taskList
      .where((Task task) => _isSameDay(task.date, _selectedDay))
      .toList();

  Future<void> _addTask() async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selectedTime == null || !mounted) return;

    final TextEditingController descriptionController = TextEditingController();
    int durationMinutes = 60;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Add Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: descriptionController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Class, appointment, work, etc.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: durationMinutes,
                    decoration: const InputDecoration(labelText: 'Duration'),
                    items: const <DropdownMenuItem<int>>[
                      DropdownMenuItem(value: 15, child: Text('15 minutes')),
                      DropdownMenuItem(value: 30, child: Text('30 minutes')),
                      DropdownMenuItem(value: 45, child: Text('45 minutes')),
                      DropdownMenuItem(value: 60, child: Text('1 hour')),
                      DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                      DropdownMenuItem(value: 120, child: Text('2 hours')),
                      DropdownMenuItem(value: 180, child: Text('3 hours')),
                    ],
                    onChanged: (int? value) {
                      if (value != null) {
                        setDialogState(() => durationMinutes = value);
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final String description = descriptionController.text.trim();
                    if (description.isEmpty) return;
                    setState(() {
                      _taskList.add(
                        Task(
                          time: selectedTime,
                          description: description,
                          date: DateTime(
                            _selectedDay.year,
                            _selectedDay.month,
                            _selectedDay.day,
                          ),
                          durationMinutes: durationMinutes,
                        ),
                      );
                      _sortTasks();
                    });
                    _saveTasks();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    descriptionController.dispose();
  }

  Future<void> _showPlannerOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ListTile(
                title: Text(
                  'Plan my free time',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'PLDDY will look at your commitments and find real open blocks.',
                ),
              ),
              _plannerChoice(
                context: context,
                icon: Icons.menu_book,
                title: 'Study',
                subtitle: '60 minute focus block',
                activity: ActivityType.study,
                durationMinutes: 60,
              ),
              _plannerChoice(
                context: context,
                icon: Icons.assignment,
                title: 'Homework',
                subtitle: '60 minute work block',
                activity: ActivityType.homework,
                durationMinutes: 60,
              ),
              _plannerChoice(
                context: context,
                icon: Icons.fitness_center,
                title: 'Workout',
                subtitle: '45 minute workout block',
                activity: ActivityType.workout,
                durationMinutes: 45,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _plannerChoice({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required ActivityType activity,
    required int durationMinutes,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () {
        Navigator.of(context).pop();
        _suggestActivity(activity, durationMinutes, title);
      },
    );
  }

  void _suggestActivity(
    ActivityType activity,
    int durationMinutes,
    String label,
  ) {
    final List<ScheduleBlock> busyBlocks = _taskList
        .where((Task task) => _isSameDay(task.date, _selectedDay))
        .map(
          (Task task) => ScheduleBlock(
            start: task.startDateTime,
            end: task.endDateTime,
          ),
        )
        .toList();

    final List<PlannerSuggestion> suggestions = SmartPlanner.suggest(
      day: _selectedDay,
      busyBlocks: busyBlocks,
      durationMinutes: durationMinutes,
      activity: activity,
    );

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Best times for $label'),
          content: suggestions.isEmpty
              ? const Text(
                  'There is not enough open time on this day. Try another day or remove a conflicting task.',
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: suggestions.map((PlannerSuggestion suggestion) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.auto_awesome),
                      title: Text(
                        '${DateFormat.jm().format(suggestion.start)} to ${DateFormat.jm().format(suggestion.end)}',
                      ),
                      subtitle: const Text('Open time with transition room'),
                      onTap: () {
                        setState(() {
                          _taskList.add(
                            Task(
                              time: TimeOfDay.fromDateTime(suggestion.start),
                              description: label,
                              date: DateTime(
                                _selectedDay.year,
                                _selectedDay.month,
                                _selectedDay.day,
                              ),
                              durationMinutes: durationMinutes,
                            ),
                          );
                          _sortTasks();
                        });
                        _saveTasks();
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _deleteTask(Task task) {
    setState(() => _taskList.remove(task));
    _saveTasks();
  }

  void _deleteVeryOldTasks() {
    final DateTime cutoff = DateTime.now().subtract(const Duration(days: 30));
    final int before = _taskList.length;
    _taskList.removeWhere((Task task) => task.endDateTime.isBefore(cutoff));
    if (_taskList.length != before) _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    final List<Task> visibleTasks = _visibleTasks;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/txt.png', fit: BoxFit.contain, height: 60),
        elevation: 0,
        leadingWidth: 72,
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(DateFormat('MMM').format(_selectedDay)),
            Text(
              '${_selectedDay.day}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          TableCalendar(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (DateTime day) => _isSameDay(day, _selectedDay),
            calendarFormat: _calendarFormat,
            onFormatChanged: (CalendarFormat format) {
              setState(() => _calendarFormat = format);
            },
            onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTasks,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _gradientColors,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const <double>[0, 0.2, 0.4, 0.6, 0.8, 1],
                  ),
                ),
                child: visibleTasks.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: <Widget>[
                          const SizedBox(height: 100),
                          Icon(Icons.event_available, size: 72, color: Colors.blueGrey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'Nothing planned for ${DateFormat.MMMd().format(_selectedDay)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Add fixed commitments first, then let PLDDY find your free time.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: visibleTasks.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Task task = visibleTasks[index];
                          return Dismissible(
                            key: ValueKey<String>(
                              '${task.date.toIso8601String()}-${task.time.hour}-${task.time.minute}-${task.description}',
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _deleteTask(task),
                            background: Container(
                              alignment: Alignment.centerRight,
                              color: Colors.red,
                              child: const Padding(
                                padding: EdgeInsets.all(16),
                                child: Icon(Icons.delete, color: Colors.white),
                              ),
                            ),
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              child: ListTile(
                                title: Text(task.description),
                                subtitle: Text(
                                  '${DateFormat.jm().format(task.startDateTime)} to ${DateFormat.jm().format(task.endDateTime)}',
                                ),
                                trailing: Text('${task.durationMinutes} min'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            heroTag: 'addTask',
            onPressed: _addTask,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'smartPlan',
            backgroundColor: Colors.red,
            onPressed: _showPlannerOptions,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Plan'),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class Task {
  final TimeOfDay time;
  final String description;
  final DateTime date;
  final int durationMinutes;

  Task({
    required this.time,
    required this.description,
    required this.date,
    this.durationMinutes = 60,
  });

  DateTime get startDateTime => DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

  DateTime get endDateTime => startDateTime.add(Duration(minutes: durationMinutes));

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      time: _decodeTime(map['time']),
      description: map['description']?.toString() ?? 'Task',
      date: _decodeDate(map['date']),
      durationMinutes: _decodeDuration(map['durationMinutes']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'time': <String, int>{'hour': time.hour, 'minute': time.minute},
      'description': description,
      'date': <String, int>{
        'year': date.year,
        'month': date.month,
        'day': date.day,
      },
      'durationMinutes': durationMinutes,
    };
  }

  static TimeOfDay _decodeTime(dynamic value) {
    if (value is Map) {
      return TimeOfDay(
        hour: int.tryParse(value['hour'].toString()) ?? 9,
        minute: int.tryParse(value['minute'].toString()) ?? 0,
      );
    }
    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(value);
      if (parsed != null) return TimeOfDay.fromDateTime(parsed);
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  static DateTime _decodeDate(dynamic value) {
    if (value is Map) {
      final DateTime now = DateTime.now();
      return DateTime(
        int.tryParse(value['year'].toString()) ?? now.year,
        int.tryParse(value['month'].toString()) ?? now.month,
        int.tryParse(value['day'].toString()) ?? now.day,
      );
    }
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static int _decodeDuration(dynamic value) {
    final int? parsed = int.tryParse(value?.toString() ?? '');
    return parsed == null || parsed <= 0 ? 60 : parsed;
  }
}
