import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';

class ActivityDateChip extends StatelessWidget {
  final DateTime date;

  const ActivityDateChip({
    super.key,
    required this.date,
  });

  String _formatDateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);

    final diff = today.difference(itemDate).inDays;
    if (diff == 0) {
      return 'Hari Ini';
    } else if (diff == 1) {
      return 'Kemarin';
    } else {
      try {
        return DateFormat('d MMMM yyyy', 'id_ID').format(date);
      } catch (_) {
        return DateFormat('dd/MM/yyyy').format(date);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.brandBorder.withValues(alpha: 0.8),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          _formatDateLabel(),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.brandWarmGray,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
