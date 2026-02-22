// lib/presentation/widgets/luminosity_indicator.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/entities/luminosity_record.dart';
import '../../services/camera_service.dart';

class LuminosityIndicator extends StatelessWidget {
  final LuminosityData? data;

  const LuminosityIndicator({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();

    final condition = data!.lightCondition;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(condition),
            color: _getColor(condition),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            condition.label,
            style: TextStyle(
              color: _getColor(condition),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(LightCondition condition) {
    switch (condition) {
      case LightCondition.low: return Icons.brightness_3;
      case LightCondition.bright: return Icons.wb_sunny;
      case LightCondition.normal: return Icons.light_mode;
    }
  }

  Color _getColor(LightCondition condition) {
    switch (condition) {
      case LightCondition.low: return AppColors.errorRed;
      case LightCondition.bright: return AppColors.warningOrange;
      case LightCondition.normal: return AppColors.successGreen;
    }
  }
}
