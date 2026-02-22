// lib/presentation/screens/result/result_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/di/injection.dart';
import '../../../domain/entities/minutiae_record.dart';
import '../../../domain/entities/palm_session.dart';
import '../../viewmodels/result_viewmodel.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionId = ModalRoute.of(context)?.settings.arguments as String?;

    return ChangeNotifierProvider<ResultViewModel>(
      create: (_) => getIt<ResultViewModel>()..loadResults(sessionId ?? ''),
      child: const _ResultBody(),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ResultViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detection Results'),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.home, (route) => false),
        ),
      ),
      body: vm.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Success header
                  _buildSuccessHeader(context, vm),
                  const SizedBox(height: 24),

                  // Metrics card
                  _buildMetricsCard(context, vm),
                  const SizedBox(height: 24),

                  // Palm image
                  if (vm.session != null) _buildPalmCard(context, vm),
                  const SizedBox(height: 24),

                  // Finger records
                  Text('Captured Fingers',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ...vm.fingerRecords.map((r) => _buildFingerCard(context, r)),

                  const SizedBox(height: 32),
                  // Restart button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.palmDetection,
                          (r) => r.settings.name == AppRoutes.home),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Capture Again'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSuccessHeader(BuildContext context, ResultViewModel vm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detection Complete',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                Text(
                  '${vm.session?.handSide.label.replaceAll('_', ' ') ?? 'Hand'} — ${vm.fingerRecords.length}/5 fingers captured',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard(BuildContext context, ResultViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Image Quality Metrics',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.accent)),
          const SizedBox(height: 16),
          _MetricRow(
            label: 'Blur Score',
            value: vm.avgBlurScore.toStringAsFixed(1),
            icon: Icons.blur_on,
            color: vm.avgBlurScore > 100
                ? AppColors.successGreen
                : AppColors.warningOrange,
            description: vm.avgBlurScore > 100 ? 'Sharp' : 'Slightly blurred',
          ),
          const Divider(color: Colors.white10, height: 24),
          _MetricRow(
            label: 'Brightness Score',
            value: vm.avgBrightnessScore.toStringAsFixed(1),
            icon: Icons.brightness_6,
            color: (vm.avgBrightnessScore > 50 && vm.avgBrightnessScore < 220)
                ? AppColors.successGreen
                : AppColors.warningOrange,
            description: '0–255 range, ideal: 50–220',
          ),
          const Divider(color: Colors.white10, height: 24),
          _MetricRow(
            label: 'Focus Distance',
            value: '${vm.avgFocusDistance.toStringAsFixed(2)} m',
            icon: Icons.center_focus_strong,
            color: AppColors.accent,
            description: 'Auto-focus distance',
          ),
          if (vm.session != null) ...[
            const Divider(color: Colors.white10, height: 24),
            _MetricRow(
              label: 'Session ID',
              value: vm.session!.id.substring(0, 8) + '...',
              icon: Icons.fingerprint,
              color: AppColors.textSecondary,
              description: 'Unique capture session',
            ),
            const Divider(color: Colors.white10, height: 24),
            _MetricRow(
              label: 'Captured At',
              value: _formatTime(vm.session!.capturedAt),
              icon: Icons.access_time,
              color: AppColors.textSecondary,
              description: '',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPalmCard(BuildContext context, ResultViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Palm Image', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.4)),
          ),
          clipBehavior: Clip.antiAlias,
          height: 200,
          width: double.infinity,
          child: File(vm.session!.palmImagePath).existsSync()
              ? Image.file(
                  File(vm.session!.palmImagePath),
                  fit: BoxFit.cover,
                )
              : Container(
                  color: AppColors.cardBg,
                  child: const Center(
                    child: Icon(Icons.image_not_supported,
                        color: Colors.white38, size: 48),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          vm.session!.palmImagePath.split('/').last,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildFingerCard(BuildContext context, MinutiaeRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.surface,
            ),
            clipBehavior: Clip.antiAlias,
            child: File(record.imagePath).existsSync()
                ? Image.file(File(record.imagePath), fit: BoxFit.cover)
                : const Icon(Icons.fingerprint,
                    color: AppColors.accent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.handSide.replaceAll('_', ' ')} — ${record.fingerName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _MiniBadge(
                      label: 'Blur: ${record.blurScore.toStringAsFixed(0)}',
                      color: record.blurScore > 100
                          ? AppColors.successGreen
                          : AppColors.warningOrange,
                    ),
                    const SizedBox(width: 6),
                    _MiniBadge(
                      label:
                          'Brightness: ${record.brightnessScore.toStringAsFixed(0)}',
                      color: AppColors.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  record.imagePath.split('/').last,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle,
              color: AppColors.successGreen, size: 22),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${_pad(dt.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String description;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              if (description.isNotEmpty)
                Text(description,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
