import 'package:flutter/material.dart';
import 'package:qbit_shared/widgets/common/bottom_navigation_bar.dart';
import 'package:qbit_shared/widgets/common/app_header.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qbit_shared/screens/study/study_screen.dart';
import 'package:qbit_shared/screens/record/record_screen.dart';
import 'package:qbit_shared/screens/trade/trade_screen.dart';
import 'package:qbit_shared/screens/my/my_screen.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:qbit_services/auth/auth_service.dart';
import 'package:qbit_services/storage/token_service.dart';
import 'package:qbit_services/api/ai_api_service.dart';
import 'package:qbit_services/api/stock_api_service.dart';
import 'package:qbit_services/api/learning_card_api_service.dart';
import 'package:qbit_services/api/report_api_service.dart';
import 'package:qbit_services/api/order_api_service.dart';
import 'package:qbit_services/api/portfolio_api_service.dart';
import 'package:qbit_services/models/recommend_column_response.dart';
import 'package:qbit_services/models/column.dart' as models;
import 'package:qbit_services/models/learning_card_model.dart';
import 'package:qbit_services/models/portfolio_position_model.dart';
import 'package:qbit_shared/widgets/home/portfolio_positions_widget.dart';
import 'package:kakao_flutter_sdk_auth/kakao_flutter_sdk_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qbit_shared/utils/responsive_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeContentScreen(),
    const StudyScreen(),
    const RecordScreen(),
    const TradeScreen(),
    const MyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomBottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HomeContentScreen extends StatefulWidget {
  const HomeContentScreen({super.key});

  @override
  State<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  String _userNickname = '';
  String _currentDate = '';
  RecommendColumnResponse? _columnResponse;
  bool _isLoadingColumn = false;
  String? _columnError;
  
  // 학습 카드 관련
  List<LearningCard> _learningCards = [];
  bool _isLoadingLearningCards = false;
  String? _learningCardsError;
  
  // 포트폴리오 포지션 관련
  List<PortfolioPosition> _positions = [];
  bool _isLoadingPositions = false;

  @override
  void initState() {
    super.initState();
    // 비동기 작업을 안전하게 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocaleAndSetDate();
      _loadUserData();
      _loadColumn();
      _loadLearningCards();
      _loadPortfolioPositions();
      _printTokens();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // 로케일 초기화 및 현재 날짜 설정
  Future<void> _initializeLocaleAndSetDate() async {
    try {
      await initializeDateFormatting('ko_KR', null);
      if (mounted) {
        _setCurrentDate();
      }
    } catch (e) {
      // 로케일 초기화 실패 시 기본 형식 사용
      if (mounted) {
        _setCurrentDateWithDefaultFormat();
      }
    }
  }

  // 현재 날짜 설정 (한국어 로케일)
  void _setCurrentDate() {
    if (!mounted) return;
    final now = DateTime.now();
    final formatter = DateFormat('M월 d일', 'ko_KR');
    setState(() {
      _currentDate = formatter.format(now);
    });
  }

  // 현재 날짜 설정 (기본 형식)
  void _setCurrentDateWithDefaultFormat() {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _currentDate = '${now.month}월 ${now.day}일';
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
      } else {
        setState(() {
          _userNickname = '';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _userNickname = '';
      });
    }
  }

  // 칼럼 추천 로드
  Future<void> _loadColumn() async {
    setState(() {
      _isLoadingColumn = true;
      _columnError = null;
    });

    try {
      // 사용자 포트폴리오 종목 가져오기
      debugPrint('📰 포트폴리오 종목 조회 시작...');
      final positions = await StockApiService.getPositions();
      final tickers = positions ?? <String>[];
      
      debugPrint('📰 포트폴리오 종목 조회 결과:');
      debugPrint('  - positions: $positions');
      debugPrint('  - tickers: $tickers');
      debugPrint('  - tickers.length: ${tickers.length}');
      
      if (tickers.isEmpty) {
        debugPrint('⚠️ 보유 종목이 없습니다. 인기 칼럼을 반환할 수 있습니다.');
      }
      
      // 상위 3개 종목만 사용 (API 권장사항)
      final topTickers = tickers.take(3).toList();
      
      debugPrint('📰 칼럼 추천 요청 시작:');
      debugPrint('  - 전체 보유 종목: $tickers');
      debugPrint('  - 사용할 종목 (상위 3개): $topTickers');
      debugPrint('  - 전송할 ticker 개수: ${topTickers.length}');
      
      final response = await AiApiService.recommendColumn(topTickers);
      
      debugPrint('📰 칼럼 추천 응답:');
      debugPrint('  - success: ${response.success}');
      debugPrint('  - source: ${response.source}');
      debugPrint('  - message: ${response.message}');
      debugPrint('  - ticker: ${response.column.ticker}');
      debugPrint('  - title: ${response.column.title}');
      debugPrint('  - subtitle: ${response.column.subtitle}');
      
      if (mounted) {
        setState(() {
          _columnResponse = response;
          _isLoadingColumn = false;
        });
      }
    } on ApiException catch (e) {
      debugPrint('📰 칼럼 추천 에러: ${e.message}');
      if (mounted) {
        setState(() {
          _columnError = e.message;
          _isLoadingColumn = false;
        });
      }
    } catch (e) {
      debugPrint('📰 칼럼 추천 예외: $e');
      if (mounted) {
        setState(() {
          _columnError = '칼럼을 불러오는 중 오류가 발생했습니다.';
          _isLoadingColumn = false;
        });
      }
    }
  }

  // 학습 카드 로드
  Future<void> _loadLearningCards() async {
    setState(() {
      _isLoadingLearningCards = true;
      _learningCardsError = null;
    });

    try {
      debugPrint('📚 학습 카드 목록 조회 시작...');
      
      // 리포트에서 추천하는 학습 카드 ID 가져오기
      // 최근 거래 사이클 조회
      List<int> recommendedCardIds = [];
      
      try {
        final cyclesResponse = await OrderApiService.getTradeCycles(page: 0, size: 1);
        debugPrint('📚 거래 사이클 조회 결과: ${cyclesResponse != null ? "성공" : "실패"}');
        
        if (cyclesResponse != null && cyclesResponse.content.isNotEmpty) {
          final latestCycle = cyclesResponse.content.first;
          debugPrint('📚 최근 거래 사이클 ID: ${latestCycle.tradeCycleId}');
          
          final report = await ReportApiService.getTradeReport(latestCycle.tradeCycleId);
          debugPrint('📚 리포트 조회 결과: ${report != null ? "성공" : "실패"}');
          
          if (report != null && report.learningCards.isNotEmpty) {
            recommendedCardIds = report.learningCards.map((c) => c.id).toList();
            debugPrint('📚 리포트에서 추천 카드 ID 가져옴: $recommendedCardIds');
          } else {
            debugPrint('📚 리포트에 학습 카드가 없음');
          }
        } else {
          debugPrint('📚 거래 사이클이 없음');
        }
      } catch (e) {
        debugPrint('📚 거래 사이클/리포트 조회 중 에러: $e');
      }
      
      // 리포트에서 추천 카드가 없으면 기본 추천 카드 ID 사용 (9, 11, 17)
      if (recommendedCardIds.isEmpty) {
        recommendedCardIds = [9, 11, 17];
        debugPrint('📚 기본 추천 카드 ID 사용: $recommendedCardIds');
      }
      
      // 전체 카드 목록 조회
      final response = await LearningCardApiService.getLearningCards();

      if (mounted) {
        if (response != null && response.isNotEmpty) {
          debugPrint('📚 학습 카드 목록 조회 성공: ${response.length}개');
          
          // 리포트에서 추천하는 카드 ID로 필터링
          final filteredCards = response.where((card) {
            return recommendedCardIds.contains(card.id);
          }).toList();
          
          debugPrint('📚 필터링 후 카드 수: ${filteredCards.length}개');
          
          if (filteredCards.isEmpty) {
            debugPrint('📚 필터링된 카드가 없습니다. 전체 카드 목록을 확인하세요.');
            setState(() {
              _learningCardsError = '학습 카드를 불러올 수 없습니다.';
              _isLoadingLearningCards = false;
            });
            return;
          }
          
          // 추천 카드 ID 순서대로 정렬
          filteredCards.sort((a, b) {
            final indexA = recommendedCardIds.indexOf(a.id);
            final indexB = recommendedCardIds.indexOf(b.id);
            if (indexA == -1) return 1;
            if (indexB == -1) return -1;
            return indexA.compareTo(indexB);
          });
          
          final finalCards = filteredCards.take(2).toList();
          debugPrint('📚 최종 표시할 카드: ${finalCards.map((c) => 'ID=${c.id}, 제목=${c.title}').join(", ")}');
          
          setState(() {
            _learningCards = finalCards;
            _isLoadingLearningCards = false;
          });
        } else {
          // API가 404를 반환하거나 응답이 없는 경우 임시 데이터 사용
          debugPrint('📚 학습 카드 목록 조회 실패: response=$response');
          debugPrint('📚 임시 데이터로 대체합니다.');
          
          // 임시 하드코딩된 데이터 (백엔드가 준비되지 않았을 때 사용)
          final tempCards = <LearningCard>[
            LearningCard(
              id: 1,
              title: '왜 투자가 필요한가: 저금리 시대의 돈 가치 이해하기',
              description: '예·적금만으로는 부족한 이유와 투자가 필요한 배경을 짚어보는 입문 가이드',
              contents: [],
              category: '투자기초',
              level: 1,
              keywords: ['금융상품이해', '물가상승', '복리'],
              imageUrls: [],
            ),
            LearningCard(
              id: 16,
              title: '투자 비율 설계: 생활비·비상자금·투자금의 경계 정하기',
              description: '생활비, 비상자금, 투자금의 적절한 비율을 설계하는 방법',
              contents: [],
              category: '투자기초',
              level: 1,
              keywords: ['자산배분', '비상자금', '투자비율'],
              imageUrls: [],
            ),
          ];
          
          setState(() {
            _learningCards = tempCards;
            _isLoadingLearningCards = false;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('📚 학습 카드 목록 조회 예외: $e');
      debugPrint('📚 스택 트레이스: $stackTrace');
      
      // 예외 발생 시에도 임시 데이터 사용
      debugPrint('📚 예외 발생으로 임시 데이터로 대체합니다.');
      final tempCards = <LearningCard>[
        LearningCard(
          id: 1,
          title: '왜 투자가 필요한가: 저금리 시대의 돈 가치 이해하기',
          description: '예·적금만으로는 부족한 이유와 투자가 필요한 배경을 짚어보는 입문 가이드',
          contents: [],
          category: '투자기초',
          level: 1,
          keywords: ['금융상품이해', '물가상승', '복리'],
          imageUrls: [],
        ),
        LearningCard(
          id: 16,
          title: '투자 비율 설계: 생활비·비상자금·투자금의 경계 정하기',
          description: '생활비, 비상자금, 투자금의 적절한 비율을 설계하는 방법',
          contents: [],
          category: '투자기초',
          level: 1,
          keywords: ['자산배분', '비상자금', '투자비율'],
          imageUrls: [],
        ),
      ];
      
      if (mounted) {
        setState(() {
          _learningCards = tempCards;
          _isLoadingLearningCards = false;
        });
      }
    }
  }

  // 포트폴리오 포지션 로드
  Future<void> _loadPortfolioPositions() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingPositions = true;
    });

    try {
      final response = await PortfolioApiService.getPositions(
        page: 0,
        size: 10,
      );

      if (!mounted) return;
      
      if (response != null) {
        setState(() {
          _positions = response.content;
          _isLoadingPositions = false;
        });
      } else {
        setState(() {
          _isLoadingPositions = false;
        });
      }
    } catch (e) {
      debugPrint('포트폴리오 포지션 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingPositions = false;
        });
      }
    }
  }

  // 토큰 정보 출력
  Future<void> _printTokens() async {
    debugPrint('=== 토큰 정보 ===');
    
    // 백엔드 액세스 토큰
    final backendToken = await TokenService.getAccessToken();
    if (backendToken != null) {
      debugPrint('🔑 백엔드 액세스 토큰: $backendToken');
    } else {
      debugPrint('❌ 백엔드 액세스 토큰: 없음');
    }
    
    // 카카오 액세스 토큰 (SDK에서 직접)
    try {
      final kakaoToken = await TokenManagerProvider.instance.manager.getToken();
      if (kakaoToken?.accessToken != null) {
        debugPrint('🔑 카카오 액세스 토큰: ${kakaoToken!.accessToken}');
      } else {
        debugPrint('❌ 카카오 액세스 토큰: 없음');
      }
    } catch (e) {
      debugPrint('❌ 카카오 액세스 토큰 조회 실패: $e');
    }
    
    // 저장된 카카오 토큰
    final storedKakaoToken = await TokenService.getKakaoAccessToken();
    if (storedKakaoToken != null) {
      debugPrint('🔑 저장된 카카오 토큰: $storedKakaoToken');
    } else {
      debugPrint('❌ 저장된 카카오 토큰: 없음');
    }
    
    debugPrint('================');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppHeader(
        titleWidget: SvgPicture.asset(
          'assets/icons/navigation/top-nav-QBIT-text-logo.svg',
          height: 28,
          fit: BoxFit.contain,
        ),
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
          children: [
            // 사용자를 위한 소식 섹션
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: context.h(12)),
                  // 상단 배너 (11월 16일, user nickname님을 위한 소식)
                  Container(
                    width: double.infinity,
                    height: context.h(48),
                    decoration: ShapeDecoration(
                      color: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          width: 0.50,
                          color: AppColors.gray150,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.w(16)),
                      child: Row(
                        children: [
                          Text(
                            '🗞️',
                            style: TextStyle(
                              fontSize: context.w(16),
                            ),
                          ),
                          SizedBox(width: context.w(8)),
                          Expanded(
                            child: Text(
                              _userNickname.isNotEmpty 
                                ? '$_currentDate, $_userNickname님을 위한 소식'
                                : '$_currentDate, 큐빗을 위한 소식',
                              style: AppFonts.b1Semibold.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: context.h(12)),
                  
                  // 칼럼 카드
                  if (_isLoadingColumn)
                    Container(
                      width: double.infinity,
                      height: context.h(203), // 137 + 66
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_columnError != null)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(context.w(16)),
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _columnError!,
                            style: AppFonts.b1Regular.copyWith(
                              color: AppColors.gray600,
                            ),
                          ),
                          SizedBox(height: context.h(8)),
                          TextButton(
                            onPressed: _loadColumn,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    )
                  else if (_columnResponse != null)
                    _buildColumnCard(_columnResponse!.column as models.Column),
                ],
              ),
            ),
            // 추천 이론 학습 섹션
            SizedBox(height: context.h(20)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: context.w(20), vertical: context.h(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더: 제목 + 더 학습하기 링크
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '추천 이론 학습',
                        style: AppFonts.t2Semibold.copyWith(
                          color: AppColors.gray900,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // TODO: 더 학습하기 화면으로 이동
                        },
                        child: Row(
                          children: [
                            Text(
                              '더 학습하기',
                              style: AppFonts.b2Regular.copyWith(
                                color: AppColors.gray600,
                              ),
                            ),
                            SizedBox(width: context.w(4)),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: AppColors.gray600,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.h(16)),
                  
                  // 학습 카드들 (2개 가로 배치)
                  if (_isLoadingLearningCards)
                    Container(
                      height: context.h(163),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_learningCardsError != null)
                    Container(
                      height: context.h(163),
                      padding: EdgeInsets.all(context.w(16)),
                      child: Center(
                        child: Text(
                          _learningCardsError!,
                          style: AppFonts.b2Regular.copyWith(
                            color: AppColors.gray600,
                          ),
                        ),
                      ),
                    )
                  else if (_learningCards.isEmpty)
                    Container(
                      height: context.h(163),
                      child: Center(
                        child: Text(
                          '학습 카드가 없습니다',
                          style: AppFonts.b2Regular.copyWith(
                            color: AppColors.gray600,
                          ),
                        ),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ..._learningCards.asMap().entries.map((entry) {
                            final index = entry.key;
                            final card = entry.value;
                            return Row(
                              children: [
                                _buildLearningCard(
                                  context,
                                  card: card,
                                  onTap: () {
                                    // 학습 카드 상세로 이동
                                    context.push('/learning-card/${card.id}', extra: card);
                                  },
                                ),
                                if (index < _learningCards.length - 1)
                                  SizedBox(width: context.w(16)),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // 내 종목 보기 섹션 (추천 이론 학습 아래)
            SizedBox(height: context.h(20)), // 뉴스 칼럼과 추천 이론 학습 사이 여백과 동일
            if (_isLoadingPositions)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: context.h(20)),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_positions.isNotEmpty)
              PortfolioPositionsWidget(
                positions: _positions,
                onViewAll: () {
                  // TODO: 전체 포트폴리오 상세 화면으로 이동
                  // context.push('/portfolio-detail');
                },
              ),
            // 하단 여백 추가
            SizedBox(height: context.h(100)),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnCard(models.Column column) {
    return GestureDetector(
      onTap: () {
        // 칼럼 상세 화면으로 이동
        context.pushNamed(
          'column-detail',
          pathParameters: {'ticker': column.ticker},
        );
      },
      child: Column(
        children: [
          // 이미지 (상단만 radius 12)
          if (column.imageUrl != null && column.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Image.network(
                column.imageUrl!,
                width: double.infinity,
                height: context.h(137),
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: context.h(137),
                    color: AppColors.gray100,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  width: double.infinity,
                  height: context.h(137),
                  color: AppColors.gray100,
                  child: Icon(
                    Icons.error_outline,
                    color: AppColors.gray400,
                    size: context.w(40),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: context.h(137),
              decoration: const BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Icon(
                Icons.image_not_supported,
                color: AppColors.gray400,
                size: context.w(40),
              ),
            ),
          
          // 하단 정보 (하단만 radius 10, 높이 66)
          Container(
            width: double.infinity,
            height: context.h(66),
            padding: EdgeInsets.symmetric(
              horizontal: context.w(16),
              vertical: context.h(12),
            ),
            decoration: ShapeDecoration(
              color: AppColors.gray50,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: 0.50,
                  color: AppColors.gray150,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 제목
                Text(
                  column.title,
                  style: AppFonts.b1Semibold.copyWith(
                    color: AppColors.gray900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: context.h(2)),
                // 부제 ∙ 심볼
                Text(
                  column.subtitle != null && column.subtitle!.isNotEmpty && column.ticker.isNotEmpty
                      ? '${column.subtitle} ∙ ${column.ticker}'
                      : column.subtitle != null && column.subtitle!.isNotEmpty
                          ? column.subtitle!
                          : column.ticker.isNotEmpty
                              ? column.ticker
                              : '',
                  style: AppFonts.b2Regular.copyWith(
                    color: AppColors.gray600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
