import 'dart:convert';

/// Model for a manual exercise plan created by the user
class ManualExercisePlanModel {
  final String name;
  final String? description;
  final List<PlanDay> days;

  ManualExercisePlanModel({
    required this.name,
    this.description,
    required this.days,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'days': days.map((d) => d.toJson()).toList(),
    };
  }

  factory ManualExercisePlanModel.fromJson(Map<String, dynamic> json) {
    return ManualExercisePlanModel(
      name: json['name'] as String,
      description: json['description'] as String?,
      days: (json['days'] as List)
          .map((d) => PlanDay.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ManualExercisePlanModel.fromJsonString(String jsonString) {
    return ManualExercisePlanModel.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}

class PlanDay {
  final String dayName; // e.g., "Monday", "Day 1", "Push Day"
  final List<PlanExercise> exercises;

  PlanDay({required this.dayName, required this.exercises});

  Map<String, dynamic> toJson() {
    return {
      'day_name': dayName,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }

  factory PlanDay.fromJson(Map<String, dynamic> json) {
    return PlanDay(
      dayName: json['day_name'] as String,
      exercises: (json['exercises'] as List)
          .map((e) => PlanExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PlanExercise {
  final String name;
  final String? category;
  final String? equipment;
  final int sets;
  final String reps; // Can be "8-12", "10", "to failure"
  final int restSeconds;
  final String? notes;

  PlanExercise({
    required this.name,
    this.category,
    this.equipment,
    required this.sets,
    required this.reps,
    this.restSeconds = 60,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (category != null) 'category': category,
      if (equipment != null) 'equipment': equipment,
      'sets': sets,
      'reps': reps,
      'rest_seconds': restSeconds,
      if (notes != null) 'notes': notes,
    };
  }

  factory PlanExercise.fromJson(Map<String, dynamic> json) {
    return PlanExercise(
      name: json['name'] as String,
      category: json['category'] as String?,
      equipment: json['equipment'] as String?,
      sets: json['sets'] as int,
      reps: json['reps'].toString(),
      restSeconds: json['rest_seconds'] as int? ?? 60,
      notes: json['notes'] as String?,
    );
  }
}
