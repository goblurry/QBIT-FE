import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/widgets/common/app_header.dart';

class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: '기록',
        showBack: false,
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/navigation/top-nav-alarm.svg',
              height: 26,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/navigation/top-nav-setting.svg',
              height: 26,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(
        child: Text(
          '기록 화면',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: AppColors.gray900,
          ),
        ),
      ),
    );
  }
}
