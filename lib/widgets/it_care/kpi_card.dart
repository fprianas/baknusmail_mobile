// lib/widgets/it_care/kpi_card.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/it_care_models.dart';

class KpiDashboardWidget extends StatelessWidget {
  final KpiDashboard kpi;

  const KpiDashboardWidget({super.key, required this.kpi});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'KPI Helpdesk IT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (kpi.averageRating > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        '${kpi.averageRating.toStringAsFixed(1)} / 5.0',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 5 Metric Items in a Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Total Masuk',
                  value: '${kpi.totalTickets}',
                  icon: Icons.inbox_rounded,
                  color: const Color(0xFF1E40AF),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Tiket Baru',
                  value: '${kpi.newTickets}',
                  icon: Icons.fiber_new_rounded,
                  color: const Color(0xFF2563EB),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Diproses',
                  value: '${kpi.inProgressTickets}',
                  icon: Icons.sync_rounded,
                  color: const Color(0xFFD97706),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Selesai',
                  value: '${kpi.resolvedTickets}',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF059669),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Overdue SLA',
                  value: '${kpi.overdueSlaTickets}',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFDC2626),
                  isDark: isDark,
                  isAlert: kpi.overdueSlaTickets > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isAlert
            ? Colors.red.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlert
              ? Colors.red.withValues(alpha: 0.3)
              : color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
