import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../db/database.dart';
import '../../providers/app_providers.dart';

class WaterTrackerScreen extends ConsumerWidget {
  const WaterTrackerScreen({super.key});

  Future<void> _addWater(BuildContext context, WidgetRef ref, int ml) async {
    final db = ref.read(databaseProvider);
    final storage = ref.read(secureStorageProvider);

    try {
      final userId = await storage.getUserId();
      if (userId == null) throw Exception('No user found');

      await db.insertWaterLog(
        WaterLogsCompanion(
          userId: drift.Value(userId),
          amountMl: drift.Value(ml),
        ),
      );

      ref.invalidate(todayWaterLogsProvider);
      ref.invalidate(todayWaterIntakeProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Added ${ml}ml of water!')));
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
    final waterIntakeAsync = ref.watch(todayWaterIntakeProvider);
    final waterLogsAsync = ref.watch(todayWaterLogsProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Water Tracker')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentUserProvider);
          ref.invalidate(todayWaterLogsProvider);
          ref.invalidate(todayWaterIntakeProvider);
        },
        child: userAsync.when(
          data: (user) {
            final dailyGoal = user?.dailyWaterGoalMl ?? 2500;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Today\'s Progress',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        waterIntakeAsync.when(
                          data: (intake) {
                            final progress = (intake / dailyGoal).clamp(
                              0.0,
                              1.0,
                            );
                            return Column(
                              children: [
                                SizedBox(
                                  height: 150,
                                  width: 150,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 12,
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Colors.blue,
                                            ),
                                      ),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${(intake / 1000).toStringAsFixed(1)} L',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'of ${dailyGoal / 1000} L',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}% Complete',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
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
                const SizedBox(height: 24),
                const Text(
                  'Quick Add',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _WaterButton(
                      ml: 250,
                      label: '1 Glass',
                      onTap: () => _addWater(context, ref, 250),
                    ),
                    _WaterButton(
                      ml: 500,
                      label: '1 Bottle',
                      onTap: () => _addWater(context, ref, 500),
                    ),
                    _WaterButton(
                      ml: 1000,
                      label: '1 Liter',
                      onTap: () => _addWater(context, ref, 1000),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Today\'s Log',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                waterLogsAsync.when(
                  data: (logs) {
                    if (logs.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No water logged yet today'),
                        ),
                      );
                    }
                    return Column(
                      children: logs.map((log) {
                        return ListTile(
                          leading: const Icon(
                            Icons.water_drop,
                            color: Colors.blue,
                          ),
                          title: Text('${log.amountMl} ml'),
                          subtitle: Text(
                            '${log.createdAt.hour}:${log.createdAt.minute.toString().padLeft(2, '0')}',
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error loading logs'),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const Center(child: Text('Error loading user data')),
        ),
      ),
    );
  }
}

class _WaterButton extends StatelessWidget {
  final int ml;
  final String label;
  final VoidCallback onTap;

  const _WaterButton({
    required this.ml,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
          child: Column(
            children: [
              Text(
                '$ml ml',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
