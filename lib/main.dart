import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splash_screen_view/SplashScreenView.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreenView(
        duration: 2500,
        // Set duration for showing the splash screen (in milliseconds)
        imageSrc: "assets/images/logo.png",
        // Set image path for the splash screen
        imageSize: 500,
        // Set size for the splash screen image
        text: "PLDDY",
        // Set text to show below the image
        textType: TextType.ColorizeAnimationText,
        // Set text animation type
        textStyle: TextStyle(
          fontSize: 50.0,
        ),
        colors: [Colors.blue, Colors.lightBlue, Colors.cyan, Colors.blueGrey],
        // Set colors for the text animation
        backgroundColor: Colors.white,
        navigateRoute:
        MyHomePage(), // Set background color for the splash screen
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  List<Task> _taskList = [];

  final List<Color> _gradientColors = [
    Colors.blue[400]!,
    Colors.blue[300]!,
    Colors.blue[200]!,
    Colors.blue[100]!,
    Colors.blue[50]!,
    Colors.white,
  ];

  late final AnimationController _animationController;
  late final DateTime _selectedDay;
  late final DateTime _focusedDay;
  late final CalendarFormat _calendarFormat;

  Future<void> _refreshTasks() async {
    final DateTime now = DateTime.now();
    final DateTime currentFocusedDay = _focusedDay;
    if (now.year != currentFocusedDay.year ||
        now.month != currentFocusedDay.month ||
        now.day != currentFocusedDay.day) {
      setState(() {
        _focusedDay.add(Duration(days: 1));
        // if tasks are from the previous day, delete them
        _deleteOldTasks();
        _loadTasks();
      });
    } else {
      setState(() {
        _loadTasks();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _calendarFormat = CalendarFormat.week;

    _loadTasks();
    _deleteOldTasks();
  }

  SharedPreferences? _prefs;

  void _loadTasks() async {
    _prefs = await SharedPreferences.getInstance();
    final List<String>? taskList = _prefs?.getStringList('tasks');
    if (taskList != null) {
      _taskList =
          taskList.map((task) => Task.fromMap(json.decode(task))).toList();
    }
  }

  void _saveTasks() {
    final List<String> taskList =
    _taskList.map((task) => json.encode(task.toMap())).toList();
    _prefs?.setStringList('tasks', taskList);
  }

  void _addTask() async {
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selectedTime != null) {
      TextEditingController descriptionController = TextEditingController();
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Add Task'),
            content: TextFormField(
              controller: descriptionController,
              decoration: InputDecoration(
                hintText: 'Description',
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Save'),
                onPressed: () {
                  setState(() {
                    _taskList.add(
                      Task(
                        time: selectedTime,
                        description: descriptionController.text,
                        //date is set to the current date
                        date: DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                        ),
                      ),
                    );
                    _taskList.sort((a, b) {
                      DateTime aDateTime = DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                        a.time!.hour,
                        a.time!.minute,
                      );
                      DateTime bDateTime = DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                        b.time!.hour,
                        b.time!.minute,
                      );
                      return aDateTime.compareTo(bDateTime);
                    });
                    _saveTasks();
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  void _suggestStudyTime() async {
    List<TimeOfDay> suggestedTimes = [];
    Random random = Random();
    int hour = random.nextInt(16) + 7;
    int count = 0;
    while (suggestedTimes.length < 4 && count < 20) {
      if (hour >= 7 && hour <= 23) { // adds time to the list only if it's between 7am and 11pm
        suggestedTimes.add(TimeOfDay(hour: hour, minute: 0));
      }
      hour += 1;
      if (hour > 23) {
        hour = 7;
      }
      count++;
    }
    if (suggestedTimes.isEmpty) {

      for (int i = 1; i < 4; i++) {
        suggestedTimes.add(TimeOfDay(hour: 7 + i, minute: 0));
      }
    }

    // do not repeat times
    suggestedTimes.removeWhere((time) => _taskList.any((task) =>
    task.time!.hour == time.hour && task.time!.minute == time.minute));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Suggested Study Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: suggestedTimes
                .map(
                  (time) => ListTile(
                title: Text(time.format(context)),
                onTap: () {
                  setState(() {
                    _taskList.add(
                      Task(
                        time: time,
                        description: 'Study',
                        // date is set to the current day
                        date: DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                        ),
                      ),
                    );
                    _taskList.sort((a, b) {
                      DateTime aDateTime = DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                        a.time!.hour,
                        a.time!.minute,
                      );
                      DateTime bDateTime = DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                        b.time!.hour,
                        b.time!.minute,
                      );
                      return aDateTime.compareTo(bDateTime);
                    });
                    _saveTasks();
                  });
                  Navigator.of(context).pop();
                },
              ),
            )
                .toList(),
          ),
        );
      },
    );
  }


  void _deleteOldTasks() {
    setState(() {
      _taskList.removeWhere((task) {
        DateTime taskDateTime = DateTime(
          task.date.year,
          task.date.month,
          task.date.day,
          task.time!.hour,
          task.time!.minute,
        );
        DateTime now = DateTime.now();
        return taskDateTime.isBefore(now);
      });
      _saveTasks();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _saveTasks();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/txt.png',
          fit: BoxFit.contain,
          height: 60,
        ),
        elevation: 0,
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${DateFormat('MMMM').format(DateTime.now())}',
              style: TextStyle(fontSize: 16.0),
            ),
            Text(
              '${DateTime.now().day}',
              style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: DateTime.now(),
            calendarFormat: CalendarFormat.week,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshTasks,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _gradientColors,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.2, 0.4, 0.6, 0.8, 1],
                  ),
                ),
                child: ListView.builder(
                  itemCount: _taskList.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Task task = _taskList[index];
                    return Dismissible(
                      key: Key('${task.time}-${task.description}'),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        setState(() {
                          _taskList.removeAt(index);
                          _saveTasks();
                        });
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        color: Colors.red,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                      ),
                      child: Card(
                        child: ListTile(
                          title: Text(task.description),
                          subtitle: Text(DateFormat('hh:mm a').format(
                            DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day,
                              task.time!.hour,
                              task.time!.minute,
                            ),
                          )),
                          trailing: Icon(Icons.drag_handle),
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
        children: [
          FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: _addTask,
          ),
          SizedBox(height: 16.0),
          FloatingActionButton(
            backgroundColor: Colors.red,
            child: Icon(Icons.book),
            //
            onPressed: _suggestStudyTime,
          ),
        ],
      ),
    );
  }
}

class Task {
  final TimeOfDay time;
  final String description;
  final DateTime date;

  Task({required this.time, required this.description, required this.date});

  Task.fromMap(Map<String, dynamic> map)
      : time = TimeOfDay.fromDateTime(DateTime.parse(map['time'])),
        description = map['description'],
        date = DateTime.parse(map['date']);

  Map<String, dynamic> toMap() {
    return {
      'time': {'hour': time.hour, 'minute': time.minute},
      'description': description,
      'date': {'year': date.year, 'month': date.month, 'day': date.day},
    };
  }
}
