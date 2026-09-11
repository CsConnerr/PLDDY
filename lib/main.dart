import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splash_screen_view/SplashScreenView.dart';
import 'package:table_calendar/table_calendar.dart';

import 'planner.dart';
import 'task.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B5CE2),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F7FB),
          foregroundColor: Color(0xFF1E1F2D),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE8E9F1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF5B5CE2), width: 1.5),
          ),
        ),
      ),
      home: SplashScreenView(
        duration: 1800,
        imageSrc: 'assets/images/logo.png',
        imageSize: 420,
        text: 'PLDDY',
        textType: TextType.ColorizeAnimationText,
        textStyle: const TextStyle(fontSize: 46, fontWeight: FontWeight.w700),
        colors: const <Color>[
          Color(0xFF5B5CE2),
          Color(0xFF6D8BFF),
          Color(0xFF6DCFD5),
          Color(0xFF5B5CE2),
        ],
        backgroundColor: const Color(0xFFF6F7FB),
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

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    _prefs = await SharedPreferences.getInstance();
    final List<String>? savedTasks = _prefs?.getStringList('tasks');
    if (savedTasks == null) {
      return;
    }

    final List<Task> loaded = <Task>[];
    for (final String taskJson in savedTasks) {
      try {
        loaded.add(Task.fromMap(json.decode(taskJson)));
      } catch (_) {
        // A malformed legacy task should not stop the rest of the schedule loading.
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _taskList
        ..clear()
        ..addAll(loaded);
      _sortTasks();
    });
  }

  Future<void> _saveTasks() async {
    _prefs ??= await SharedPreferences.getInstance();
    final List<String> encoded = _taskList
        .map((Task task) => json.encode(task.toMap()))
        .toList();
    await _prefs?.setStringList('tasks', encoded);
  }

  void _sortTasks() {
    _taskList.sort(
      (Task a, Task b) => a.startDateTime.compareTo(b.startDateTime),
    );
  }

  List<Task> get _visibleTasks => _taskList
      .where((Task task) => _isSameDay(task.date, _selectedDay))
      .toList();

  List<ScheduleBlock> get _busyBlocksForSelectedDay => _taskList
      .where(
        (Task task) =>
            !task.completed && _isSameDay(task.date, _selectedDay),
      )
      .map(
        (Task task) => ScheduleBlock(
          start: task.startDateTime,
          end: task.endDateTime,
        ),
      )
      .toList();

  Future<void> _showTaskEditor({Task? existingTask}) async {
    final TextEditingController descriptionController = TextEditingController(
      text: existingTask?.description ?? '',
    );
    TimeOfDay selectedTime = existingTask?.time ?? TimeOfDay.now();
    int durationMinutes = existingTask?.durationMinutes ?? 60;
    TaskCategory selectedCategory =
        existingTask?.category ?? TaskCategory.personal;

    final Task? editedTask = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFD),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8DAE6),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      existingTask == null ? 'Add to your day' : 'Edit task',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMMM d').format(_selectedDay),
                      style: const TextStyle(color: Color(0xFF6F7180)),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: descriptionController,
                      autofocus: existingTask == null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'What is happening?',
                        hintText: 'Class, appointment, work, errands',
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TaskCategory.values.map((TaskCategory category) {
                        final bool selected = category == selectedCategory;
                        final Color color = _categoryColor(category);
                        return ChoiceChip(
                          selected: selected,
                          avatar: Icon(
                            _categoryIcon(category),
                            size: 18,
                            color: selected ? Colors.white : color,
                          ),
                          label: Text(_categoryLabel(category)),
                          selectedColor: color,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : const Color(0xFF353746),
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) {
                            setSheetState(() => selectedCategory = category);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setSheetState(() => selectedTime = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Start time'),
                              child: Row(
                                children: <Widget>[
                                  const Icon(Icons.schedule, size: 20),
                                  const SizedBox(width: 8),
                                  Text(selectedTime.format(context)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: durationMinutes,
                            decoration: const InputDecoration(labelText: 'Duration'),
                            items: const <DropdownMenuItem<int>>[
                              DropdownMenuItem(value: 15, child: Text('15 min')),
                              DropdownMenuItem(value: 30, child: Text('30 min')),
                              DropdownMenuItem(value: 45, child: Text('45 min')),
                              DropdownMenuItem(value: 60, child: Text('1 hour')),
                              DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                              DropdownMenuItem(value: 120, child: Text('2 hours')),
                              DropdownMenuItem(value: 180, child: Text('3 hours')),
                            ],
                            onChanged: (int? value) {
                              if (value != null) {
                                setSheetState(() => durationMinutes = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final String description =
                              descriptionController.text.trim();
                          if (description.isEmpty) {
                            return;
                          }
                          Navigator.of(sheetContext).pop(
                            Task(
                              id: existingTask?.id,
                              time: selectedTime,
                              description: description,
                              date: DateTime(
                                _selectedDay.year,
                                _selectedDay.month,
                                _selectedDay.day,
                              ),
                              durationMinutes: durationMinutes,
                              category: selectedCategory,
                              completed: existingTask?.completed ?? false,
                              suggestedByPlddy:
                                  existingTask?.suggestedByPlddy ?? false,
                            ),
                          );
                        },
                        icon: Icon(existingTask == null ? Icons.add : Icons.check),
                        label: Text(existingTask == null ? 'Add task' : 'Save changes'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    descriptionController.dispose();
    if (editedTask == null || !mounted) {
      return;
    }

    setState(() {
      if (existingTask == null) {
        _taskList.add(editedTask);
      } else {
        final int index = _taskList.indexWhere(
          (Task task) => task.id == existingTask.id,
        );
        if (index != -1) {
          _taskList[index] = editedTask;
        }
      }
      _sortTasks();
    });
    _saveTasks();
  }

  Future<void> _showPlannerMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFD),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DAE6),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Let PLDDY help',
                  style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'PLDDY looks at what is already on your calendar and finds realistic open time.',
                  style: TextStyle(color: Color(0xFF6F7180), height: 1.4),
                ),
                const SizedBox(height: 18),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openDayPlanBuilder();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF5B5CE2), Color(0xFF6D8BFF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: <Widget>[
                        CircleAvatar(
                          backgroundColor: Color(0x33FFFFFF),
                          child: Icon(Icons.auto_awesome, color: Colors.white),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Build my day',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Fit study, homework, and a workout into one schedule',
                                style: TextStyle(color: Color(0xFFE9E9FF)),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.white),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Or find time for one thing',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _plannerMenuTile(
                  sheetContext: sheetContext,
                  icon: Icons.menu_book_rounded,
                  title: 'Study',
                  subtitle: 'Find a focused 60 minute block',
                  activity: ActivityType.study,
                  durationMinutes: 60,
                ),
                _plannerMenuTile(
                  sheetContext: sheetContext,
                  icon: Icons.assignment_rounded,
                  title: 'Homework',
                  subtitle: 'Find a 60 minute work block',
                  activity: ActivityType.homework,
                  durationMinutes: 60,
                ),
                _plannerMenuTile(
                  sheetContext: sheetContext,
                  icon: Icons.fitness_center_rounded,
                  title: 'Workout',
                  subtitle: 'Find a 45 minute workout block',
                  activity: ActivityType.workout,
                  durationMinutes: 45,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _plannerMenuTile({
    required BuildContext sheetContext,
    required IconData icon,
    required String title,
    required String subtitle,
    required ActivityType activity,
    required int durationMinutes,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFECECFB),
        child: Icon(icon, color: const Color(0xFF5B5CE2)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(sheetContext).pop();
        _suggestActivity(activity, durationMinutes, title);
      },
    );
  }

  Future<void> _suggestActivity(
    ActivityType activity,
    int durationMinutes,
    String label,
  ) async {
    final List<PlannerSuggestion> suggestions = SmartPlanner.suggest(
      day: _selectedDay,
      busyBlocks: _busyBlocksForSelectedDay,
      durationMinutes: durationMinutes,
      activity: activity,
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFD),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DAE6),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Best times for $label',
                  style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  DateFormat('EEEE, MMMM d').format(_selectedDay),
                  style: const TextStyle(color: Color(0xFF6F7180)),
                ),
                const SizedBox(height: 16),
                if (suggestions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Column(
                      children: <Widget>[
                        Icon(Icons.event_busy_rounded, size: 40, color: Color(0xFF9295A7)),
                        SizedBox(height: 10),
                        Text(
                          'There is not enough open time on this day.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Try another day or adjust one of your commitments.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6F7180)),
                        ),
                      ],
                    ),
                  )
                else
                  ...suggestions.map((PlannerSuggestion suggestion) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          _addPlannerTask(
                            suggestion: suggestion,
                            activity: activity,
                            durationMinutes: durationMinutes,
                            label: label,
                          );
                          Navigator.of(sheetContext).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE7E8F0)),
                          ),
                          child: Row(
                            children: <Widget>[
                              const CircleAvatar(
                                backgroundColor: Color(0xFFECECFB),
                                child: Icon(Icons.auto_awesome, color: Color(0xFF5B5CE2)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      '${DateFormat.jm().format(suggestion.start)} to ${DateFormat.jm().format(suggestion.end)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _suggestionReason(suggestion, activity),
                                      style: const TextStyle(color: Color(0xFF6F7180)),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.add_circle, color: Color(0xFF5B5CE2)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addPlannerTask({
    required PlannerSuggestion suggestion,
    required ActivityType activity,
    required int durationMinutes,
    required String label,
  }) {
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
          category: _categoryForActivity(activity),
          suggestedByPlddy: true,
        ),
      );
      _sortTasks();
    });
    _saveTasks();
  }

  Future<void> _openDayPlanBuilder() async {
    bool includeStudy = true;
    bool includeHomework = true;
    bool includeWorkout = true;
    int studyMinutes = 60;
    int homeworkMinutes = 60;
    int workoutMinutes = 45;

    final List<PlannerRequest>? requests =
        await showModalBottomSheet<List<PlannerRequest>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFD),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8DAE6),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'What do you want to fit in?',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'PLDDY will place these around your existing schedule for ${DateFormat.MMMMd().format(_selectedDay)}.',
                        style: const TextStyle(color: Color(0xFF6F7180), height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      _planGoalRow(
                        title: 'Study',
                        icon: Icons.menu_book_rounded,
                        enabled: includeStudy,
                        durationMinutes: studyMinutes,
                        onEnabledChanged: (bool value) {
                          setSheetState(() => includeStudy = value);
                        },
                        onDurationChanged: (int value) {
                          setSheetState(() => studyMinutes = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      _planGoalRow(
                        title: 'Homework',
                        icon: Icons.assignment_rounded,
                        enabled: includeHomework,
                        durationMinutes: homeworkMinutes,
                        onEnabledChanged: (bool value) {
                          setSheetState(() => includeHomework = value);
                        },
                        onDurationChanged: (int value) {
                          setSheetState(() => homeworkMinutes = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      _planGoalRow(
                        title: 'Workout',
                        icon: Icons.fitness_center_rounded,
                        enabled: includeWorkout,
                        durationMinutes: workoutMinutes,
                        onEnabledChanged: (bool value) {
                          setSheetState(() => includeWorkout = value);
                        },
                        onDurationChanged: (int value) {
                          setSheetState(() => workoutMinutes = value);
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: includeStudy || includeHomework || includeWorkout
                              ? () {
                                  final List<PlannerRequest> result = <PlannerRequest>[];
                                  if (includeStudy) {
                                    result.add(
                                      PlannerRequest(
                                        activity: ActivityType.study,
                                        durationMinutes: studyMinutes,
                                      ),
                                    );
                                  }
                                  if (includeHomework) {
                                    result.add(
                                      PlannerRequest(
                                        activity: ActivityType.homework,
                                        durationMinutes: homeworkMinutes,
                                      ),
                                    );
                                  }
                                  if (includeWorkout) {
                                    result.add(
                                      PlannerRequest(
                                        activity: ActivityType.workout,
                                        durationMinutes: workoutMinutes,
                                      ),
                                    );
                                  }
                                  Navigator.of(sheetContext).pop(result);
                                }
                              : null,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Build my schedule'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (requests == null || requests.isEmpty || !mounted) {
      return;
    }
    _previewDayPlan(requests);
  }

  Widget _planGoalRow({
    required String title,
    required IconData icon,
    required bool enabled,
    required int durationMinutes,
    required ValueChanged<bool> onEnabledChanged,
    required ValueChanged<int> onDurationChanged,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7E8F0)),
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: const Color(0xFFECECFB),
              child: Icon(icon, color: const Color(0xFF5B5CE2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (enabled)
              DropdownButton<int>(
                value: durationMinutes,
                underline: const SizedBox.shrink(),
                items: const <DropdownMenuItem<int>>[
                  DropdownMenuItem(value: 30, child: Text('30 min')),
                  DropdownMenuItem(value: 45, child: Text('45 min')),
                  DropdownMenuItem(value: 60, child: Text('1 hour')),
                  DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                  DropdownMenuItem(value: 120, child: Text('2 hours')),
                ],
                onChanged: (int? value) {
                  if (value != null) {
                    onDurationChanged(value);
                  }
                },
              ),
            Switch(value: enabled, onChanged: onEnabledChanged),
          ],
        ),
      ),
    );
  }

  Future<void> _previewDayPlan(List<PlannerRequest> requests) async {
    final List<PlannedActivity> planned = SmartPlanner.planDay(
      day: _selectedDay,
      busyBlocks: _busyBlocksForSelectedDay,
      requests: requests,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFD),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DAE6),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  planned.isEmpty ? 'No room yet' : 'Here is your plan',
                  style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  planned.isEmpty
                      ? 'PLDDY could not fit these into the open time on this day.'
                      : 'PLDDY fit ${planned.length} of ${requests.length} goals into your day.',
                  style: const TextStyle(color: Color(0xFF6F7180)),
                ),
                const SizedBox(height: 16),
                if (planned.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Try shortening one of the activities, moving a commitment, or choosing another day.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...planned.map((PlannedActivity item) {
                    final Color color = _categoryColor(
                      _categoryForActivity(item.activity),
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE7E8F0)),
                      ),
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundColor: color.withOpacity(0.12),
                            child: Icon(
                              _activityIcon(item.activity),
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _activityLabel(item.activity),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${DateFormat.jm().format(item.suggestion.start)} to ${DateFormat.jm().format(item.suggestion.end)}',
                                  style: const TextStyle(color: Color(0xFF6F7180)),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatDuration(item.durationMinutes),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  }),
                if (planned.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          for (final PlannedActivity item in planned) {
                            _taskList.add(
                              Task(
                                time: TimeOfDay.fromDateTime(item.suggestion.start),
                                description: _activityLabel(item.activity),
                                date: DateTime(
                                  _selectedDay.year,
                                  _selectedDay.month,
                                  _selectedDay.day,
                                ),
                                durationMinutes: item.durationMinutes,
                                category: _categoryForActivity(item.activity),
                                suggestedByPlddy: true,
                              ),
                            );
                          }
                          _sortTasks();
                        });
                        _saveTasks();
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added ${planned.length} planned ${planned.length == 1 ? 'task' : 'tasks'} to your day.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Add this plan'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleTask(Task task) {
    final int index = _taskList.indexWhere((Task item) => item.id == task.id);
    if (index == -1) {
      return;
    }
    setState(() {
      _taskList[index] = task.copyWith(completed: !task.completed);
    });
    _saveTasks();
  }

  void _deleteTask(Task task) {
    setState(() => _taskList.removeWhere((Task item) => item.id == task.id));
    _saveTasks();
  }

  void _goToToday() {
    final DateTime today = DateTime.now();
    setState(() {
      _selectedDay = today;
      _focusedDay = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Task> visibleTasks = _visibleTasks;
    final int completedCount =
        visibleTasks.where((Task task) => task.completed).length;
    final int plannedMinutes = visibleTasks.fold<int>(
      0,
      (int total, Task task) => total + task.durationMinutes,
    );
    final int openMinutes = SmartPlanner.availableMinutes(
      day: _selectedDay,
      busyBlocks: _busyBlocksForSelectedDay,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: const Text(
          'PLDDY',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.4),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _goToToday,
            child: const Text('Today'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildCalendar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                children: <Widget>[
                  _buildDayOverview(
                    taskCount: visibleTasks.length,
                    completedCount: completedCount,
                    plannedMinutes: plannedMinutes,
                    openMinutes: openMinutes,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _showPlannerMenu,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Plan my day'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showTaskEditor(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add task'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Schedule',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (visibleTasks.isNotEmpty)
                        Text(
                          '${visibleTasks.length} ${visibleTasks.length == 1 ? 'item' : 'items'}',
                          style: const TextStyle(color: Color(0xFF77798A)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (visibleTasks.isEmpty)
                    _buildEmptyState()
                  else
                    ...visibleTasks.map(_buildTaskCard),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskEditor(),
        tooltip: 'Add task',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCalendar() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE7E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: TableCalendar<Task>(
          firstDay: DateTime.utc(2023, 1, 1),
          lastDay: DateTime.utc(2035, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (DateTime day) => _isSameDay(day, _selectedDay),
          calendarFormat: _calendarFormat,
          availableCalendarFormats: const <CalendarFormat, String>{
            CalendarFormat.month: 'Month',
            CalendarFormat.week: 'Week',
          },
          rowHeight: 44,
          daysOfWeekHeight: 24,
          eventLoader: (DateTime day) => _taskList
              .where((Task task) => _isSameDay(task.date, day))
              .toList(),
          headerStyle: const HeaderStyle(
            titleCentered: true,
            formatButtonShowsNext: false,
            leftChevronMargin: EdgeInsets.zero,
            rightChevronMargin: EdgeInsets.zero,
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            todayDecoration: BoxDecoration(
              color: const Color(0xFF5B5CE2).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            todayTextStyle: const TextStyle(
              color: Color(0xFF5B5CE2),
              fontWeight: FontWeight.w800,
            ),
            selectedDecoration: const BoxDecoration(
              color: Color(0xFF5B5CE2),
              shape: BoxShape.circle,
            ),
            markerDecoration: const BoxDecoration(
              color: Color(0xFF6DCFD5),
              shape: BoxShape.circle,
            ),
            markersMaxCount: 1,
          ),
          onFormatChanged: (CalendarFormat format) {
            setState(() => _calendarFormat = format);
          },
          onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (DateTime focusedDay) {
            _focusedDay = focusedDay;
          },
        ),
      ),
    );
  }

  Widget _buildDayOverview({
    required int taskCount,
    required int completedCount,
    required int plannedMinutes,
    required int openMinutes,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF20213A), Color(0xFF42447A)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      DateFormat('EEEE').format(_selectedDay),
                      style: const TextStyle(
                        color: Color(0xFFBEC0DD),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('MMMM d').format(_selectedDay),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (completedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6DCFD5).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$completedCount done',
                    style: const TextStyle(
                      color: Color(0xFF9DE9ED),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: _summaryStat(
                  value: '$taskCount',
                  label: taskCount == 1 ? 'Task' : 'Tasks',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryStat(
                  value: _formatDuration(plannedMinutes),
                  label: 'Planned',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryStat(
                  value: _formatDuration(openMinutes),
                  label: 'Open',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStat({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFBEC0DD), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E8F0)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: Color(0xFFECECFB),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: Color(0xFF5B5CE2),
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Your day is wide open',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add fixed commitments first, or let PLDDY create a starting plan for you.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6F7180), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final Color color = _categoryColor(task.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey<String>(task.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _deleteTask(task),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFE9505A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: task.completed ? 0.55 : 1,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showTaskEditor(existingTask: task),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE7E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 62,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            DateFormat('h:mm').format(task.startDateTime),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            DateFormat('a').format(task.startDateTime),
                            style: const TextStyle(
                              color: Color(0xFF8A8C9C),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 54,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            task.description,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              decoration: task.completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 7,
                            runSpacing: 5,
                            children: <Widget>[
                              _smallLabel(
                                icon: _categoryIcon(task.category),
                                text: _categoryLabel(task.category),
                                color: color,
                              ),
                              Text(
                                _formatDuration(task.durationMinutes),
                                style: const TextStyle(
                                  color: Color(0xFF77798A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (task.suggestedByPlddy)
                                const Text(
                                  'PLDDY planned',
                                  style: TextStyle(
                                    color: Color(0xFF5B5CE2),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: task.completed ? 'Mark incomplete' : 'Mark complete',
                      onPressed: () => _toggleTask(task),
                      icon: Icon(
                        task.completed
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: task.completed ? const Color(0xFF43A47C) : const Color(0xFFA5A7B4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallLabel({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _suggestionReason(
    PlannerSuggestion suggestion,
    ActivityType activity,
  ) {
    final int hour = suggestion.start.hour;
    if (activity == ActivityType.workout) {
      if (hour < 11) {
        return 'A clear morning window with transition room';
      }
      if (hour < 17) {
        return 'A roomy break in the middle of your day';
      }
      return 'A good evening opening before the day gets too late';
    }

    if (hour < 12) {
      return 'A strong morning focus window with breathing room';
    }
    if (hour < 17) {
      return 'A useful afternoon opening between commitments';
    }
    return 'An evening focus block that still leaves time afterward';
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) {
      return '0m';
    }
    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes % 60;
    if (hours == 0) {
      return '${remainingMinutes}m';
    }
    if (remainingMinutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMinutes}m';
  }

  String _activityLabel(ActivityType activity) {
    switch (activity) {
      case ActivityType.study:
        return 'Study';
      case ActivityType.homework:
        return 'Homework';
      case ActivityType.workout:
        return 'Workout';
    }
  }

  IconData _activityIcon(ActivityType activity) {
    switch (activity) {
      case ActivityType.study:
        return Icons.menu_book_rounded;
      case ActivityType.homework:
        return Icons.assignment_rounded;
      case ActivityType.workout:
        return Icons.fitness_center_rounded;
    }
  }

  TaskCategory _categoryForActivity(ActivityType activity) {
    switch (activity) {
      case ActivityType.study:
        return TaskCategory.study;
      case ActivityType.homework:
        return TaskCategory.homework;
      case ActivityType.workout:
        return TaskCategory.workout;
    }
  }

  String _categoryLabel(TaskCategory category) {
    switch (category) {
      case TaskCategory.classMeeting:
        return 'Class';
      case TaskCategory.appointment:
        return 'Appointment';
      case TaskCategory.work:
        return 'Work';
      case TaskCategory.personal:
        return 'Personal';
      case TaskCategory.study:
        return 'Study';
      case TaskCategory.homework:
        return 'Homework';
      case TaskCategory.workout:
        return 'Workout';
    }
  }

  IconData _categoryIcon(TaskCategory category) {
    switch (category) {
      case TaskCategory.classMeeting:
        return Icons.school_rounded;
      case TaskCategory.appointment:
        return Icons.medical_services_rounded;
      case TaskCategory.work:
        return Icons.work_rounded;
      case TaskCategory.personal:
        return Icons.person_rounded;
      case TaskCategory.study:
        return Icons.menu_book_rounded;
      case TaskCategory.homework:
        return Icons.assignment_rounded;
      case TaskCategory.workout:
        return Icons.fitness_center_rounded;
    }
  }

  Color _categoryColor(TaskCategory category) {
    switch (category) {
      case TaskCategory.classMeeting:
        return const Color(0xFF5B5CE2);
      case TaskCategory.appointment:
        return const Color(0xFFE95075);
      case TaskCategory.work:
        return const Color(0xFF4777D9);
      case TaskCategory.personal:
        return const Color(0xFF8A63D2);
      case TaskCategory.study:
        return const Color(0xFF3A9D83);
      case TaskCategory.homework:
        return const Color(0xFFE18A3E);
      case TaskCategory.workout:
        return const Color(0xFF1C9DB0);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
