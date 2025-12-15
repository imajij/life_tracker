import 'dart:convert';

class DietPlanModel {
  final int dailyCalorieTarget;
  final DietMacros macros;
  final List<DayPlan> plan;
  final String? notes;

  DietPlanModel({
    required this.dailyCalorieTarget,
    required this.macros,
    required this.plan,
    this.notes,
  });

  factory DietPlanModel.fromJson(Map<String, dynamic> json) {
    return DietPlanModel(
      dailyCalorieTarget: (json['daily_calorie_target'] as num).toInt(),
      macros: DietMacros.fromJson(
        json['macros'] as Map<String, dynamic>? ?? {},
      ),
      plan:
          (json['plan'] as List<dynamic>?)
              ?.map((day) => DayPlan.fromJson(day as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'daily_calorie_target': dailyCalorieTarget,
      'macros': macros.toJson(),
      'plan': plan.map((day) => day.toJson()).toList(),
      'notes': notes,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory DietPlanModel.fromJsonString(String jsonString) {
    return DietPlanModel.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}

class DietMacros {
  final double proteinG;
  final double carbsG;
  final double fatG;

  DietMacros({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory DietMacros.fromJson(Map<String, dynamic> json) {
    return DietMacros(
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'protein_g': proteinG, 'carbs_g': carbsG, 'fat_g': fatG};
  }
}

class DayPlan {
  final String day;
  final List<MealPlan> meals;

  DayPlan({required this.day, required this.meals});

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    return DayPlan(
      day: json['day'] as String? ?? 'Day',
      meals:
          (json['meals'] as List<dynamic>?)
              ?.map((meal) => MealPlan.fromJson(meal as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {'day': day, 'meals': meals.map((meal) => meal.toJson()).toList()};
  }

  int get totalCalories => meals.fold(0, (sum, meal) => sum + meal.calories);
}

class MealPlan {
  final String meal;
  final List<String> items;
  final int calories;

  MealPlan({required this.meal, required this.items, required this.calories});

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      meal: json['meal'] as String? ?? 'Meal',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          [],
      calories: (json['calories'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'meal': meal, 'items': items, 'calories': calories};
  }
}

/// Helper to generate a profile hash for cache invalidation
String generateProfileHash(Map<String, dynamic> profile) {
  final sortedKeys = profile.keys.toList()..sort();
  final normalized = {for (var k in sortedKeys) k: profile[k]};
  final jsonStr = jsonEncode(normalized);
  // Simple hash - in production you might use crypto package
  return jsonStr.hashCode.toRadixString(16);
}
