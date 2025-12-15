import 'dart:convert';

class WorkoutPlanModel {
  final String goal;
  final int weeks;
  final int sessionsPerWeek;
  final List<WeekPlan> plan;
  final String? notes;

  WorkoutPlanModel({
    required this.goal,
    required this.weeks,
    required this.sessionsPerWeek,
    required this.plan,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'goal': goal,
      'weeks': weeks,
      'sessions_per_week': sessionsPerWeek,
      'plan': plan.map((w) => w.toJson()).toList(),
      if (notes != null) 'notes': notes,
    };
  }

  factory WorkoutPlanModel.fromJson(Map<String, dynamic> json) {
    return WorkoutPlanModel(
      goal: json['goal'] as String,
      weeks: json['weeks'] as int,
      sessionsPerWeek: json['sessions_per_week'] as int,
      plan: (json['plan'] as List)
          .map((w) => WeekPlan.fromJson(w as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory WorkoutPlanModel.fromJsonString(String jsonString) {
    return WorkoutPlanModel.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}

class WeekPlan {
  final int week;
  final List<DayPlan> days;

  WeekPlan({required this.week, required this.days});

  Map<String, dynamic> toJson() {
    return {'week': week, 'days': days.map((d) => d.toJson()).toList()};
  }

  factory WeekPlan.fromJson(Map<String, dynamic> json) {
    return WeekPlan(
      week: json['week'] as int,
      days: (json['days'] as List)
          .map((d) => DayPlan.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DayPlan {
  final String dayOfWeek;
  final List<Exercise> exercises;

  DayPlan({required this.dayOfWeek, required this.exercises});

  Map<String, dynamic> toJson() {
    return {
      'day_of_week': dayOfWeek,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    return DayPlan(
      dayOfWeek: json['day_of_week'] as String,
      exercises: (json['exercises'] as List)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Exercise {
  final String name;
  final int sets;
  final String reps; // Can be "8-12" or "30s" etc
  final String restS; // Rest in seconds

  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.restS,
  });

  Map<String, dynamic> toJson() {
    return {'name': name, 'sets': sets, 'reps': reps, 'rest_s': restS};
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'] as String,
      sets: json['sets'] as int,
      reps: json['reps'].toString(),
      restS: json['rest_s'].toString(),
    );
  }
}
