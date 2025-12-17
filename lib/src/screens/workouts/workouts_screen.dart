import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../models/workout_plan_model.dart';
import '../../models/manual_exercise_plan_model.dart';
import '../../services/gemini_service.dart';
import '../../services/secure_storage_service.dart';
import '../../db/database.dart';
import '../exercise/exercise_library_screen.dart';
import '../exercise/manual_workout_plan_screen.dart';
import 'dart:convert';

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen>
    with SingleTickerProviderStateMixin {
  bool _isGenerating = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateWorkoutPlan() async {
    setState(() => _isGenerating = true);

    try {
      final storage = SecureStorageService();
      final geminiService = GeminiService();
      final db = ref.read(databaseProvider);

      // Get API key
      final apiKey = await storage.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please set up your Gemini API key in Settings first.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() => _isGenerating = false);
        return;
      }

      // Get user profile
      final user = await db.getUser();
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile not found.')),
        );
        setState(() => _isGenerating = false);
        return;
      }

      // Calculate age
      final now = DateTime.now();
      final age = now.year - user.dob.year;

      // Create user profile for Gemini
      final userProfile = {
        'age': age,
        'weight_kg': user.weightKg,
        'height_cm': user.heightCm,
        'goal': 'maintain', // Default goal
        'activity_level': 'moderate',
        'available_days': 4,
        'equipment': ['bodyweight', 'dumbbells'],
      };

      // Call Gemini API
      final result = await geminiService.generateWorkoutPlan(
        apiKey: apiKey,
        userProfile: userProfile,
      );

      if (result['success'] == true) {
        final planData = result['data'] as Map<String, dynamic>;

        // Save to database
        await db.insertWorkoutPlan(
          WorkoutPlansCompanion.insert(
            userId: user.id,
            goal: planData['goal'] ?? 'general',
            planJson: json.encode(planData),
            source: 'gemini',
          ),
        );

        // Refresh the list
        ref.invalidate(workoutPlansProvider);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout plan generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate plan: ${result['error']}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(workoutPlansProvider);
    final manualPlansAsync = ref.watch(manualExercisePlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center),
            tooltip: 'Exercise Library',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ExerciseLibraryScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'AI Plans', icon: Icon(Icons.auto_awesome)),
            Tab(text: 'My Plans', icon: Icon(Icons.edit_note)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // AI Plans Tab
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(workoutPlansProvider);
            },
            child: plansAsync.when(
              data: (plans) {
                if (plans.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 64,
                          color: Colors.purple,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No AI workout plans yet',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isGenerating
                              ? null
                              : _generateWorkoutPlan,
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: const Text('Generate Plan with AI'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    WorkoutPlanModel? model;
                    try {
                      model = WorkoutPlanModel.fromJsonString(plan.planJson);
                    } catch (e) {
                      // Invalid JSON
                    }

                    return Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Goal: ${plan.goal}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Chip(
                                  label: Text(plan.source),
                                  backgroundColor: plan.source == 'gemini'
                                      ? Colors.purple.shade100
                                      : Colors.grey.shade200,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (model != null) ...[
                              Text(
                                '${model.weeks} weeks, ${model.sessionsPerWeek} sessions/week',
                              ),
                              if (model.notes != null) Text(model.notes!),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Created: ${plan.createdAt.day}/${plan.createdAt.month}/${plan.createdAt.year}',
                              style: TextStyle(color: Colors.grey.shade600),
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

          // Manual Plans Tab
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(manualExercisePlansProvider);
            },
            child: manualPlansAsync.when(
              data: (plans) {
                if (plans.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.edit_note,
                          size: 64,
                          color: Colors.teal,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No manual workout plans yet',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your own custom workout plan',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ManualWorkoutPlanScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Manual Plan'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    ManualExercisePlanModel? model;
                    try {
                      model = ManualExercisePlanModel.fromJsonString(
                        plan.planJson,
                      );
                    } catch (e) {
                      // Invalid JSON
                    }

                    final totalExercises =
                        model?.days.fold<int>(
                          0,
                          (sum, day) => sum + day.exercises.length,
                        ) ??
                        0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: plan.isActive
                              ? Colors.green
                              : Colors.grey.shade700,
                          child: Icon(
                            plan.isActive
                                ? Icons.play_arrow
                                : Icons.fitness_center,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          plan.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (plan.description != null &&
                                plan.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  plan.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade400),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${model?.days.length ?? 0} days',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$totalExercises exercises',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'activate') {
                              final db = ref.read(databaseProvider);
                              await db.setActivePlan(plan.id);
                              ref.invalidate(manualExercisePlansProvider);
                            } else if (value == 'view') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ViewWorkoutPlanScreen(plan: plan),
                                ),
                              );
                            } else if (value == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Plan'),
                                  content: Text('Delete "${plan.name}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final db = ref.read(databaseProvider);
                                await db.deleteManualExercisePlan(plan.id);
                                ref.invalidate(manualExercisePlansProvider);
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Text('View Plan'),
                            ),
                            if (!plan.isActive)
                              const PopupMenuItem(
                                value: 'activate',
                                child: Text('Set as Active'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ViewWorkoutPlanScreen(plan: plan),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _generateWorkoutPlan();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManualWorkoutPlanScreen(),
              ),
            );
          }
        },
        icon: Icon(_tabController.index == 0 ? Icons.auto_awesome : Icons.add),
        label: Text(
          _tabController.index == 0 ? 'Generate AI Plan' : 'Create Plan',
        ),
      ),
    );
  }
}
