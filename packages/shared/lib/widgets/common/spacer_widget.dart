import 'package:flutter/material.dart';
import 'package:qbit_shared/theme/app_colors.dart';

/// 스페이서 위젯
class SpacerWidget extends StatelessWidget {
  final double height;

  const SpacerWidget({
    super.key,
    this.height = AppSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height);
  }
}
