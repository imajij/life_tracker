import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../services/gemini_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _remainingCalls = 0;
  int _currentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAIUsage();
  }

  Future<void> _loadAIUsage() async {
    final geminiService = ref.read(geminiServiceProvider);
    final remaining = await geminiService.getRemainingCalls();
    final count = await geminiService.getCurrentCount();
    if (mounted) {
      setState(() {
        _remainingCalls = remaining;
        _currentCount = count;
      });
    }
  }

  Future<void> _resetAICounter() async {
    final geminiService = ref.read(geminiServiceProvider);
    await geminiService.resetDailyCount();
    await _loadAIUsage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI counter reset successfully!')),
      );
    }
  }

  Future<void> _editDailyGoals(BuildContext context) async {
    final db = ref.read(databaseProvider);
    final user = await db.getUser();

    if (user == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User profile not found')));
      return;
    }

    final waterController = TextEditingController(
      text: user.dailyWaterGoalMl.toString(),
    );
    final calorieController = TextEditingController(
      text: user.dailyCalorieGoal.toString(),
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Daily Goals'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: waterController,
              decoration: const InputDecoration(
                labelText: 'Daily Water Goal (ml)',
                hintText: '2500',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: calorieController,
              decoration: const InputDecoration(
                labelText: 'Daily Calorie Goal (kcal)',
                hintText: '2000',
              ),
              keyboardType: TextInputType.number,
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
              final waterGoal = int.tryParse(waterController.text);
              final calorieGoal = int.tryParse(calorieController.text);

              if (waterGoal == null || calorieGoal == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid numbers')),
                );
                return;
              }

              // Create updated user object
              final updatedUser = user.copyWith(
                dailyWaterGoalMl: waterGoal,
                dailyCalorieGoal: calorieGoal,
                updatedAt: DateTime.now(),
              );

              await db.updateUser(updatedUser);

              ref.invalidate(currentUserProvider);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Daily goals updated!')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _manageApiKey(BuildContext context) async {
    final storage = ref.read(secureStorageProvider);
    final hasKey = await storage.hasGeminiApiKey();

    if (!context.mounted) return;

    if (hasKey) {
      // Show delete confirmation
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Manage API Key'),
          content: const Text(
            'You have a Gemini API key stored. Do you want to delete it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await storage.deleteGeminiApiKey();
                ref.invalidate(geminiApiKeyProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API key deleted')),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else {
      // Show input dialog
      final controller = TextEditingController();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add API Key'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Gemini API Key',
              hintText: 'Paste your key here',
            ),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isEmpty) return;
                await storage.saveGeminiApiKey(controller.text);
                ref.invalidate(geminiApiKeyProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API key saved')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _exportData(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data export feature will be implemented')),
    );
  }

  Future<void> _resetApp(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text(
          'This will delete ALL data including your profile, entries, and settings. This cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final storage = ref.read(secureStorageProvider);
      await storage.clearAll();
      // TODO: Clear database
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App reset. Please restart.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKeyAsync = ref.watch(hasApiKeyProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.track_changes),
            title: const Text('Daily Goals'),
            subtitle: userAsync.when(
              data: (user) => Text(
                'Water: ${user?.dailyWaterGoalMl ?? 2500}ml, Calories: ${user?.dailyCalorieGoal ?? 2000}kcal',
              ),
              loading: () => const Text('Loading...'),
              error: (_, __) => const Text('Error'),
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _editDailyGoals(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('Gemini API Key'),
            subtitle: hasKeyAsync.when(
              data: (hasKey) => Text(hasKey ? 'Configured' : 'Not set'),
              loading: () => const Text('Loading...'),
              error: (_, __) => const Text('Error'),
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _manageApiKey(context),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('AI Usage Today'),
            subtitle: Text(
              'Used: $_currentCount / ${GeminiService.maxCallsPerDay} calls ($_remainingCalls remaining)',
            ),
            trailing: TextButton(
              onPressed: _resetAICounter,
              child: const Text('Reset'),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Data'),
            subtitle: const Text('Export all your data as JSON'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _exportData(context),
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Import Data'),
            subtitle: const Text('Import data from JSON file'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data import feature will be implemented'),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Reset App', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Delete all data and start fresh'),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red),
            onTap: () => _resetApp(context),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('About'),
            subtitle: Text(
              'LifeTracker MVP v1.0\nLocal-first health & productivity tracker',
            ),
          ),
        ],
      ),
    );
  }
}
