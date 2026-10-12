import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/dashboard_stat_model.dart';

class HomeDonutChart extends StatelessWidget {
  final DashboardDonutModel donut;
  final double size;

  const HomeDonutChart({
    super.key,
    required this.donut,
    this.size = 78,
  });

  @override
  Widget build(BuildContext context) {
    // Siapkan list section pie chart
    final List<PieChartSectionData> sections = [];

    final hasValidValues = donut.slices.any((s) => s.value > 0);

    if (!hasValidValues) {
      sections.add(
        PieChartSectionData(
          color: const Color(0xFFE2E8F0),
          value: 1,
          radius: 11,
          showTitle: false,
        ),
      );
    } else {
      for (final slice in donut.slices) {
        if (slice.value <= 0) continue;
        sections.add(
          PieChartSectionData(
            color: slice.color,
            value: slice.value,
            radius: 11,
            showTitle: false,
          ),
        );
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Donut Chart dengan PieChart dari fl_chart
          PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: (size / 2) - 13,
              sectionsSpace: 2.5,
              startDegreeOffset: -90,
              borderData: FlBorderData(show: false),
            ),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          ),

          // Teks di tengah lubang donat
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                donut.centerLabel,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A), // Teks hitam pekat
                  height: 1.1,
                ),
              ),
              if (donut.centerSublabel.isNotEmpty)
                Text(
                  donut.centerSublabel,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandWarmGray,
                    height: 1.1,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget Indikator Persegi yang di-rotate 45 derajat (Diamond / Belah Ketupat)
class DiamondIndicator extends StatelessWidget {
  final Color color;
  final double size;

  const DiamondIndicator({
    super.key,
    required this.color,
    this.size = 7.5,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 45 * math.pi / 180, // Rotasi tepat 45 derajat
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}
