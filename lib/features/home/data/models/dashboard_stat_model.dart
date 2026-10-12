import 'package:flutter/material.dart';

class DashboardDonutSliceModel {
  final String label;
  final double value;
  final Color color;

  const DashboardDonutSliceModel({
    required this.label,
    required this.value,
    required this.color,
  });

  factory DashboardDonutSliceModel.fromJson(Map<String, dynamic> json) {
    Color parsedColor = Colors.grey;
    final colorHex = json['color']?.toString() ?? '';
    if (colorHex.startsWith('#')) {
      final hexCode = colorHex.replaceFirst('#', '');
      if (hexCode.length == 6) {
        parsedColor = Color(int.parse('FF$hexCode', radix: 16));
      }
    }

    return DashboardDonutSliceModel(
      label: json['label']?.toString() ?? '',
      value: (json['value'] is num) ? (json['value'] as num).toDouble() : 0.0,
      color: parsedColor,
    );
  }
}

class DashboardDonutModel {
  final int percentage;
  final String centerLabel;
  final String centerSublabel;
  final List<DashboardDonutSliceModel> slices;

  const DashboardDonutModel({
    required this.percentage,
    required this.centerLabel,
    required this.centerSublabel,
    required this.slices,
  });

  factory DashboardDonutModel.fromJson(Map<String, dynamic> json) {
    final rawSlices = json['slices'] as List<dynamic>? ?? [];
    return DashboardDonutModel(
      percentage: json['percentage'] is int
          ? json['percentage'] as int
          : (json['percentage'] as num?)?.toInt() ?? 0,
      centerLabel: json['center_label']?.toString() ?? '0%',
      centerSublabel: json['center_sublabel']?.toString() ?? '',
      slices: rawSlices
          .map((s) => DashboardDonutSliceModel.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DashboardMetricModel {
  final String label;
  final String value;
  final Color color;

  const DashboardMetricModel({
    required this.label,
    required this.value,
    required this.color,
  });

  factory DashboardMetricModel.fromJson(Map<String, dynamic> json) {
    Color parsedColor = Colors.grey;
    final colorHex = json['color']?.toString() ?? '';
    if (colorHex.startsWith('#')) {
      final hexCode = colorHex.replaceFirst('#', '');
      if (hexCode.length == 6) {
        parsedColor = Color(int.parse('FF$hexCode', radix: 16));
      }
    }

    return DashboardMetricModel(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      color: parsedColor,
    );
  }
}

class DashboardStatModel {
  final String type; // 'bisnis' or 'pengantaran'
  final String title;
  final String dateFormatted;
  final DashboardDonutModel donut;
  final List<DashboardMetricModel> metrics;

  const DashboardStatModel({
    required this.type,
    required this.title,
    required this.dateFormatted,
    required this.donut,
    required this.metrics,
  });

  factory DashboardStatModel.fromJson(Map<String, dynamic> json) {
    final rawMetrics = json['metrics'] as List<dynamic>? ?? [];
    return DashboardStatModel(
      type: json['type']?.toString() ?? 'bisnis',
      title: json['title']?.toString() ?? 'Ringkasan',
      dateFormatted: json['date_formatted']?.toString() ?? '',
      donut: DashboardDonutModel.fromJson(
        json['donut'] as Map<String, dynamic>? ?? {},
      ),
      metrics: rawMetrics
          .map((m) => DashboardMetricModel.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
