import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../widgets/habit_consistency_graph.dart';
import '../../services/widget_service.dart';
import '../root/main_shell.dart';
import '../water/water_tracker_screen.dart';
import '../study/study_tasks_screen.dart';
import '../workouts/workouts_screen.dart';
import '../diet/diet_plan_screen.dart';
import '../weight/weight_tracking_screen.dart';
import '../exercise/exercise_library_screen.dart';
import '../pomodoro/pomodoro_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Update widget data when home screen loads
    _updateWidgetData();
  }

  Future<void> _updateWidgetData() async {
    final database = ref.read(databaseProvider);
    await WidgetService.refreshWidgetData(database);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final todayCaloriesAsync = ref.watch(todayCaloriesProvider);
    final todayWaterAsync = ref.watch(todayWaterIntakeProvider);
    final habitsAsync = ref.watch(habitsProvider);
    final habitCompletionsAsync = ref.watch(habitCompletionsByDateProvider);
    final latestWeightAsync = ref.watch(latestWeightProvider);

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
            onPressed: () {
              ref.read(mainShellIndexProvider.notifier).state = 3;
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
            // Also update the home screen widget
            await _updateWidgetData();
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

              // Today's Calories - Tappable to navigate to Nutrition
              Card(
                child: InkWell(
                  onTap: () {
                    ref.read(mainShellIndexProvider.notifier).state = 1;
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Today\'s Calories',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
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
                                  value: (calories / calorieGoal).clamp(
                                    0.0,
                                    1.0,
                                  ),
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

              // Weight Tracking Card
              Card(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WeightTrackingScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Weight',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        latestWeightAsync.when(
                          data: (weightLog) {
                            if (weightLog == null) {
                              return const Text(
                                'No weight logged yet',
                                style: TextStyle(color: Colors.grey),
                              );
                            }
                            final initialWeight =
                                userAsync.value?.weightKg ?? weightLog.weightKg;
                            final diff = weightLog.weightKg - initialWeight;
                            final diffStr = diff >= 0
                                ? '+${diff.toStringAsFixed(1)}'
                                : diff.toStringAsFixed(1);
                            return Row(
                              children: [
                                Text(
                                  '${weightLog.weightKg.toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: diff < 0
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$diffStr kg',
                                    style: TextStyle(
                                      color: diff < 0
                                          ? Colors.green
                                          : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                    icon: Icons.restaurant,
                    label: 'Nutrition',
                    color: Colors.green,
                    onTap: () {
                      ref.read(mainShellIndexProvider.notifier).state = 1;
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
                      ref.read(mainShellIndexProvider.notifier).state = 2;
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
                  _QuickActionCard(
                    icon: Icons.monitor_weight,
                    label: 'Weight',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WeightTrackingScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.sports_gymnastics,
                    label: 'Exercises',
                    color: Colors.amber,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExerciseLibraryScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.timer,
                    label: 'Pomodoro',
                    color: Colors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PomodoroScreen(),
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
