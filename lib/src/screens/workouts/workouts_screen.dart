import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../models/workout_plan_model.dart';
import '../../services/gemini_service.dart';
import '../../services/secure_storage_service.dart';
import '../../db/database.dart';
import 'dart:convert';

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  bool _isGenerating = false;

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

    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: RefreshIndicator(
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
                    const Text(
                      'No workout plans yet',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isGenerating ? null : _generateWorkoutPlan,
                      child: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Generate Plan with AI'),
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
    );
  }
}
