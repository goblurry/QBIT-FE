import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/common/header_back.dart';

class AIReportDetailScreen extends StatelessWidget {
  const AIReportDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Gray-50
      appBar: AppHeader(
        title: 'AI 리포트 상세',
        onBack: () => context.pop(),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 투자 성향 섹션
            Container(
              width: double.infinity,
              height: 134,
              decoration: const BoxDecoration(
                color: Color(0xFFFCE6B3), // Secondary-Light
              ),
              child: Stack(
                children: [
                  // 텍스트 부분
                  Positioned(
                    left: 40,
                    top: 42,
                    child: Container(
                      width: 184,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '노현선님의 투자유형은',
                            style: TextStyle(
                              color: const Color(0xFF323232), // Gray-900
                              fontSize: 14,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w400,
                              height: 1.21,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '균형을 지키는 ',
                                  style: TextStyle(
                                    color: const Color(0xFF323232), // Gray-900
                                    fontSize: 18,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w600,
                                    height: 1.17,
                                  ),
                                ),
                                TextSpan(
                                  text: '중립형',
                                  style: TextStyle(
                                    color: const Color(0xFF04B99A), // Primary-Font(Dark)
                                    fontSize: 18,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w700,
                                    height: 1.17,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 올빼미 캐릭터
                  Positioned(
                    right: 40, // 오른쪽에서 40px 떨어진 위치
                    top: 20,
                    child: SvgPicture.asset(
                      'assets/images/characters/owl-mid.svg',
                      width: 122.18,
                      height: 94.63,
                    ),
                  ),
                ],
              ),
            ),
            
            // 매매 정보 컨테이너
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 날짜 범위
                    Text(
                      '25.10.03 ~ 25.10.17',
                      style: TextStyle(
                        color: const Color(0xFF7F7F7F), // Gray-600
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w400,
                        height: 1.23,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 종목명과 수익률 태그
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'FIGMA Inc. (FIG)',
                            style: TextStyle(
                              color: const Color(0xFF323232), // Gray-900
                              fontSize: 18,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                              height: 1.17,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                width: 1,
                                color: const Color(0xFFE74C3C), // Chart-Red
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          child: Text(
                            '+3.5%',
                            style: TextStyle(
                              color: const Color(0xFFE74C3C), // Chart-Red
                              fontSize: 13,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w400,
                              height: 1.23,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // 실현 손익 섹션
                    Center(
                      child: Column(
                        children: [
                          Text(
                            '실현 손익',
                            style: TextStyle(
                              color: const Color(0xFF7F7F7F), // Gray-600
                              fontSize: 14,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w400,
                              height: 1.21,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '+ 92 ',
                                  style: TextStyle(
                                    color: const Color(0xFFE74C3C), // Chart-Red
                                    fontSize: 28,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: 'USD',
                                  style: TextStyle(
                                    color: const Color(0xFFE74C3C), // Chart-Red
                                    fontSize: 16,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 메트릭 카드들 (2x2 그리드)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard('최대 손실폭', '2%'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard('최대 투입 금액', '1,000 USD'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard('평균 매수가', '89.2 USD'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard('평균 매도가', '92.3 USD'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // 전체 매매 평가 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '전체 매매 평가',
                    style: TextStyle(
                      color: const Color(0xFF323232), // Gray-900
                      fontSize: 18,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      height: 1.17,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '이번 매매는 초보 투자자에게 이상적인 흐름이었어요. 매수는 기술 지표가 안정적인 구간에서 이루어졌고, 시장 분위기를 무리 없이 따라간 점이 좋았습니다. 매도 시점도 과열 신호가 나타나기 직전으로, 시장가 대응을 통해 작은 수익을 확정한 점은 긍정적이에요. 다만, 명확한 익절 목표나 손절 기준이 없어서 매도 타이밍 판단이 다소 늦었고, 이후 이어진 상승 구간을 일부 놓쳤습니다. 향후에는 사전에 기준을 세워 감정적 판단을 줄이고, 기술적 신호를 체계적으로 활용하는 연습이 필요합니다.',
                      style: TextStyle(
                        color: const Color(0xFF323232), // Gray-900
                        fontSize: 16,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 거래 일지 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '거래 일지',
                    style: TextStyle(
                      color: const Color(0xFF323232), // Gray-900
                      fontSize: 18,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      height: 1.17,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 날짜와 상태
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '2025년 10월 17일',
                              style: TextStyle(
                                color: const Color(0xFF737373),
                                fontSize: 14,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w400,
                                height: 1.21,
                              ),
                            ),
                            Text(
                              '완료',
                              style: TextStyle(
                                color: const Color(0xFF7F7F7F), // Gray-600
                                fontSize: 14,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w400,
                                height: 1.21,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // 거래 정보
                        Row(
                          children: [
                            SvgPicture.asset(
                              'assets/images/characters/owl-smile.svg',
                              width: 50,
                              height: 38,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FIGMA',
                                    style: TextStyle(
                                      color: const Color(0xFF323232), // Gray-900
                                      fontSize: 16,
                                      fontFamily: 'Pretendard',
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                  ),
                                  Text(
                                    '매도 | 총액 \$153.13',
                                    style: TextStyle(
                                      color: const Color(0xFF178EDE), // Chart-Blue
                                      fontSize: 13,
                                      fontFamily: 'Pretendard',
                                      fontWeight: FontWeight.w400,
                                      height: 1.23,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // 거래 일지 텍스트
                        Text(
                          '수익은 얼마 안 됐지만 그래도 이익! 처음엔 언제 팔아야 할지 몰라 계속 차트만 봤는데, RSI가 높아진다는 걸 보고 팔았다... 다음엔 목표가랑 손절선 미리 정해두고 더 자신 있게 해봐야겠다.',
                          style: TextStyle(
                            color: const Color(0xFF7F7F7F), // Gray-600
                            fontSize: 16,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w400,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 추천 학습 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '추천 학습',
                    style: TextStyle(
                      color: const Color(0xFF323232), // Gray-900
                      fontSize: 18,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      height: 1.17,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 학습 카드들
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                      GestureDetector(
                        onTap: () {
                          // AI 리포트 분석 결과에서 추출된 태그들
                          final extractedTags = _extractTagsFromReport();
                          context.push('/learning-card/risk_management', extra: extractedTags);
                        },
                        child: Container(
                          width: 234,
                          height: 163,
                          decoration: ShapeDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment(0.50, -0.00),
                              end: Alignment(0.50, 1.00),
                              colors: [Color(0xFFD9D9D9), Color(0xFF737373)],
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 16,
                              top: 92,
                              child: Text(
                                '손절매와 익절 기준 설정',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              top: 127,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: ShapeDecoration(
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                                child: Text(
                                  '#리스크관리',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w400,
                                    height: 1.23,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          // AI 리포트 분석 결과에서 추출된 태그들
                          final extractedTags = _extractTagsFromReport();
                          context.push('/learning-card/investment_psychology', extra: extractedTags);
                        },
                        child: Container(
                        width: 234,
                        height: 163,
                        decoration: ShapeDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment(0.50, -0.00),
                            end: Alignment(0.50, 1.00),
                            colors: [Color(0xFFD9D9D9), Color(0xFF737373)],
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 16,
                              top: 90,
                              child: Text(
                                '공포에 사라는 말, 진짜일까?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              top: 125,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: ShapeDecoration(
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                                child: Text(
                                  '#투자심리',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w400,
                                    height: 1.23,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 하단 여백 추가
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3), // Secondary-BG
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFE19B), // Secondary-Main
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF7F7F7F), // Gray-600
              fontSize: 13,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              height: 1.23,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF323232), // Gray-900
              fontSize: 16,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  /// AI 리포트 분석 결과에서 태그 추출
  List<String> _extractTagsFromReport() {
    // 실제로는 AI 리포트 분석 결과에서 태그를 추출해야 함
    // 현재는 목업 데이터로 시뮬레이션
    
    final reportText = '''
    이번 매매는 초보 투자자에게 이상적인 흐름이었어요. 매수는 기술 지표가 안정적인 구간에서 이루어졌고, 
    시장 분위기를 무리 없이 따라간 점이 좋았습니다. 매도 시점도 과열 신호가 나타나기 직전으로, 
    시장가 대응을 통해 작은 수익을 확정한 점은 긍정적이에요. 다만, 명확한 익절 목표나 손절 기준이 없어서 
    매도 타이밍 판단이 다소 늦었고, 이후 이어진 상승 구간을 일부 놓쳤습니다. 향후에는 사전에 기준을 세워 
    감정적 판단을 줄이고, 기술적 신호를 체계적으로 활용하는 연습이 필요합니다.
    ''';

    // 키워드 기반 태그 추출 (실제로는 NLP 모델 사용)
    final List<String> extractedTags = [];
    
    if (reportText.contains('손절') || reportText.contains('손실')) {
      extractedTags.add('손절매');
    }
    if (reportText.contains('익절') || reportText.contains('수익')) {
      extractedTags.add('익절');
    }
    if (reportText.contains('기술') || reportText.contains('지표')) {
      extractedTags.add('기술지표');
    }
    if (reportText.contains('감정') || reportText.contains('판단')) {
      extractedTags.add('감정통제');
    }
    if (reportText.contains('기준') || reportText.contains('목표')) {
      extractedTags.add('기준설정');
    }
    if (reportText.contains('매도') || reportText.contains('타이밍')) {
      extractedTags.add('매도타이밍');
    }
    if (reportText.contains('초보') || reportText.contains('투자자')) {
      extractedTags.add('초보투자');
    }
    if (reportText.contains('RSI') || reportText.contains('과열')) {
      extractedTags.add('RSI');
    }

    return extractedTags;
  }
}