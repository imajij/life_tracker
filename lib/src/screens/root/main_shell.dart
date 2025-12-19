import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../food/nutrition_screen.dart';
import '../habits/habits_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';

final mainShellIndexProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(mainShellIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          HomeScreen(),
          NutritionScreen(),
          HabitsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            ref.read(mainShellIndexProvider.notifier).state = value,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant_rounded),
            label: 'Nutrition',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_rtl_outlined),
            selectedIcon: Icon(Icons.checklist_rtl_rounded),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
