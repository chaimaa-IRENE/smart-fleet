import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../models/evolution_data.dart';

class EvolutionChart extends StatelessWidget {
  final List<EvolutionData> data;
  final String metric;

  const EvolutionChart({
    super.key,
    required this.data,
    this.metric = 'coutTotal',
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      double value = 0;
      if (metric == 'coutTotal') {
        value = data[i].coutTotal;
      } else if (metric == 'nombrePannes') {
        value = data[i].nombrePannes.toDouble();
      } else {
        value = data[i].coutTotal;
      }
      spots.add(FlSpot(i.toDouble(), value));
    }

    final maxY = spots.fold<double>(0, (max, s) => s.y > max ? s.y : max);
    final minY =
        spots.fold<double>(spots.first.y, (min, s) => s.y < min ? s.y : min);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble() : 1,
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < data.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data[idx].mois.length >= 7
                                ? data[idx].mois.substring(0, 7)
                                : data[idx].mois,
                            style: const TextStyle(fontSize: 9),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (data.length - 1).toDouble(),
              minY: minY > 0 ? minY * 0.9 : 0,
              maxY: maxY * 1.1,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppTheme.primary,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: AppTheme.primary,
                        strokeWidth: 0,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.primary.withValues(alpha: 0.08),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final idx = spot.spotIndex;
                      return LineTooltipItem(
                        '${idx < data.length ? data[idx].mois : ''}\n${spot.y.toStringAsFixed(0)}',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
