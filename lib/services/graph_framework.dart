import 'dart:math'; // For the 'max' function in _calculateMaxY
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SpectrumChart extends StatelessWidget {
  final bool showGraph;
  final List<FlSpot>? colorChartData;
  final List<FlSpot>? redChartData; // New: Optional reference data
  final List<FlSpot>? secondLineData;
  final List<FlSpot>? thirdLineData; // This will now be used for CIE data
  final double? maxY; // Optional maxY if external control is desired

  // New parameters for custom axis ranges and CIE chart specific configurations
  final double? minXOverride;
  final double? maxXOverride;
  final double? minYOverride;
  final double? maxYOverride;
  final bool isCIEChart;

  const SpectrumChart({
    Key? key,
    required this.showGraph,
    this.colorChartData,
    this.redChartData,
    this.secondLineData,
    this.thirdLineData, // This will now be used for CIE data
    this.maxY,
    // Initialize new parameters
    this.minXOverride,
    this.maxXOverride,
    this.minYOverride,
    this.maxYOverride,
    this.isCIEChart = false, // Default to false
  }) : super(key: key);

  // Helper function to calculate appropriate maxY based on data
  double _calculateDynamicMaxY(List<FlSpot> data, List<FlSpot>? referenceData) {
    List<double> allValues = [];
    if (data.isNotEmpty) {
      allValues.addAll(data.map((e) => e.y));
    }
    if (referenceData != null && referenceData.isNotEmpty) {
      allValues.addAll(referenceData.map((e) => e.y));
    }

    if (allValues.isEmpty) return 1000.0; // Default if no data

    double maxValue = allValues.reduce(max);

    const maxList = [
      0.5,
      1.0,
      1000.0,
      5000.0,
      10000.0,
      25000.0,
      50000.0,
      70000.0,
    ];
    double calculatedMaxY = 1000.0;
    for (var maxPoints in maxList) {
      if (maxValue < maxPoints) {
        calculatedMaxY = maxPoints;
        break;
      }
    }
    return calculatedMaxY;
  }

  // Helper function to calculate appropriate maxX based on data
  double _calculateDynamicMaxX(List<FlSpot> data) {
    if (data.isEmpty) return 8.0; // Default if no data

    double maxXValue = data.map((e) => e.x).reduce(max);
    // If the data is F1-F8, max X is 8. For other data, it might be different.
    // Here, assuming default max X for existing charts is 8.
    return maxXValue > 8.0 ? maxXValue : 8.0;
  }

  @override
  Widget build(BuildContext context) {
    // Determine the actual maxY for the chart
    final double chartMaxY =
        maxYOverride ??
        maxY ??
        _calculateDynamicMaxY(colorChartData ?? [], redChartData);
    final double chartMinX = minXOverride ?? 1;
    final double chartMaxX =
        maxXOverride ?? _calculateDynamicMaxX(colorChartData ?? []);
    final double chartMinY = minYOverride ?? 0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: !isCIEChart),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                // Custom titles for CIE chart
                if (isCIEChart) {
                  return Text(
                    value.toStringAsFixed(1), // Show numerical labels for CIE
                  );
                } else {
                  // Original titles for F1-F8 channels
                  switch (value.toInt()) {
                    case 1:
                      return const Text('F1');
                    case 2:
                      return const Text('F2');
                    case 3:
                      return const Text('F3');
                    case 4:
                      return const Text('F4');
                    case 5:
                      return const Text('F5');
                    case 6:
                      return const Text('F6');
                    case 7:
                      return const Text('F7');
                    case 8:
                      return const Text('F8');
                    default:
                      return const Text('');
                  }
                }
              },
            ),
          ),

          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.black, width: 2),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.white,
            tooltipBorder: const BorderSide(color: Colors.black),
          ),
        ),
        minX: chartMinX,
        maxX: chartMaxX,
        minY: chartMinY,
        maxY: chartMaxY, // Use the determined maxY
        lineBarsData: [
          if (colorChartData != null && colorChartData!.isNotEmpty)
            LineChartBarData(
              spots: colorChartData!,
              isCurved: true,
              barWidth: 2, // Adjusted barWidth as per your snippet
              color:
                  Colors.black, // Set line color to black as per your snippet
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true, // Always show area for colorChartData
                gradient: const LinearGradient(
                  colors: [
                    Color.fromRGBO(111, 47, 159, 0.8),
                    Color.fromRGBO(0, 31, 95, 0.8),
                    Color.fromRGBO(63, 146, 207, 0.8),
                    Color.fromRGBO(0, 175, 239, 0.8),
                    Color.fromRGBO(0, 175, 80, 0.8),
                    Color.fromRGBO(255, 255, 0, 0.8),
                    Color.fromRGBO(247, 149, 70, 0.8),
                    Color.fromRGBO(255, 0, 0, 0.8),
                  ],
                  stops: [
                    0,
                    0.14285714285714285,
                    0.2857142857142857,
                    0.42857142857142855,
                    0.5714285714285714,
                    0.7142857142857143,
                    0.8571428571428571,
                    1,
                  ],
                  begin: Alignment.bottomLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          // Reference Data Line
          if (redChartData != null && redChartData!.isNotEmpty)
            LineChartBarData(
              spots: redChartData!,
              isCurved: true,
              color: Colors.red, // Distinct color for reference data
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: false,
              ), // Reference data does not have area
              dashArray: [5, 5], // Dashed line for distinction
            ),
          if (secondLineData != null && secondLineData!.isNotEmpty)
            LineChartBarData(
              spots: secondLineData!,
              isCurved: true,
              color: Colors.red, // Distinct color for Basic Count
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          // Third Line Data (now potentially used for CIE 1931)
          if (thirdLineData != null && thirdLineData!.isNotEmpty)
            LineChartBarData(
              spots: thirdLineData!,
              isCurved: true,
              color: Colors.black,

              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: !isCIEChart, // Hide area for CIE charts
                gradient: const LinearGradient(
                  // No gradient for CIE charts
                  colors: [
                    // You might want a specific gradient for thirdLineData if not CIE,
                    // but for now, it's just a solid color as per previous code.
                    Colors.purple,
                    Colors.deepPurple,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
