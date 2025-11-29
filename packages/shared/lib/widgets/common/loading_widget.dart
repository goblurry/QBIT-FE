import 'package:flutter/material.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';

/// 로딩 위젯
class LoadingWidget extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;

  const LoadingWidget({
    super.key,
    this.message,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? AppColors.primary,
              ),
              strokeWidth: 2.0,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: AppFonts.b1Regular,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
