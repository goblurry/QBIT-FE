import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:qbit_shared/widgets/common/header_back.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';
import 'package:qbit_shared/utils/responsive_utils.dart';
import 'package:qbit_shared/widgets/common/button/big_black_button.dart';

class TradeReportIntroScreen extends StatelessWidget {
  final int tradeCycleId;

  const TradeReportIntroScreen({
    super.key,
    required this.tradeCycleId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: 'AI 트레이딩 리포트',
        onBack: () => context.pop(),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
                    ),
        child: Stack(
                    children: [
            // 제목 (t2-bold)
            Positioned(
              left: context.w(22),
              top: context.h(80),
              child: Text(
                '보유 주식 전량 매도 완료',
                  style: AppFonts.t2Bold.copyWith(
                    color: AppColors.gray900,
                              fontFamily: 'Pretendard',
                  fontSize: 18,
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.w700,
                  height: 21 / 18,
                ),
              ),
            ),
            
            // 설명 텍스트 (b1-regular)
            Positioned(
              left: context.w(22),
              top: context.h(80) + context.h(11) + 24,
              child: SizedBox(
                width: context.w(342),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                      '이번 매매, 전략적으로 어땠을까요?',
                      style: AppFonts.b1Regular.copyWith(
                          color: AppColors.gray900,
                        ),
                      textAlign: TextAlign.left,
                      ),
                    SizedBox(height: context.h(4)),
                      Text(
                      '지금 리포트를 확인해보세요.',
                        style: AppFonts.b1Regular.copyWith(
                      color: AppColors.gray900,
                      ),
                      textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                ),
            ),
            
            // 부엉이 이미지
            Positioned(
              left: context.w(-20),
              right: context.w(20),
              top: context.h(250),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/trade/trade_report_screen/owl_before_report.svg',
                  width: context.w(341),
                  height: context.h(302),
                ),
              ),
            ),
            
            // 하단 텍스트 (좌우 중앙 정렬)
            Positioned(
              left: 0,
              right: 0,
              bottom: context.h(100),
              child: Center(
                    child: Text(
                  '감에 의존하는 투자는 이제 그만 -',
                          style: AppFonts.b2Regular.copyWith(
                            color: AppColors.gray600,
                          ),
                        ),
              ),
            ),
            
            // AI 리포트 확인 버튼 (하단 고정)
            Positioned(
              left: context.w(16),
              right: context.w(16),
              bottom: context.h(32),
              child: BigBlackButton(
                text: 'AI 리포트 확인',
                onPressed: () {
                  context.push('/trade-report-detail/$tradeCycleId');
                },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

