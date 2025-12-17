import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../db/database.dart';
import '../../providers/app_providers.dart';
import '../../models/manual_exercise_plan_model.dart';
import 'exercise_library_screen.dart';

class ManualWorkoutPlanScreen extends ConsumerStatefulWidget {
  const ManualWorkoutPlanScreen({super.key});

  @override
  ConsumerState<ManualWorkoutPlanScreen> createState() =>
      _ManualWorkoutPlanScreenState();
}

class _ManualWorkoutPlanScreenState
    extends ConsumerState<ManualWorkoutPlanScreen> {
  final _planNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<PlanDay> _days = [];

  @override
  void dispose() {
    _planNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addDay() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(
          text: 'Day ${_days.length + 1}',
        );
        return AlertDialog(
          title: const Text('Add Workout Day'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Day Name',
              hintText: 'e.g., Push Day, Monday, Leg Day',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _days.add(PlanDay(dayName: controller.text, exercises: []));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addExerciseToDay(int dayIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseLibraryScreen(
          selectionMode: true,
          onExerciseSelected: (exercise) {
            _showExerciseConfigDialog(dayIndex, exercise);
          },
        ),
      ),
    );
  }

  void _showExerciseConfigDialog(int dayIndex, ExerciseLibraryData exercise) {
    final setsController = TextEditingController(text: '3');
    final repsController = TextEditingController(text: '10');
    final restController = TextEditingController(text: '60');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Configure ${exercise.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: setsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sets'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: repsController,
                      decoration: const InputDecoration(
                        labelText: 'Reps',
                        hintText: 'e.g., 10, 8-12',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: restController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Rest (seconds)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
                maxLines: 2,
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
              final sets = int.tryParse(setsController.text) ?? 3;
              final rest = int.tryParse(restController.text) ?? 60;

              setState(() {
                final updatedExercises = List<PlanExercise>.from(
                  _days[dayIndex].exercises,
                );
                updatedExercises.add(
                  PlanExercise(
                    name: exercise.name,
                    category: exercise.category,
                    equipment: exercise.equipment,
                    sets: sets,
                    reps: repsController.text,
                    restSeconds: rest,
                    notes: notesController.text.isNotEmpty
                        ? notesController.text
                        : null,
                  ),
                );

                _days[dayIndex] = PlanDay(
                  dayName: _days[dayIndex].dayName,
                  exercises: updatedExercises,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removeExercise(int dayIndex, int exerciseIndex) {
    setState(() {
      final updatedExercises = List<PlanExercise>.from(
        _days[dayIndex].exercises,
      );
      updatedExercises.removeAt(exerciseIndex);
      _days[dayIndex] = PlanDay(
        dayName: _days[dayIndex].dayName,
        exercises: updatedExercises,
      );
    });
  }

  void _removeDay(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Day'),
        content: Text(
          'Are you sure you want to delete "${_days[index].dayName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _days.removeAt(index));
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePlan() async {
    if (_planNameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a plan name')));
      return;
    }

    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one day')),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    final user = await db.getUser();
    if (user == null) return;

    final plan = ManualExercisePlanModel(
      name: _planNameController.text,
      description: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : null,
      days: _days,
    );

    await db.insertManualExercisePlan(
      ManualExercisePlansCompanion.insert(
        userId: user.id,
        name: _planNameController.text,
        description: drift.Value(
          _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : null,
        ),
        planJson: plan.toJsonString(),
      ),
    );

    ref.invalidate(manualExercisePlansProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout plan saved!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Workout Plan'),
        actions: [
          TextButton.icon(
            onPressed: _savePlan,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDay,
        icon: const Icon(Icons.add),
        label: const Text('Add Day'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Plan Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Plan Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _planNameController,
                    decoration: const InputDecoration(
                      labelText: 'Plan Name',
                      hintText: 'e.g., Push Pull Legs, Full Body',
                      prefixIcon: Icon(Icons.fitness_center),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Describe your workout plan',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Days
          if (_days.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 64,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 16),
                    const Text('No workout days added'),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap "Add Day" to create your workout schedule',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ..._days.asMap().entries.map((entry) {
              final dayIndex = entry.key;
              final day = entry.value;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              day.dayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.green,
                            ),
                            onPressed: () => _addExerciseToDay(dayIndex),
                            tooltip: 'Add Exercise',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeDay(dayIndex),
                            tooltip: 'Delete Day',
                          ),
                        ],
                      ),
                    ),

                    // Exercises
                    if (day.exercises.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'No exercises yet. Tap + to add.',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: day.exercises.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final exercises = List<PlanExercise>.from(
                              day.exercises,
                            );
                            final item = exercises.removeAt(oldIndex);
                            exercises.insert(newIndex, item);
                            _days[dayIndex] = PlanDay(
                              dayName: day.dayName,
                              exercises: exercises,
                            );
                          });
                        },
                        itemBuilder: (context, exerciseIndex) {
                          final exercise = day.exercises[exerciseIndex];
                          return ListTile(
                            key: ValueKey('${dayIndex}_$exerciseIndex'),
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                '${exerciseIndex + 1}',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              exercise.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${exercise.sets} sets × ${exercise.reps} reps • ${exercise.restSeconds}s rest',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (exercise.notes != null)
                                  IconButton(
                                    icon: Icon(
                                      Icons.info_outline,
                                      color: Colors.grey.shade400,
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Notes'),
                                          content: Text(exercise.notes!),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: Colors.red.shade300,
                                  ),
                                  onPressed: () =>
                                      _removeExercise(dayIndex, exerciseIndex),
                                ),
                                const Icon(Icons.drag_handle),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }
}

class ViewWorkoutPlanScreen extends ConsumerWidget {
  final ManualExercisePlan plan;

  const ViewWorkoutPlanScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ManualExercisePlanModel? model;
    try {
      model = ManualExercisePlanModel.fromJsonString(plan.planJson);
    } catch (e) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout Plan')),
        body: const Center(child: Text('Error loading plan')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(model.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Plan'),
                  content: const Text(
                    'Are you sure you want to delete this plan?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final db = ref.read(databaseProvider);
                await db.deleteManualExercisePlan(plan.id);
                ref.invalidate(manualExercisePlansProvider);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (model.description != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(model.description!),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          ...model.days.map(
            (day) => Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.blue),
                        const SizedBox(width: 12),
                        Text(
                          day.dayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${day.exercises.length} exercises',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                  ...day.exercises.asMap().entries.map((entry) {
                    final index = entry.key;
                    final exercise = entry.value;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        exercise.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${exercise.sets} sets × ${exercise.reps} reps'),
                          Text(
                            'Rest: ${exercise.restSeconds}s',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          if (exercise.notes != null)
                            Text(
                              exercise.notes!,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      isThreeLine: exercise.notes != null,
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
