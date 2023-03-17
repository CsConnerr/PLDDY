import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PLDDY',
      // change color of the top banner
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // make the color glassmorphism
        scaffoldBackgroundColor: Color(0xFFECEFF1),
        // change the color of the appbar
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF299BE8),
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Color(0xFFECEFF1),
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Task> _taskList = [];

  final List<Color> _gradientColors = [
    Colors.blue[400]!,
    Colors.blue[300]!,
    Colors.blue[200]!,
    Colors.blue[100]!,
    Colors.blue[50]!,
    Colors.white,
  ];

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
                      ),
                    );
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
    int availableMinutes = 720; // Change this to the user's available time
    List<TimeOfDay> suggestedTimes = [];

    // Generate 3 random times within the range of 7am to 11pm,
    // at the beginning of each hour
    Random random = Random();
    int hour = random.nextInt(18) + 7; // 7am to 11pm
    for (int i = 0; i < 3; i++) {
      if (hour >= 7 && hour <= 23) {
        // Only add times within the range
        suggestedTimes.add(TimeOfDay(hour: hour, minute: 0));
      }
      hour++;
      if (hour > 23) {
        hour = 0;
      }
    }

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
                          ),
                        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PLDDY'),
      ),
      body: Container(
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
            Task task = _taskList[index];
            return Dismissible(
              key: Key('$task'),
              direction: DismissDirection.endToStart,
              onDismissed: (direction) {
                setState(() {
                  _taskList.removeAt(index);
                });
              },
              background: Container(
                color: Colors.red,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(width: 16.0),
                    Icon(Icons.delete, color: Colors.white),
                    SizedBox(width: 16.0),
                  ],
                ),
              ),
              child: Card(
                child: ListTile(
                  tileColor: _gradientColors[
                      _taskList.length % _gradientColors.length],
                  subtitle: Text(task.time.format(context)),
                  title: Text(
                    task.description,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          offset: Offset(1.0, 1.0),
                          blurRadius: 2.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
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
            child: Icon(Icons.book),
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

  Task({required this.time, required this.description});
}
