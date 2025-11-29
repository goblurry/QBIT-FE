import 'package:flutter/material.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';

/// 빈 상태 위젯
class EmptyWidget extends StatelessWidget {
  final String message;
  final IconData? icon;
  final Widget? action;

  const EmptyWidget({
    super.key,
    required this.message,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 64,
              color: AppColors.gray300,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppFonts.b1Semibold,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
