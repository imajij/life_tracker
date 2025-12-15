import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../db/database.dart';
import '../../providers/app_providers.dart';

class StudyTasksScreen extends ConsumerWidget {
  const StudyTasksScreen({super.key});

  Future<void> _showAddTaskDialog(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    final durationController = TextEditingController();
    DateTime? dueDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Study Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'Goal Duration (minutes)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Due Date'),
                  subtitle: Text(
                    dueDate == null
                        ? 'Not set'
                        : '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => dueDate = picked);
                    }
                  },
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
              onPressed: () async {
                if (titleController.text.isEmpty) return;

                final db = ref.read(databaseProvider);
                final storage = ref.read(secureStorageProvider);

                try {
                  final userId = await storage.getUserId();
                  if (userId == null) throw Exception('No user found');

                  await db.insertStudyTask(
                    StudyTasksCompanion(
                      userId: drift.Value(userId),
                      title: drift.Value(titleController.text),
                      subject: drift.Value(subjectController.text),
                      durationGoalMinutes: durationController.text.isEmpty
                          ? const drift.Value.absent()
                          : drift.Value(int.parse(durationController.text)),
                      dueDate: dueDate == null
                          ? const drift.Value.absent()
                          : drift.Value(dueDate!),
                    ),
                  );

                  ref.invalidate(incompleteTasksProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTaskCompletion(
    BuildContext context,
    WidgetRef ref,
    StudyTask task,
  ) async {
    final db = ref.read(databaseProvider);

    try {
      await db.updateStudyTask(
        task.copyWith(
          completed: !task.completed,
          completedAt: !task.completed
              ? drift.Value(DateTime.now())
              : const drift.Value(null),
        ),
      );

      ref.invalidate(incompleteTasksProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              task.completed ? 'Task marked incomplete' : 'Task completed!',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(incompleteTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTaskDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(incompleteTasksProvider);
        },
        child: tasksAsync.when(
          data: (tasks) {
            if (tasks.isEmpty) {
              return const Center(
                child: Text('No tasks yet. Tap + to add one!'),
              );
            }

            return ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                final isOverdue =
                    task.dueDate != null &&
                    task.dueDate!.isBefore(DateTime.now()) &&
                    !task.completed;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: isOverdue ? Colors.red.shade50 : null,
                  child: ListTile(
                    leading: Checkbox(
                      value: task.completed,
                      onChanged: (_) =>
                          _toggleTaskCompletion(context, ref, task),
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Subject: ${task.subject}'),
                        if (task.durationGoalMinutes != null)
                          Text('Goal: ${task.durationGoalMinutes} min'),
                        if (task.dueDate != null)
                          Text(
                            'Due: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                            style: TextStyle(
                              color: isOverdue ? Colors.red : null,
                              fontWeight: isOverdue ? FontWeight.bold : null,
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final db = ref.read(databaseProvider);
                        await db.deleteStudyTask(task.id);
                        ref.invalidate(incompleteTasksProvider);
                      },
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}
