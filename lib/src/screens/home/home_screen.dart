import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../widgets/habit_consistency_graph.dart';
import '../food/add_food_screen.dart';
import '../water/water_tracker_screen.dart';
import '../habits/habits_screen.dart';
import '../study/study_tasks_screen.dart';
import '../workouts/workouts_screen.dart';
import '../settings/settings_screen.dart';
import '../diet/diet_plan_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final todayCaloriesAsync = ref.watch(todayCaloriesProvider);
    final todayWaterAsync = ref.watch(todayWaterIntakeProvider);
    final habitsAsync = ref.watch(habitsProvider);
    final habitCompletionsAsync = ref.watch(habitCompletionsByDateProvider);

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('LifeTracker'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF252538), Color(0xFF1E1E2E)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              // Refresh user data when coming back from settings
              ref.invalidate(currentUserProvider);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1E), Color(0xFF121218)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentUserProvider);
            ref.invalidate(todayCaloriesProvider);
            ref.invalidate(todayWaterIntakeProvider);
            ref.invalidate(habitsProvider);
            ref.invalidate(habitCompletionsByDateProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Welcome message
              userAsync.when(
                data: (user) => Text(
                  'Welcome back, ${user?.name ?? 'User'}!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Welcome!'),
              ),
              const SizedBox(height: 24),

              // Today's Calories
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today\'s Calories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      todayCaloriesAsync.when(
                        data: (calories) {
                          final calorieGoal =
                              userAsync.value?.dailyCalorieGoal ?? 2000;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${calories.toStringAsFixed(0)} / $calorieGoal kcal',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: (calories / calorieGoal).clamp(0.0, 1.0),
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  calories > calorieGoal
                                      ? Colors.orange
                                      : Colors.blue,
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Text('Error loading'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Water Intake
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Water Intake',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      todayWaterAsync.when(
                        data: (water) {
                          final waterGoal =
                              userAsync.value?.dailyWaterGoalMl ?? 2500;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(water / 1000).toStringAsFixed(2)} L / ${(waterGoal / 1000).toStringAsFixed(1)} L',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyan,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: (water / waterGoal).clamp(0.0, 1.0),
                                backgroundColor: Colors.grey.shade300,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.cyan,
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Text('Error loading'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Active Streaks
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Habits',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      habitsAsync.when(
                        data: (habits) {
                          if (habits.isEmpty) {
                            return const Text('No habits yet. Create one!');
                          }
                          return Column(
                            children: habits.map((habit) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.flash_on,
                                  color: Colors.orange,
                                ),
                                title: Text(habit.title),
                                trailing: Text(
                                  '${habit.streakCount} 🔥',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Text('Error loading habits'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Habit Consistency Graph
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: habitCompletionsAsync.when(
                    data: (completions) {
                      final totalHabits = habitsAsync.value?.length ?? 0;
                      return HabitConsistencyGraph(
                        completionsByDate: completions,
                        totalHabits: totalHabits,
                        daysToShow: 7,
                      );
                    },
                    loading: () => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SizedBox(
                      height: 200,
                      child: Center(
                        child: Text('Error loading consistency data'),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _QuickActionCard(
                    icon: Icons.camera_alt,
                    label: 'Add Food',
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddFoodScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.water_drop,
                    label: 'Log Water',
                    color: Colors.blue,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WaterTrackerScreen(),
                        ),
                      );
                      // Refresh data when coming back
                      ref.invalidate(currentUserProvider);
                      ref.invalidate(todayWaterIntakeProvider);
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.fitness_center,
                    label: 'Workouts',
                    color: Colors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WorkoutsScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.check_circle,
                    label: 'Habits',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HabitsScreen()),
                      );
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.book,
                    label: 'Study',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudyTasksScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.restaurant_menu,
                    label: 'Diet Plan',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DietPlanScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF252538), Color(0xFF1E1E2E)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
