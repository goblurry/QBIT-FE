import 'package:flutter/material.dart';
import 'package:qbit_shared/theme/app_colors.dart';

/// 구분선 위젯
class DividerWidget extends StatelessWidget {
  final double? height;
  final Color? color;
  final EdgeInsets? margin;

  const DividerWidget({
    super.key,
    this.height,
    this.color,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 1,
      margin: margin ?? const EdgeInsets.symmetric(vertical: AppSpacing.md),
      color: color ?? AppColors.border,
    );
  }
}
