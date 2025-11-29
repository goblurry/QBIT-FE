import 'package:flutter/material.dart';

import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget; // For custom titles like logos
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Color backgroundColor;
  final Color contentColor;
  final bool centerTitle;
  final double elevation;
  final Widget? leadingIcon; // For custom back button or other leading icons

  const AppHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.showBack = true,
    this.onBack,
    this.actions,
    this.backgroundColor = Colors.white,
    this.contentColor = AppColors.gray900,
    this.centerTitle = true,
    this.elevation = 0,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: elevation,
      centerTitle: centerTitle,
      leading: showBack
          ? IconButton(
              icon: leadingIcon ?? Icon(Icons.arrow_back_ios, color: contentColor, size: 24),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            )
          : null,
      title: titleWidget ?? (title != null
          ? Text(
              title!,
              style: AppFonts.t2Bold.copyWith(color: contentColor),
            )
          : null),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
