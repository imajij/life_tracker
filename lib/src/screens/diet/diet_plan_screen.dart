import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../db/database.dart';
import '../../models/diet_plan_model.dart';
import '../../providers/app_providers.dart';

class DietPlanScreen extends ConsumerStatefulWidget {
  const DietPlanScreen({super.key});

  @override
  ConsumerState<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends ConsumerState<DietPlanScreen> {
  bool _isGenerating = false;
  String? _error;
  DietPlanModel? _currentPlan;
  int _selectedDayIndex = 0;
  String _motivationalQuote = '';
  int _remainingCalls = 5;

  final List<String> _quotes = [
    "Your body is a reflection of your lifestyle.",
    "Nutrition is not about being perfect, it's about being consistent.",
    "Take care of your body. It's the only place you have to live.",
    "Healthy eating is a form of self-respect.",
    "The food you eat can be either the safest medicine or the slowest poison.",
    "Don't dig your grave with your own knife and fork.",
    "A healthy outside starts from the inside.",
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingPlan();
    _loadRemainingCalls();
    _motivationalQuote = _quotes[Random().nextInt(_quotes.length)];
  }

  Future<void> _loadRemainingCalls() async {
    final geminiService = ref.read(geminiServiceProvider);
    final remaining = await geminiService.getRemainingCalls();
    if (mounted) {
      setState(() => _remainingCalls = remaining);
    }
  }

  Future<void> _loadExistingPlan() async {
    try {
      final db = ref.read(databaseProvider);
      final storage = ref.read(secureStorageProvider);
      final userId = await storage.getUserId();

      if (userId == null) return;

      final existingPlan = await db.getActiveDietPlan(userId);
      if (existingPlan != null && mounted) {
        setState(() {
          _currentPlan = DietPlanModel.fromJsonString(existingPlan.planJson);
        });
      }
    } catch (e) {
      // Ignore errors loading existing plan
    }
  }

  Future<void> _generateDietPlan() async {
    setState(() {
      _isGenerating = true;
      _error = null;
      _motivationalQuote = _quotes[Random().nextInt(_quotes.length)];
    });

    try {
      final geminiService = ref.read(geminiServiceProvider);
      final storage = ref.read(secureStorageProvider);
      final db = ref.read(databaseProvider);

      final apiKey = await storage.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        setState(() {
          _error = 'Please set your Gemini API key in settings first.';
          _isGenerating = false;
        });
        return;
      }

      final userId = await storage.getUserId();
      if (userId == null) {
        setState(() {
          _error = 'No user profile found. Please complete onboarding.';
          _isGenerating = false;
        });
        return;
      }

      // Get user profile from database
      final user = await db.getUser();
      if (user == null) {
        setState(() {
          _error = 'User profile not found.';
          _isGenerating = false;
        });
        return;
      }

      // Calculate age from DOB
      final now = DateTime.now();
      final age =
          now.year -
          user.dob.year -
          ((now.month < user.dob.month ||
                  (now.month == user.dob.month && now.day < user.dob.day))
              ? 1
              : 0);

      // Build user profile for AI
      final userProfile = {
        'age': age,
        'gender': user.gender,
        'height_cm': user.heightCm,
        'weight_kg': user.weightKg,
        'goal': user.goal,
        'activity_level': _mapActivityLevel(user.activityLevel),
        'diet_type': 'mixed', // Could be added to user profile later
        'meals_per_day': 3,
      };

      // Generate profile hash for caching
      final profileHash = generateProfileHash(userProfile);

      // Check if we have a cached plan for this profile
      final cachedPlan = await db.getDietPlanByProfileHash(userId, profileHash);
      if (cachedPlan != null) {
        setState(() {
          _currentPlan = DietPlanModel.fromJsonString(cachedPlan.planJson);
          _isGenerating = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Loaded cached diet plan')),
          );
        }
        return;
      }

      // Generate new plan
      final result = await geminiService.generateDietPlan(
        apiKey: apiKey,
        userProfile: userProfile,
      );

      await _loadRemainingCalls();

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final planModel = DietPlanModel.fromJson(data);

        // Deactivate old plans and save new one
        await db.deactivateAllDietPlans(userId);
        await db.insertDietPlan(
          DietPlansCompanion(
            userId: drift.Value(userId),
            goal: drift.Value(user.goal),
            targetCalories: drift.Value(planModel.dailyCalorieTarget),
            planJson: drift.Value(planModel.toJsonString()),
            profileHash: drift.Value(profileHash),
            source: const drift.Value('gemini'),
            isActive: const drift.Value(true),
          ),
        );

        setState(() {
          _currentPlan = planModel;
          _isGenerating = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Diet plan generated successfully!')),
          );
        }
      } else {
        final errorMsg = result['error'] as String? ?? 'Unknown error';
        final limitReached = result['limitReached'] == true;

        setState(() {
          _error = limitReached
              ? 'Daily AI limit reached. Please try again tomorrow.'
              : errorMsg;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Failed to generate diet plan: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString()}';
          _isGenerating = false;
        });
      }
    }
  }

  String _mapActivityLevel(String level) {
    switch (level) {
      case 'sedentary':
        return 'low';
      case 'light':
      case 'moderate':
        return 'medium';
      case 'very_active':
      case 'extra_active':
        return 'high';
      default:
        return 'medium';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diet Plan'),
        actions: [
          if (_currentPlan != null)
            IconButton(
              onPressed: _remainingCalls > 0 ? _generateDietPlan : null,
              icon: const Icon(Icons.refresh),
              tooltip: 'Regenerate Plan',
            ),
        ],
      ),
      body: _isGenerating
          ? _buildLoadingState(theme)
          : _currentPlan != null
          ? _buildPlanView(theme)
          : _buildEmptyState(theme),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Generating your personalized diet plan...',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.format_quote,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _motivationalQuote,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AI calls remaining indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _remainingCalls > 2
                    ? Colors.green.withOpacity(0.1)
                    : _remainingCalls > 0
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: _remainingCalls > 2
                        ? Colors.green
                        : _remainingCalls > 0
                        ? Colors.orange
                        : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_remainingCalls AI calls remaining today',
                    style: TextStyle(
                      color: _remainingCalls > 2
                          ? Colors.green
                          : _remainingCalls > 0
                          ? Colors.orange
                          : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Icon(
              Icons.restaurant_menu,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text('No Diet Plan Yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Generate a personalized 7-day diet plan\nbased on your profile and goals.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            ElevatedButton.icon(
              onPressed: _remainingCalls > 0 ? _generateDietPlan : null,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                _remainingCalls > 0
                    ? 'Generate AI Diet Plan'
                    : 'Daily Limit Reached',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanView(ThemeData theme) {
    final plan = _currentPlan!;

    return Column(
      children: [
        // Summary card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                '${plan.dailyCalorieTarget}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                'Daily Calorie Target',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MacroSummary(
                    label: 'Protein',
                    value: '${plan.macros.proteinG.toInt()}g',
                  ),
                  _MacroSummary(
                    label: 'Carbs',
                    value: '${plan.macros.carbsG.toInt()}g',
                  ),
                  _MacroSummary(
                    label: 'Fat',
                    value: '${plan.macros.fatG.toInt()}g',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Day selector
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: plan.plan.length,
            itemBuilder: (context, index) {
              final day = plan.plan[index];
              final isSelected = index == _selectedDayIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(day.day.substring(0, 3)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedDayIndex = index);
                    }
                  },
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),

        // Day's meals
        Expanded(
          child: plan.plan.isNotEmpty && _selectedDayIndex < plan.plan.length
              ? _buildDayMeals(theme, plan.plan[_selectedDayIndex])
              : const Center(child: Text('No meals for this day')),
        ),

        // Notes
        if (plan.notes != null && plan.notes!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.notes!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDayMeals(ThemeData theme, DayPlan dayPlan) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: dayPlan.meals.length,
      itemBuilder: (context, index) {
        final meal = dayPlan.meals[index];
        return _MealCard(meal: meal);
      },
    );
  }
}

class _MacroSummary extends StatelessWidget {
  final String label;
  final String value;

  const _MacroSummary({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealPlan meal;

  const _MealCard({required this.meal});

  IconData _getMealIcon(String mealName) {
    final lower = mealName.toLowerCase();
    if (lower.contains('breakfast')) return Icons.wb_sunny;
    if (lower.contains('lunch')) return Icons.wb_cloudy;
    if (lower.contains('dinner')) return Icons.nightlight_round;
    if (lower.contains('snack')) return Icons.cookie;
    return Icons.restaurant;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getMealIcon(meal.meal),
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    meal.meal,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${meal.calories} kcal',
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...meal.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(item, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
