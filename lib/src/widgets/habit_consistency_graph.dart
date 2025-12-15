import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class HabitConsistencyGraph extends StatelessWidget {
  final Map<DateTime, int> completionsByDate;
  final int totalHabits;
  final int daysToShow;

  const HabitConsistencyGraph({
    super.key,
    required this.completionsByDate,
    required this.totalHabits,
    this.daysToShow = 7,
  });

  @override
  Widget build(BuildContext context) {
    final spots = _generateSpots();
    final maxY = totalHabits > 0 ? totalHabits.toDouble() + 1 : 5.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Habit Consistency',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            _buildConsistencyScore(),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: spots.isEmpty
              ? const Center(
                  child: Text(
                    'No habit data yet.\nComplete habits to see your consistency!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    minY: 0,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => Colors.blueGrey.shade800,
                        tooltipRoundedRadius: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final date = DateTime.now().subtract(
                            Duration(days: daysToShow - 1 - groupIndex),
                          );
                          return BarTooltipItem(
                            '${DateFormat('EEE, MMM d').format(date)}\n${rod.toY.toInt()} habit${rod.toY.toInt() == 1 ? '' : 's'}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            if (value == value.roundToDouble() && value >= 0) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= daysToShow) {
                              return const SizedBox.shrink();
                            }
                            final date = DateTime.now().subtract(
                              Duration(days: daysToShow - 1 - index),
                            );
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('E').format(date),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.2),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    barGroups: spots,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Last $daysToShow days',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildConsistencyScore() {
    final totalPossible = totalHabits * daysToShow;
    final totalCompleted = completionsByDate.values.fold(0, (a, b) => a + b);
    final percentage = totalPossible > 0
        ? ((totalCompleted / totalPossible) * 100).round()
        : 0;

    Color scoreColor;
    String emoji;
    if (percentage >= 80) {
      scoreColor = Colors.green;
      emoji = '🔥';
    } else if (percentage >= 50) {
      scoreColor = Colors.orange;
      emoji = '💪';
    } else if (percentage > 0) {
      scoreColor = Colors.amber;
      emoji = '🌱';
    } else {
      scoreColor = Colors.grey;
      emoji = '🎯';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$percentage% $emoji',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: scoreColor,
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateSpots() {
    final List<BarChartGroupData> spots = [];
    final today = DateTime.now();

    for (int i = 0; i < daysToShow; i++) {
      final date = today.subtract(Duration(days: daysToShow - 1 - i));
      final dateKey = DateTime(date.year, date.month, date.day);
      final count = completionsByDate[dateKey] ?? 0;

      // Determine bar color based on completion
      Color barColor;
      if (totalHabits > 0 && count >= totalHabits) {
        barColor = Colors.green; // All habits done
      } else if (count > 0) {
        barColor = Colors.blue; // Some habits done
      } else {
        barColor = Colors.grey.shade400; // No habits done
      }

      spots.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: barColor,
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return spots;
  }
}
