import 'package:expenseapp/Constants/Colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PieChartDisplay extends StatefulWidget {
  final Map<String, double> categorySums;

  const PieChartDisplay({
    Key? key,
    required this.categorySums,
  }) : super(key: key);

  @override
  _PieChartDisplayState createState() => _PieChartDisplayState();
}

class _PieChartDisplayState extends State<PieChartDisplay> with SingleTickerProviderStateMixin {
  int touchedIndex = -1;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller for smooth chart loading
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Dynamic color generation for new categories
  Color _getCategoryColor(String category, int index) {
    final Map<String, Color> categoryColors = {
      'Food': Colors.orange,
      'Travel': Colors.blue,
      'Shopping': Colors.green,
      'Uncategorized': Colors.grey,
    };
    if (categoryColors.containsKey(category)) {
      return categoryColors[category]!;
    }
    // Generate a color for new categories based on index
    final List<Color> fallbackColors = [
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.cyan,
    ];
    return fallbackColors[index % fallbackColors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categorySums.isEmpty) {
      return Card(
        color: AppColors.cardBackground,
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No expense data available for pie chart',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Card(
      color: AppColors.cardBackground,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          SizedBox(
            height: 250,
            child: FadeTransition(
              opacity: _animation,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: widget.categorySums.entries.map((entry) {
                    final index = widget.categorySums.keys.toList().indexOf(entry.key);
                    final isTouched = index == touchedIndex;
                    return PieChartSectionData(
                      color: _getCategoryColor(entry.key, index),
                      value: entry.value,
                      title: isTouched
                          ? '${entry.key}\n₹${entry.value.toStringAsFixed(0)}'
                          : entry.key,
                      radius: isTouched ? 110 : 100,
                      titleStyle: TextStyle(
                        fontSize: isTouched ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: isTouched
                            ? [
                                Shadow(
                                  blurRadius: 2,
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(1, 1),
                                ),
                              ]
                            : null,
                      ),
                      titlePositionPercentageOffset: 0.55,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          if (touchedIndex != -1) // Display touched section details
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '${widget.categorySums.keys.elementAt(touchedIndex)}: ₹${widget.categorySums.values.elementAt(touchedIndex).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}