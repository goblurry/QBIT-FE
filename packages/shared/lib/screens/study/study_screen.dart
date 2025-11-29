import 'package:flutter/material.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qbit_shared/widgets/common/app_header.dart';
import 'package:qbit_shared/utils/responsive_utils.dart';
import 'package:qbit_services/api/learning_card_api_service.dart';
import 'package:qbit_services/api/report_api_service.dart';
import 'package:qbit_services/api/order_api_service.dart';
import 'package:qbit_services/models/learning_card_model.dart';
import 'package:qbit_services/auth/auth_service.dart';
import 'package:go_router/go_router.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  String _userNickname = '';
  
  // 추천 카드 (id=1, id=16)
  List<LearningCard> _recommendedCards = [];
  bool _isLoadingRecommended = false;
  
  // 레벨별 카드
  Map<int, List<LearningCard>> _levelCards = {};
  Map<int, bool> _isLoadingLevel = {};
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      _loadRecommendedCards();
      _loadLevelCards();
    });
  }
  
  // 사용자 닉네임 가져오기
  Future<void> _loadUserData() async {
    try {
      final userInfo = await AuthService.getCurrentUser();
      if (!mounted) return;
      
      if (userInfo != null && userInfo['nickname'] != null) {
        setState(() {
          _userNickname = userInfo['nickname'] as String;
        });
      }
    } catch (error) {
      // 에러 무시
    }
  }
  
  // 추천 카드 로드 (리포트에서 추천하는 카드)
  Future<void> _loadRecommendedCards() async {
    setState(() {
      _isLoadingRecommended = true;
    });
    
    try {
      // 리포트에서 추천하는 학습 카드 ID 가져오기
      // 최근 거래 사이클 조회
      List<int> recommendedCardIds = [];
      
      try {
        final cyclesResponse = await OrderApiService.getTradeCycles(page: 0, size: 1);
        debugPrint('📚 [학습] 거래 사이클 조회 결과: ${cyclesResponse != null ? "성공" : "실패"}');
        
        if (cyclesResponse != null && cyclesResponse.content.isNotEmpty) {
          final latestCycle = cyclesResponse.content.first;
          debugPrint('📚 [학습] 최근 거래 사이클 ID: ${latestCycle.tradeCycleId}');
          
          final report = await ReportApiService.getTradeReport(latestCycle.tradeCycleId);
          debugPrint('📚 [학습] 리포트 조회 결과: ${report != null ? "성공" : "실패"}');
          
          if (report != null && report.learningCards.isNotEmpty) {
            recommendedCardIds = report.learningCards.map((c) => c.id).toList();
            debugPrint('📚 [학습] 리포트에서 추천 카드 ID 가져옴: $recommendedCardIds');
          } else {
            debugPrint('📚 [학습] 리포트에 학습 카드가 없음');
          }
        } else {
          debugPrint('📚 [학습] 거래 사이클이 없음');
        }
      } catch (e) {
        debugPrint('📚 [학습] 거래 사이클/리포트 조회 중 에러: $e');
      }
      
      // 리포트에서 추천 카드가 없으면 기본 추천 카드 ID 사용 (9, 11, 17)
      if (recommendedCardIds.isEmpty) {
        recommendedCardIds = [9, 11, 17];
        debugPrint('📚 [학습] 기본 추천 카드 ID 사용: $recommendedCardIds');
      }
      
      final response = await LearningCardApiService.getLearningCards();
      
      if (mounted) {
        if (response != null && response.isNotEmpty) {
          // 리포트에서 추천하는 카드 ID로 필터링
          final filteredCards = response
              .where((card) => recommendedCardIds.contains(card.id))
              .toList();
          
          // 추천 카드 ID 순서대로 정렬
          filteredCards.sort((a, b) {
            final indexA = recommendedCardIds.indexOf(a.id);
            final indexB = recommendedCardIds.indexOf(b.id);
            if (indexA == -1) return 1;
            if (indexB == -1) return -1;
            return indexA.compareTo(indexB);
          });
          
          setState(() {
            _recommendedCards = filteredCards.take(2).toList();
            _isLoadingRecommended = false;
          });
        } else {
          setState(() {
            _isLoadingRecommended = false;
          });
        }
      }
    } catch (e) {
      debugPrint('추천 카드 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingRecommended = false;
        });
      }
    }
  }
  
  // 레벨별 카드 로드
  Future<void> _loadLevelCards() async {
    // Level 1, Level 2, Level 3 로드
    for (int level = 1; level <= 3; level++) {
      setState(() {
        _isLoadingLevel[level] = true;
      });
      
      try {
        final response = await LearningCardApiService.getLearningCards(
          level: level,
        );
        
        if (mounted) {
          if (response != null && response.isNotEmpty) {
            setState(() {
              _levelCards[level] = response;
              _isLoadingLevel[level] = false;
            });
          } else {
            setState(() {
              _levelCards[level] = [];
              _isLoadingLevel[level] = false;
            });
          }
        }
      } catch (e) {
        debugPrint('레벨 $level 카드 로드 실패: $e');
        if (mounted) {
          setState(() {
            _levelCards[level] = [];
            _isLoadingLevel[level] = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: '학습',
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 노란색 배너: "큐빗님을 위한 추천"
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE19B),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: context.h(20)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.w(20)),
                    child: Text(
                      _userNickname.isNotEmpty 
                          ? '$_userNickname님을 위한 추천'
                          : '큐빗님을 위한 추천',
                      style: TextStyle(
                        color: const Color(0xFF323232),
                        fontSize: 18,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        height: 1.17,
                      ),
                    ),
                  ),
                  SizedBox(height: context.h(16)),
                  // 추천 카드들 (가로 스크롤)
                  if (_isLoadingRecommended)
                    Container(
                      height: context.h(163),
                      padding: EdgeInsets.symmetric(horizontal: context.w(20)),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_recommendedCards.isEmpty)
                    Container(
                      height: context.h(163),
                      padding: EdgeInsets.symmetric(horizontal: context.w(20)),
                      child: Center(
                        child: Text(
                          '추천 카드가 없습니다',
                          style: AppFonts.b2Regular.copyWith(
                            color: AppColors.gray600,
                          ),
                        ),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: context.w(20)),
                      child: Row(
                        children: [
                          ..._recommendedCards.asMap().entries.map((entry) {
                            final index = entry.key;
                            final card = entry.value;
                            return Row(
                              children: [
                                _buildLearningCard(
                                  context,
                                  card: card,
                                  onTap: () {
                                    context.push('/learning-card/${card.id}', extra: card);
                                  },
                                ),
                                if (index < _recommendedCards.length - 1)
                                  SizedBox(width: context.w(16)),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  SizedBox(height: context.h(20)), // 하단 여백
                ],
              ),
            ),
            
            // 레벨별 학습 섹션
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: context.h(20)),
                  Text(
                    '레벨별 학습',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w700,
                      height: 1.17,
                    ),
                  ),
                  
                  // Level 1
                  SizedBox(height: context.h(20)),
                  Text(
                    'Level 1',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: context.h(12)),
                  _buildLevelCards(context, level: 1),
                  
                  // Level 2
                  SizedBox(height: context.h(20)),
                  Text(
                    'Level 2',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: context.h(12)),
                  _buildLevelCards(context, level: 2),
                  
                  // Level 3
                  SizedBox(height: context.h(20)),
                  Text(
                    'Level 3',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: context.h(12)),
                  _buildLevelCards(context, level: 3),
                  
                  // 하단 여백
                  SizedBox(height: context.h(100)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 레벨별 카드 위젯
  Widget _buildLevelCards(BuildContext context, {required int level}) {
    final cards = _levelCards[level] ?? [];
    final isLoading = _isLoadingLevel[level] ?? false;
    
    if (isLoading) {
      return Container(
        height: context.h(163),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (cards.isEmpty) {
      return Container(
        height: context.h(163),
        child: Center(
          child: Text(
            'Level $level 카드가 없습니다',
            style: AppFonts.b2Regular.copyWith(
              color: AppColors.gray600,
            ),
          ),
        ),
      );
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...cards.asMap().entries.map((entry) {
            final index = entry.key;
            final card = entry.value;
            return Row(
              children: [
                _buildLearningCard(
                  context,
                  card: card,
                  onTap: () {
                    context.push('/learning-card/${card.id}', extra: card);
                  },
                ),
                if (index < cards.length - 1)
                  SizedBox(width: context.w(16)),
              ],
            );
          }),
        ],
      ),
    );
  }
  
  // 학습 카드 위젯 (리포트 화면과 동일한 디자인)
  Widget _buildLearningCard(
    BuildContext context, {
    LearningCard? card,
    String? title,
    String? tag,
    required VoidCallback onTap,
  }) {
    final cardTitle = card?.title ?? title ?? '제목 제목 제목';
    final categoryLabel = card != null 
        ? (card.category.isNotEmpty ? card.category : '학습 카드')
        : (tag ?? '학습 카드');
    
    // 리포트 화면과 동일하게 demo_bg 이미지 사용 (순환)
    final imagePaths = [
      'assets/icons/trade/trade_report_screen/demo_bg1.png',
      'assets/icons/trade/trade_report_screen/demo_bg2.png',
      'assets/icons/trade/trade_report_screen/demo_bg3.png',
    ];
    final imageIndex = card != null ? (card.id % imagePaths.length) : 0;
    final imagePath = imagePaths[imageIndex];

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: context.w(234),
          height: context.h(163),
          decoration: BoxDecoration(
            color: AppColors.secondaryBG,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 배경 이미지
              Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment(0.50, -0.00),
                        end: Alignment(0.50, 1.00),
                        colors: [Color(0xFFD9D9D9), Color(0xFF737373)],
                      ),
                    ),
                  );
                },
              ),
              // 그라데이션 오버레이 (리포트와 동일)
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
              // 텍스트 (리포트와 동일)
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
                      cardTitle,
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
      ),
    );
  }
}
