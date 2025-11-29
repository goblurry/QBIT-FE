import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:qbit_shared/widgets/common/header_back.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';
import 'package:qbit_shared/utils/responsive_utils.dart';
import 'package:qbit_services/api/report_api_service.dart';
import 'package:qbit_services/api/order_api_service.dart';
import 'package:qbit_services/models/trade_report_model.dart';
import 'package:qbit_services/models/trade_cycle_report_model.dart';
import 'package:qbit_shared/widgets/chart/trade_report_chart.dart';
import 'package:qbit_shared/widgets/common/button/big_black_button.dart';

class TradeReportScreen extends StatefulWidget {
  final int tradeCycleId;

  const TradeReportScreen({
    super.key,
    required this.tradeCycleId,
  });

  @override
  State<TradeReportScreen> createState() => _TradeReportScreenState();
}

class _TradeReportScreenState extends State<TradeReportScreen> {
  bool _isLoading = true;
  TradeReport? _report;
  String? _error;
  ReportTradeCycleResponse? _cycle;
  bool _isBuyAnalysisExpanded = true; // 매수 분석 접기/열기
  bool _isSellAnalysisExpanded = false; // 매도 분석 접기/열기

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await Future.wait([
        ReportApiService.getTradeReport(widget.tradeCycleId),
        OrderApiService.getReportTradeCycle(widget.tradeCycleId),
      ]);

      final TradeReport? report = results[0] as TradeReport?;
      final ReportTradeCycleResponse? cycle =
          results[1] as ReportTradeCycleResponse?;

      if (!mounted) return;

      setState(() {
        _report = report;
        _cycle = cycle;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '리포트를 불러오지 못했습니다.\n다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: '트레이딩 리포트',
        onBack: () => context.pop(),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (_error != null || _report == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error ?? '리포트를 불러오지 못했습니다.',
              style: AppFonts.b1Regular.copyWith(color: AppColors.gray600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadReport,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    final report = _report!;
    final cycle = _cycle;

    // 상단 카드에 사용할 값들 (없으면 기본값)
    String dateRangeText = '';
    String symbolText = '-';
    String stockNameText = 'Figma (FIG)';
    String realizedPlRateText = '--%';
    String realizedPlAmountText = '--';
    String realizedPlAmountUsdText = 'USD';
    Color realizedPlAmountColor = AppColors.gray900;

    if (cycle != null) {
      final start = cycle.startDate;
      final end = cycle.endDate ?? start;
      dateRangeText =
          '${start.year}.${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')}'
          ' - '
          '${end.year}.${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}';

      symbolText = cycle.symbol;
      // mock
      stockNameText = 'Figma (FIG)';

      final rate = cycle.profitLossRate;
      // 상세 응답에는 금액 필드가 없으므로, 최대 투입 금액과 손익률로 추정
      final amount = cycle.totalInvestmentAmount * rate / 100;

      final rateSign = rate > 0 ? '+' : rate < 0 ? '-' : '';
      final amountSign = amount > 0 ? '+' : amount < 0 ? '-' : '';

      realizedPlRateText = '$rateSign${rate.abs().toStringAsFixed(2)}%';
      // 숫자 포맷팅 (천 단위 콤마)
      final formattedAmount = amount.abs().toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      realizedPlAmountText = '$amountSign$formattedAmount';
      realizedPlAmountUsdText = 'USD';
      realizedPlAmountColor =
          amount >= 0 ? AppColors.loss : AppColors.profit;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상단 헤더 영역 (투자 유형 소개 + 부엉이)
          Container(
            color: AppColors.secondaryLight,
            padding: EdgeInsets.only(
              left: context.w(20),
              right: context.w(20),
              top: context.h(20),
              bottom: context.h(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                      Text(
                        '노현선님의 투자유형은',
                        style: AppFonts.b1Regular.copyWith(
                          color: AppColors.gray900,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '변화를 엿보는 성장형',
                        style: AppFonts.t2Bold.copyWith(
                          color: AppColors.primaryDark,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.w(12)),
                SizedBox(
                  width: context.w(120),
                  height: context.h(120),
                ),
              ],
            ),
          ),

          Stack(
            clipBehavior: Clip.none,
            children: [
              // 부엉이 아이콘
            Positioned(
                right: context.w(20),
                top: context.h(-140),
                child: SvgPicture.asset(
                  'assets/icons/trade/trade_report_screen/owl_head.svg',
                  width: context.w(120),
                  height: context.h(120),
                ),
              ),
              // 요약 카드
              Transform.translate(
                offset: Offset(0, -context.h(40)), // 부엉이와 겹치게
                child: Container(
        width: double.infinity,
                  constraints: BoxConstraints(
                    minHeight: context.h(280),
                  ),
                  padding: EdgeInsets.only(
                    left: context.w(20),
                    right: context.w(20),
                    top: context.h(18),
                    bottom: context.h(4),
                  ),
        decoration: BoxDecoration(
          color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dateRangeText.isNotEmpty) ...[
                        SizedBox(height: context.h(8)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              dateRangeText,
                              style: AppFonts.b2Regular.copyWith(
                                color: const Color(0xFF7F7F7F), // Gray-600
                                fontFamily: 'Pretendard',
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.gray300,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      // 종목 + 수익률 배지
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
          children: [
                          Text(
                            stockNameText,
                  style: AppFonts.t2Bold.copyWith(
                    color: AppColors.gray900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (cycle != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: realizedPlAmountColor,
                                  width: 1,
                                ),
                              ),
              child: Text(
                                realizedPlRateText,
                                style: AppFonts.c1.copyWith(
                                  color: realizedPlAmountColor,
                ),
              ),
            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 실현 손익 (금액)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '실현 손익',
                            style: AppFonts.b2Regular.copyWith(
                              color: const Color(0xFF7F7F7F), // Gray-600
                              fontFamily: 'Pretendard',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                realizedPlAmountText,
                                style: TextStyle(
                                  color: realizedPlAmountColor,
                                  fontSize: 28,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                realizedPlAmountUsdText,
                                style: TextStyle(
                                  color: realizedPlAmountColor,
                                  fontSize: 16,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 4개의 요약 지표 카드
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryStatCard(
                              title: '최대 손실폭',
                              value: cycle != null
                                  ? '${cycle.profitLossRate < 0 ? cycle.profitLossRate.abs().toStringAsFixed(2) : 0.toStringAsFixed(2)}%'
                                  : '--',
                            ),
                          ),
                          SizedBox(width: context.w(12)),
                          Expanded(
                            child: _buildSummaryStatCard(
                              title: '최대 투입 금액',
                              value: cycle != null
                                  ? '\$${cycle.totalInvestmentAmount.toStringAsFixed(2)}'
                                  : '--',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.h(10)),
                      Row(
          children: [
                          Expanded(
                            child: _buildSummaryStatCard(
                              title: '평균 매수가',
                              value: cycle != null
                                  ? '\$${cycle.averageBuyPrice.toStringAsFixed(2)}'
                                  : '--',
                            ),
                          ),
                          SizedBox(width: context.w(12)),
                          Expanded(
                            child: _buildSummaryStatCard(
                              title: '평균 매도가',
                              value: cycle != null &&
                                      cycle.averageSellPrice != null
                                  ? '\$${cycle.averageSellPrice!.toStringAsFixed(2)}'
                                  : '--',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 메인 내용 영역 (회색 배경)
          Container(
            color: AppColors.gray30,
            padding: EdgeInsets.symmetric(
              horizontal: context.w(16),
              vertical: context.h(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // 상세 분석 차트
                if (cycle != null && cycle.chartData.isNotEmpty) ...[
                  Text(
                    '상세 분석',
                    style: AppFonts.t2Bold.copyWith(
                      color: AppColors.gray900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: context.h(420),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.04),
                          offset: Offset(0, 4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: TradeReportChart(
                      candles: cycle.chartData,
                      tradePoints: cycle.tradePoints,
                      interval: cycle.interval,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 전체 평가
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.w(20),
                    vertical: context.h(20),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.04),
                        offset: Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '전체 매매 평가',
                        style: AppFonts.t2Bold.copyWith(
                          color: AppColors.gray900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        report.overallEvaluation,
                        style: AppFonts.b1Regular.copyWith(
                          color: const Color(0xFF323232), // gray-900-font-black
                        ),
                      ),
                    ],
                  ),
                ),
            
                const SizedBox(height: 24),

              ],
            ),
          ),

          // 추천 학습 카드 (전체 매매 평가 다음)
          if (report.learningCards.isNotEmpty) ...[
            Container(
              width: double.infinity,
              color: const Color(0xFFFCE6B3), // Secondary-Light
              padding: EdgeInsets.only(
              left: context.w(16),
              right: context.w(16),
                top: context.h(24),
                bottom: context.h(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '추천 학습',
                    style: AppFonts.t2Bold.copyWith(
                      color: AppColors.gray900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLearningCardsSection(report),
                ],
              ),
            ),
          ],

          // 메인 내용 영역 (회색 배경) - 시장 상황, 매수/매도 분석
          Container(
            color: AppColors.gray30,
            padding: EdgeInsets.symmetric(
              horizontal: context.w(16),
              vertical: context.h(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 시장 상황
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.w(20),
                    vertical: context.h(20),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.04),
                        offset: Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '시장 상황',
                        style: AppFonts.t2Bold.copyWith(
                          color: AppColors.gray900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        report.marketContext,
                        style: AppFonts.b1Regular.copyWith(
                          color: const Color(0xFF323232),
                        ),
                      ),
                    ],
                  ),
                ),
            
                const SizedBox(height: 24),

                // 매수 분석
                _buildTimingAnalysisSection(
                  title: '주요 매수 시점',
                  date: cycle?.startDate,
                  evaluation: report.buyEvaluation,
                  improvement: report.buyImprovement,
                  rsi: report.buyRsi,
                  macd: report.buyMacd,
                  isExpanded: _isBuyAnalysisExpanded,
                  onToggle: () {
                    setState(() {
                      _isBuyAnalysisExpanded = !_isBuyAnalysisExpanded;
                    });
                  },
                ),

                const SizedBox(height: 24),

                // 매도 분석
                _buildTimingAnalysisSection(
                  title: '주요 매도 시점',
                  date: cycle?.endDate ?? cycle?.startDate,
                  evaluation: report.sellEvaluation,
                  improvement: report.sellImprovement,
                  rsi: report.sellRsi,
                  macd: report.sellMacd,
                  isExpanded: _isSellAnalysisExpanded,
                  onToggle: () {
                    setState(() {
                      _isSellAnalysisExpanded = !_isSellAnalysisExpanded;
                    });
                  },
                ),
              ],
            ),
          ),

          // 거래 일지 모아보기 버튼
          Container(
            color: AppColors.gray30,
            padding: EdgeInsets.symmetric(
              horizontal: context.w(16),
              vertical: context.h(24),
            ),
              child: BigBlackButton(
              text: '거래 일지 모아보기',
                onPressed: () {
                // TODO: 거래 일지 화면으로 이동
                // context.push('/trade-journal');
                },
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildIndicatorSection(String label, TradeReportIndicator indicator) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray30,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ${indicator.value.toStringAsFixed(2)}',
            style: AppFonts.b2Semibold.copyWith(color: AppColors.gray900),
          ),
          const SizedBox(height: 4),
          Text(
            indicator.analysis,
            style: AppFonts.c1.copyWith(color: AppColors.gray600),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningCardsSection(TradeReport report) {
    // 최대 3개까지만 노출
    final cards = report.learningCards.take(3).toList();

    // 카드별 배경 이미지 경로
    final imagePaths = [
      'assets/icons/trade/trade_report_screen/demo_bg1.png',
      'assets/icons/trade/trade_report_screen/demo_bg2.png',
      'assets/icons/trade/trade_report_screen/demo_bg3.png',
    ];

    return SizedBox(
      height: 163,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              SizedBox(
                width: 234,
                height: 163,
                child: _buildLearningCard(
                  cards[i],
                  imagePaths[i % imagePaths.length],
                ),
              ),
              if (i < cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLearningCard(
      TradeReportLearningCard card, String imageAssetPath) {
    // 제목은 두 줄까지만, 너무 길면 잘라서 표시
    final title = card.title;
    final categoryLabel =
        card.category.isNotEmpty ? card.category : '학습 카드';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 163,
        decoration: BoxDecoration(
          color: AppColors.secondaryBG,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 배경 이미지
            Image.asset(
              imageAssetPath,
              fit: BoxFit.cover,
            ),
            // 그라디언트 오버레이
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
            // 텍스트
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      categoryLabel,
                      style: AppFonts.c2.copyWith(
                        color: Colors.white,
                ),
              ),
            ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.b1Semibold.copyWith(
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 타이밍 분석 섹션 (접기/열기 가능)
  Widget _buildTimingAnalysisSection({
    required String title,
    DateTime? date,
    required String evaluation,
    required String improvement,
    required TradeReportIndicator rsi,
    required TradeReportIndicator macd,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    String dateText = '';
    if (date != null) {
      dateText = '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (제목 + 날짜 + 접기/열기 버튼)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.w(20),
              vertical: context.h(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppFonts.b1Semibold.copyWith(
                          color: AppColors.gray900,
                        ),
                      ),
                      if (dateText.isNotEmpty) ...[
                        SizedBox(width: context.w(6)),
                        Text(
                          dateText,
                          style: AppFonts.b2Regular.copyWith(
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onToggle,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isExpanded ? '접기' : '열기',
                    style: AppFonts.c1.copyWith(
                      color: AppColors.gray600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 확장된 내용
          if (isExpanded) ...[
            // 설명 텍스트 (연한 초록색 배경)
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: context.w(20)),
              padding: EdgeInsets.symmetric(
                horizontal: context.w(20),
                vertical: context.h(16),
              ),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.5), // Primary-BG: #E6F4F1 with 50% opacity
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                evaluation,
                style: AppFonts.b1Regular.copyWith(
                  color: const Color(0xFF323232),
                ),
              ),
            ),

            SizedBox(height: context.h(16)),

            // 기술적 지표들 (2열 - RSI, MACD만 API 데이터 사용)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(20)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RSI(14)',
                          style: AppFonts.c1.copyWith(
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${rsi.value.toStringAsFixed(1)} (${_getRsiStatus(rsi.value)})',
                          style: AppFonts.b1Regular.copyWith(
                            color: const Color(0xFF323232),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: context.w(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MACD',
                          style: AppFonts.c1.copyWith(
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          macd.value > 0 ? '골든크로스 직전' : '데드크로스',
                          style: AppFonts.b1Regular.copyWith(
                            color: const Color(0xFF323232),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: context.h(16)),

            // 구분선
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.gray100,
              indent: context.w(20),
              endIndent: context.w(20),
            ),

            SizedBox(height: context.h(16)),

            // 개선 방안
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '개선 방안',
                    style: AppFonts.b1Semibold.copyWith(
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    improvement,
                    style: AppFonts.b1Regular.copyWith(
                      color: const Color(0xFF323232),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: context.h(16)),
          ],
        ],
      ),
    );
  }

  String _getRsiStatus(double rsi) {
    if (rsi >= 70) return '과열';
    if (rsi <= 30) return '과매도';
    return '적정';
  }

  /// 상단 4개 요약 지표 카드
  Widget _buildSummaryStatCard({
    required String title,
    required String value,
  }) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.secondaryBG,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondaryMain,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: AppFonts.c1.copyWith(
              color: const Color(0xFF7F7F7F), // Gray-600
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppFonts.b1Semibold.copyWith(
              color: const Color(0xFF323232), // gray-900-font-black
              fontFamily: 'Pretendard',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
