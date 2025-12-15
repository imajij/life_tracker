import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../db/database.dart';
import '../../providers/app_providers.dart';
import '../../utils/date_utils.dart' as app_utils;

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  Future<void> _toggleHabit(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
  ) async {
    final db = ref.read(databaseProvider);

    try {
      final today = DateTime.now();
      final lastDone = habit.lastDoneDate;

      final isToday =
          lastDone != null && app_utils.DateUtils.isSameDay(lastDone, today);

      if (isToday) {
        // Already done today - untoggle not supported for simplicity
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Already completed today!')),
          );
        }
        return;
      }

      // Check if streak should continue or reset
      int newStreak = habit.streakCount;
      if (lastDone != null) {
        final yesterday = today.subtract(const Duration(days: 1));
        if (app_utils.DateUtils.isSameDay(lastDone, yesterday)) {
          // Continuing streak
          newStreak += 1;
        } else {
          // Streak broken, reset to 1
          newStreak = 1;
        }
      } else {
        // First time
        newStreak = 1;
      }

      final newBestStreak = newStreak > habit.bestStreak
          ? newStreak
          : habit.bestStreak;

      await db.updateHabit(
        habit.copyWith(
          streakCount: newStreak,
          bestStreak: newBestStreak,
          lastDoneDate: drift.Value(today),
        ),
      );

      await db.insertHabitLog(
        HabitLogsCompanion(habitId: drift.Value(habit.id)),
      );

      ref.invalidate(habitsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${habit.title} completed! Streak: $newStreak 🔥'),
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

  Future<void> _showAddHabitDialog(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    String periodicity = 'daily';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Habit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Habit Name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: periodicity,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              ],
              onChanged: (value) {
                if (value != null) periodicity = value;
              },
            ),
          ],
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

                await db.insertHabit(
                  HabitsCompanion(
                    userId: drift.Value(userId),
                    title: drift.Value(titleController.text),
                    periodicity: drift.Value(periodicity),
                  ),
                );

                ref.invalidate(habitsProvider);
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
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits & Streaks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddHabitDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(habitsProvider);
        },
        child: habitsAsync.when(
          data: (habits) {
            if (habits.isEmpty) {
              return const Center(
                child: Text('No habits yet. Tap + to add one!'),
              );
            }

            return ListView.builder(
              itemCount: habits.length,
              itemBuilder: (context, index) {
                final habit = habits[index];
                final today = DateTime.now();
                final lastDone = habit.lastDoneDate;
                final isDoneToday =
                    lastDone != null &&
                    app_utils.DateUtils.isSameDay(lastDone, today);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: IconButton(
                      icon: Icon(
                        isDoneToday
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isDoneToday ? Colors.green : Colors.grey,
                        size: 32,
                      ),
                      onPressed: () => _toggleHabit(context, ref, habit),
                    ),
                    title: Text(
                      habit.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Best: ${habit.bestStreak} days',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${habit.streakCount} 🔥',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        Text(
                          habit.periodicity,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
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
