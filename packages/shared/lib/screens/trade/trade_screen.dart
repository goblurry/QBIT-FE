import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dio/dio.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';
import 'package:qbit_shared/widgets/common/common_widgets.dart';
import 'package:qbit_shared/widgets/common/app_header.dart';
import 'package:qbit_shared/widgets/common/button/filter_button.dart';
import 'package:qbit_shared/widgets/common/padding/horizontal_inset.dart';
import 'package:qbit_shared/utils/responsive_utils.dart';
import 'package:qbit_shared/screens/trade/alpaca_auth_screen.dart';
import 'package:qbit_shared/screens/trade/stock_search_screen.dart';
import 'package:qbit_services/auth/kakao_auth_service.dart';
import 'package:qbit_services/auth/alpaca_auth_service.dart';
import 'package:qbit_services/auth/auth_service.dart';
import 'package:qbit_services/api/stock_api_service.dart';
import 'package:qbit_services/models/stock_model.dart';
import 'package:qbit_shared/models/portfolio_history.dart';
import 'package:qbit_shared/widgets/trade/portfolio_chart_widget.dart';
import 'package:qbit_shared/widgets/trade/portfolio_overview_chart.dart';
import 'package:qbit_services/api/portfolio_api_service.dart';
import 'package:qbit_services/models/portfolio_overview_model.dart';
import 'package:qbit_services/models/portfolio_position_model.dart';
import 'package:qbit_services/models/asset_model.dart';
import 'package:qbit_shared/widgets/home/portfolio_positions_widget.dart';
import 'package:qbit_services/models/stock_ranking_model.dart';
import 'package:qbit_services/storage/token_service.dart';
import 'package:qbit_services/api/api_client.dart';
import 'package:intl/intl.dart';

class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key});

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  bool _isAlpacaConnected = true; // Alpaca 연동 상태 - 테스트용으로 true로 설정
  
  String _userNickname = ''; // 카카오 닉네임
  List<StockModel> _overseasIndices = []; // 해외 주요 지수 데이터
  AssetModel? _userAssets; // 보유자산 데이터
  List<StockRankingModel> _stockRanking = []; // 해외 종목 순위 데이터
  String _selectedSortBy = 'volume'; // 선택된 정렬 기준: volume, volatility, moving
  int? _selectedStockIndex; // 선택된 종목 인덱스
  bool _isStockRankingLoading = true; // 해외 종목 순위 로딩 상태
  int _overseasPage = 0; // 해외 지수 페이지 인덱스
  int _stockRankingPage = 0; // 해외 종목 순위 페이지 인덱스
  final PageController _indicesPageController = PageController(viewportFraction: 1.0);
  final PageController _stockRankingPageController = PageController(viewportFraction: 1.0);
  
  // 포트폴리오 오버뷰 관련
  PortfolioOverviewResponse? _portfolioOverview;
  double? _selectedEquity; // 터치된 시점의 자산 가치
  int? _selectedTimestamp; // 터치된 시점의 타임스탬프
  String _selectedPeriod = '1M'; // 선택된 기간: '1D', '1W', '1M'
  bool _isPortfolioLoading = false; // 포트폴리오 오버뷰 로딩 상태
  
  // 포트폴리오 포지션 관련
  List<PortfolioPosition> _positions = [];
  bool _isLoadingPositions = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    // Alpaca 연동 성공 콜백 설정
    AlpacaAuthScreen.onSuccess = () async {
      // Alpaca Allow 후 연결 완료 간주 
      if (mounted) {
        setState(() {
          _isAlpacaConnected = true;
        });
      }
      await _loadUserAssets(); // 연동 후 자산 데이터 다시 로드
      await Future.wait([
        _loadPortfolioOverview(), // 포트폴리오 오버뷰도 다시 로드
        _loadPortfolioPositions(), // 포트폴리오 포지션도 다시 로드
      ]);
    };
  }

  // 사용자 데이터 로드
  Future<void> _loadUserData() async {
    try {
      await _loadKakaoNickname();
      await _loadOverseasIndices();
      
      // 알파카 연결 상태 확인과 자산 데이터 로드를 병렬로 실행
      await Future.wait([
        _checkAlpacaConnectionStatus(),
        _loadUserAssets(),
      ]);
      
      // 포트폴리오 오버뷰 로드 (Alpaca 연결된 경우만)
      if (_isAlpacaConnected) {
        await Future.wait([
          _loadPortfolioOverview(),
          _loadPortfolioPositions(),
        ]);
      }
      
      await _loadStockRanking();
    } catch (e) {
      print('투자 화면 데이터 로드 중 에러: $e');
    }
  }

  // Alpaca 연결 상태 확인
  Future<void> _checkAlpacaConnectionStatus() async {
    try {
      print('=== 알파카 연결 상태 확인 시작 ===');
      
      // 먼저 로그인 상태 확인
      final isLoggedIn = await TokenService.isLoggedIn();
      print('로그인 상태: $isLoggedIn');
      
      if (!isLoggedIn) {
        print('로그인되지 않음 - 연결 상태를 false로 설정');
        if (mounted) {
          setState(() {
            _isAlpacaConnected = false;
          });
        }
        return;
      }
      
      // Alpaca 계정 정보로 연결 상태 확인
      print('Alpaca 계정 정보 조회 중...');
      final accountInfo = await StockApiService.getAlpacaAccount();
      print('계정 정보 조회 결과: ${accountInfo != null ? "성공" : "실패"}');
      
      if (mounted) {
        // 계정 정보가 있고 실제 데이터가 있을 때만 연결된 것으로 판단
        bool isConnected = accountInfo != null && 
                          accountInfo['portfolioValue'] != null && 
                          (double.tryParse(accountInfo['portfolioValue'].toString()) ?? 0) > 0;
        
        setState(() {
          _isAlpacaConnected = isConnected;
        });
        print('최종 연결 상태: $_isAlpacaConnected (계정정보: ${accountInfo != null}, 포트폴리오값: ${accountInfo?['portfolioValue']})');
      }
      
      print('=== 알파카 연결 상태 확인 완료 ===');
    } catch (error) {
      print('연결 상태 확인 중 에러: $error');
      if (mounted) {
        setState(() {
          _isAlpacaConnected = false;
        });
      }
    }
  }

  // 사용자 닉네임 가져오기 
  Future<void> _loadKakaoNickname() async {
    try {
      // 백엔드에서 사용자 정보 가져오기
      final userInfo = await AuthService.getCurrentUser();
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
      setState(() {
        _userNickname = '';
      });
    }
  }

  // 보유자산 데이터 가져오기
  Future<void> _loadUserAssets() async {
    try {
      print('=== 보유자산 데이터 로드 시작 ===');
      
      final assets = await StockApiService.getUserAssets();
      print('자산 데이터 조회 결과: ${assets != null ? "성공" : "실패"}');
      
      if (mounted) {
        setState(() {
          _userAssets = assets;
          // 실제 자산 데이터가 있을 때만 연결 상태를 true로 설정
          // (하드코딩된 데이터가 아닌 실제 API 응답)
          if (assets != null && assets.portfolioValue > 0) {
            _isAlpacaConnected = true;
            print('실제 자산 데이터 존재 - 연결 상태를 true로 설정');
          } else {
            _isAlpacaConnected = false;
            print('자산 데이터 없음 또는 0값 - 연결 상태를 false로 설정');
          }
        });
        print('자산 데이터 설정 완료, 현재 연결 상태: $_isAlpacaConnected');
      }
      
      print('=== 보유자산 데이터 로드 완료 ===');
    } catch (error) {
      print('자산 데이터 로드 중 에러: $error');
      // Alpaca 연결이 안 된 경우 null로 설정
      if (mounted) {
        setState(() {
          _userAssets = null;
          _isAlpacaConnected = false;
        });
      }
    }
  }

  // 포트폴리오 오버뷰 데이터 로드
  // TODO: 백엔드 수정 후 기간별 그래프 출력
  // 현재는 period 파라미터에 관계없이 동일한 데이터 범위를 반환하고 있음
  // 백엔드에서 period(1D, 1W, 1M)에 따라 실제 조회 기간이 반영되도록 수정 필요
  // TODO: 90초 캐싱 구현 (dio_cache_interceptor 등 활용 고려)
  Future<void> _loadPortfolioOverview() async {
    if (mounted) {
      setState(() {
        _isPortfolioLoading = true;
      });
    }
    
    try {
      print('포트폴리오 오버뷰 로드 시작 - period: $_selectedPeriod');
      final overview = await PortfolioApiService.getPortfolioOverview(period: _selectedPeriod);
      if (mounted && overview != null) {
        print('포트폴리오 오버뷰 조회 성공 - period: $_selectedPeriod, timeframe: ${overview.timeframe}, history 개수: ${overview.history.length}');
        if (overview.history.isNotEmpty) {
          print('첫 번째 데이터: timestamp=${overview.history.first.timestamp}, equity=${overview.history.first.equity}');
          print('마지막 데이터: timestamp=${overview.history.last.timestamp}, equity=${overview.history.last.equity}');
        }
        
        setState(() {
          _portfolioOverview = overview;
          _isPortfolioLoading = false;
          // 초기값: 가장 최근 데이터
          if (overview.history.isNotEmpty) {
            final latestPoint = overview.history.last;
            _selectedEquity = latestPoint.equity;
            _selectedTimestamp = latestPoint.timestamp;
          }
        });
      } else {
        print('포트폴리오 오버뷰 조회 실패 - overview가 null (기존 데이터 유지)');
        if (mounted) {
          setState(() {
            _isPortfolioLoading = false;
          });
        }
        // 에러 발생 시 기존 데이터 유지 (null로 설정하지 않음)
      }
    } catch (e) {
      print('포트폴리오 오버뷰 로드 중 에러: $e (기존 데이터 유지)');
      if (mounted) {
        setState(() {
          _isPortfolioLoading = false;
        });
      }
      // 에러 발생 시 기존 데이터 유지
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
      print('포트폴리오 포지션 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingPositions = false;
        });
      }
    }
  }

  // 해외 종목 순위 데이터 가져오기
  Future<void> _loadStockRanking() async {
    if (mounted) {
      setState(() {
        _isStockRankingLoading = true;
        _stockRankingPage = 0; // 필터 변경 시 첫 페이지로 리셋
      });
    }
    
    try {
      final ranking = await StockApiService.getOverseasStockRanking(sortBy: _selectedSortBy)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('해외 종목 순위 조회 타임아웃: $_selectedSortBy');
              return null;
            },
          );
      
      if (mounted) {
        setState(() {
          _stockRanking = ranking ?? [];
          _isStockRankingLoading = false;
        });
        // 첫 페이지로 스크롤
        if (_stockRankingPageController.hasClients) {
          _stockRankingPageController.jumpToPage(0);
        }
      }
    } catch (error) {
      print('해외 종목 순위 조회 실패: $error');
      if (mounted) {
        setState(() {
          _stockRanking = [];
          _isStockRankingLoading = false;
        });
      }
    }
  }

  // 해외 주요 지수 데이터 가져오기
  Future<void> _loadOverseasIndices() async {
    try {
      final indices = await StockApiService.getOverseasIndices();
      
      if (indices != null && indices.isNotEmpty) {
        final List<StockModel> merged = List<StockModel>.from(indices);
        final Set<String> existing = merged.map((e) => e.symbol.toUpperCase()).toSet();

        // 대표 지수 심볼 후보들
        const List<String> preferredSymbols = ['SPX', 'GSPC', 'IXIC', 'DJI', 'RUT'];

        // 필요시 상세 호출로 보강
        if (merged.length < 4) {
          final futures = <Future<StockModel?>>[];
          for (final sym in preferredSymbols) {
            if (!existing.contains(sym)) {
              futures.add(StockApiService.getIndexDetail(sym));
            }
          }
          final results = await Future.wait(futures);
          for (final item in results) {
            if (item != null) {
              merged.add(item);
            }
          }
        }

        setState(() {
          _overseasIndices = merged;
        });
      } else {
        if (mounted) {
          setState(() => _overseasIndices = []);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _overseasIndices = []);
      }
    }
  }

  // 수익률 계산 (Infinity 방지)
  String _calculateReturnPercentage() {
    final equity = _userAssets?.equity ?? 100500;
    final lastEquity = _userAssets?.lastEquity ?? 100000;
    
    // lastEquity가 0이거나 매우 작으면 수익률을 0으로 처리
    if (lastEquity <= 0) {
      return '0.0';
    }
    
    final changeAmount = equity - lastEquity;
    final changePercentage = (changeAmount / lastEquity) * 100;
    
    // Infinity나 NaN 체크
    if (changePercentage.isInfinite || changePercentage.isNaN) {
      return '0.0';
    }
    
    // 매우 큰 값이나 작은 값 체크 (예: ±1000% 이상)
    if (changePercentage.abs() > 1000) {
      return changeAmount > 0 ? '+999.9' : '-999.9';
    }
    
    final sign = changeAmount > 0 ? '+' : '';
    return '$sign${changePercentage.toStringAsFixed(1)}';
  }

  // 계좌 연결하기 버튼 클릭
  void _onConnectAccount() {
    // 연동 성공 콜백 설정
    AlpacaAuthScreen.onSuccess = () {
        setState(() {
        _isAlpacaConnected = true;
      });
    };
    
    // Alpaca 동의 화면으로 이동
    context.push('/alpaca-auth');
  }


  // 계좌 정보 위젯 (연동 상태에 따라 블러 처리)
  Widget _buildAccountSection() {
    return Stack(
                  children: [
        // 기본 계좌 정보
        Inset.text(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
              children: [
                        if (_userNickname.isNotEmpty) ...[
                          TextSpan(
                            text: _userNickname,
                            style: AppFonts.b1Semibold.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: '님의 보유자산',
                            style: AppFonts.b1Semibold.copyWith(
                              color: AppColors.gray900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else ...[
                          TextSpan(
                            text: '보유자산',
                        style: AppFonts.b1Semibold.copyWith(
                              color: AppColors.gray900,
                              fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      context.push('/order-history');
                    },
                    child: Text(
                      '상세보기',
                      style: AppFonts.b2Regular.copyWith(color: AppColors.gray600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
        
        // 블러 오버레이 제거 (테스트용)
        if (false) // 항상 false로 설정하여 블러 오버레이 비활성화
          Positioned(
            left: 20,
            top: 16,
            right: 20,
            bottom: 16,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance,
                          size: 48,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Alpaca 계좌를 연동해주세요',
                          style: AppFonts.t2Bold.copyWith(
                            color: AppColors.gray900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '실시간 거래 정보를 확인하세요',
                          style: AppFonts.b1Regular.copyWith(
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _onConnectAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '계좌 연동하기',
                            style: AppFonts.t2Bold.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }


  // 검색바 섹션
  Widget _buildSearchSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Inset.block(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StockSearchScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: double.infinity, 
              height: 48,
              padding: const EdgeInsets.all(2),
              decoration: ShapeDecoration(
                color: Colors.white, 
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: 1,
                    color: AppColors.gray300, 
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(left: 12, right: 4),
                    child: Icon(
                      Icons.search,
                      color: AppColors.gray600,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '종목을 입력하세요',
                      style: AppFonts.b1Regular.copyWith(
                        color: AppColors.gray600, 
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 보유자산 섹션
  Widget _buildAssetSection() {
    print('=== 보유자산 섹션 빌드 ===');
    print('현재 연결 상태: $_isAlpacaConnected');
    
    if (_isAlpacaConnected) {
      print('연결된 상태 - 실제 자산 정보 표시');
      // Alpaca 기반 실제 자산 표시
      return Container(
        width: double.infinity,
        // 검색창과 보유자산 타이틀 사이 간격 
        margin: EdgeInsets.only(top: context.h(16), bottom: context.h(9)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Inset.text(
              child: Container(
                width: double.infinity,
                // height: 64, 
                // 금액 → 카드 상단 간격 
                margin: EdgeInsets.only(bottom: context.h(6)),
                clipBehavior: Clip.none,
                decoration: BoxDecoration(),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 60,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            width: 172,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 2,
                              children: [
                                SizedBox(
                                  width: 172,
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: _userNickname.isNotEmpty ? _userNickname : '큐빗',
                                          style: AppFonts.b1Semibold.copyWith(color: AppColors.primary),
                                        ),
                                        TextSpan(
                                          text: '님의 보유자산',
                                          style: AppFonts.b1Regular.copyWith(color: AppColors.gray900),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: context.h(4)),
                                SizedBox(
                                  width: 172,
                                  child: Text(
                                    _selectedEquity != null
                                        ? '\$ ${_selectedEquity!.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                                        : (_userAssets != null 
                                            ? '\$ ${_userAssets!.portfolioValue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                                            : '\$ --,---,---'),
                                    style: AppFonts.t2Bold.copyWith(color: AppColors.gray900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 주문내역 상세 (오른쪽 상단)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                print('주문내역 상세 클릭됨!');
                                context.push('/order-history');
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Text(
                                '주문내역 상세 ',
                                textAlign: TextAlign.right,
                                style: AppFonts.c2.copyWith(
                                  color: AppColors.gray400,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 기간 선택 버튼 (오른쪽 하단)
                        Positioned(
                          right: 0,
                          top: 28,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPeriodButton('1D', '1D'),
                              SizedBox(width: context.w(4)),
                              _buildPeriodButton('1W', '1W'),
                              SizedBox(width: context.w(4)),
                              _buildPeriodButton('1M', '1M'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ),
            ),
            Inset.block(
              child: _isPortfolioLoading
                  ? Container(
                      height: 125,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.gray300, width: 1),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : _portfolioOverview != null && _portfolioOverview!.history.isNotEmpty
                      ? PortfolioOverviewChart(
                          key: ValueKey('${_selectedPeriod}_${_portfolioOverview!.history.length}_${_portfolioOverview!.history.first.timestamp}_${_portfolioOverview!.history.last.timestamp}'), // period, 데이터 개수, 첫/마지막 timestamp로 key 생성
                          history: _portfolioOverview!.history,
                          selectedEquity: _selectedEquity,
                          selectedTimestamp: _selectedTimestamp,
                          onTouch: (equity, timestamp) {
                            setState(() {
                              _selectedEquity = equity;
                              _selectedTimestamp = timestamp;
                            });
                          },
                        )
                      : Container(
                          height: 125,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.gray300, width: 1),
                          ),
                        ),
            ),
          ],
        ),
      );
    } else {
      print('연결되지 않은 상태 - 블러 처리된 자산 정보 표시');
      // Alpaca 연동 전 - 실제 자산 정보 위에 블러 오버레이
      return Stack(
        children: [
          // 실제 자산 정보 (연동 후와 동일한 구조)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8, bottom: 9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Inset.text(
                  child: Container(
                    width: double.infinity,
                    height: 68,
                    margin: EdgeInsets.only(bottom: context.h(9)),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(),
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 352,
                        height: 50,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              child: Container(
                                width: 172,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 172,
                                      child: Text(
                                        '보유자산',
                                        style: AppFonts.b1Semibold.copyWith(color: AppColors.gray900),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 172,
                                      child: Text(
                                        '\$ --,---,---',
                                        style: AppFonts.t2Bold.copyWith(color: AppColors.gray600),
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
                ),
                Inset.block(
                  child: Container(
                    width: double.infinity,
                    height: 125,
                  decoration: ShapeDecoration(
                    color: Colors.white /* Gray-0 */,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: AppColors.gray300, /* Gray-300 */
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // 차트 영역 플레이스홀더
                      Positioned(
                        left: 16,
                        top: 16,
                        right: 16,
                        bottom: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '차트 영역',
                              style: AppFonts.b2Regular.copyWith(color: AppColors.gray300),
                            ),
                          ),
                        ),
                      ),
                      // 수익률 표시 플레이스홀더
                      Positioned(
                        right: 16,
                        top: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: ShapeDecoration(
                            color: AppColors.surfaceVariant,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: Text(
                            '--%',
                            style: AppFonts.c2.copyWith(color: AppColors.gray300),
                          ),
                        ),
                      ),
                      // 기간 표시 플레이스홀더
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: Text(
                          '--/--',
                          style: AppFonts.c2.copyWith(color: AppColors.gray300),
                        ),
                      ),
                      // 원형 마커 플레이스홀더
                      Positioned(
                        left: 50,
                        bottom: 16,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: ShapeDecoration(
                            color: AppColors.gray300,
                            shape: OvalBorder(),
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
          // 블러 오버레이와 버튼
          Positioned(
            left: 16,
            top: 0,
            right: 16,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                  ),
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          context.push('/alpaca-auth');
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 103,
                          height: 35,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: ShapeDecoration(
                            color: AppColors.gray900,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 79,
                                child: Text(
                                '계좌 연결하기',
                                  textAlign: TextAlign.center,
                                  style: AppFonts.b2Semibold.copyWith(color: AppColors.white),
                ),
              ),
            ],
                          ),
          ),
        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
    }
  }

  // 주문내역 링크 위젯
  Widget _buildOrderHistoryLink() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          print('주문내역 링크 클릭됨!');
          context.push('/order-history');
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          margin: EdgeInsets.only(top: context.h(16), bottom: context.h(16)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '주문내역',
            style: AppFonts.c2.copyWith(
              color: AppColors.gray400,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }

  // 해외 종목 순위 섹션
  Widget _buildStockRankingSection() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Container(
            margin: EdgeInsets.only(top: 0, bottom: context.h(13)),
            child: Inset.text(
              child: Text(
                '해외 종목 순위',
                style: AppFonts.t2Bold.copyWith(color: AppColors.gray900),
              ),
            ),
          ),
          // 정렬 버튼들
          Inset.block(
            child: FilterButtonGroup(
            labels: ['거래량순', '등락폭순', '상승률순'],
            values: ['volume', 'volatility', 'moving'],
            initialValue: _selectedSortBy,
            onChanged: (value) {
              setState(() {
                _selectedSortBy = value;
              });
              _loadStockRanking();
            },
            // 필터와 종목 순위 리스트 사이 간격을 조금 더 촘촘하게
            groupPadding: EdgeInsets.only(top: context.h(0), bottom: context.h(6)),
            ),
          ),
          // 종목 순위 리스트 (5개씩 4페이지)
          if (_isStockRankingLoading) ...[
            // 로딩 중
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (_stockRanking.isNotEmpty) ...[
            SizedBox(
              height: 56 * 5, // 5개 아이템 높이
              child: PageView.builder(
                controller: _stockRankingPageController,
                onPageChanged: (i) => setState(() => _stockRankingPage = i),
                itemCount: 4, // 5개씩 4페이지 (총 20개)
                itemBuilder: (context, page) {
                  final startIndex = page * 5;
                  final endIndex = (startIndex + 5).clamp(0, _stockRanking.length);
                  final pageStocks = _stockRanking.sublist(startIndex, endIndex);
                  
                  return Column(
                    children: pageStocks.map((stock) => Inset.block(
                      child: _buildStockRankingItem(stock),
                    )).toList(),
                  );
                },
              ),
            ),
            // 페이지 인디케이터
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < 4; i++) ...[
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i == _stockRankingPage ? AppColors.gray600 : AppColors.gray100,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            // 데이터 없음
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '종목 순위 데이터가 없습니다',
                  style: AppFonts.b1Regular.copyWith(
                    color: AppColors.gray600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  // 종목 순위 아이템 위젯
  Widget _buildStockRankingItem(StockRankingModel stock) {
    final index = _stockRanking.indexOf(stock);
    final isSelected = _selectedStockIndex == index;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 종목 상세 페이지로 이동
          context.push('/stock-detail/${stock.symbol}?name=${Uri.encodeComponent(stock.name)}&assetClass=us_equity');
        },
        child: Container(
          margin: EdgeInsets.zero,
          height: 56,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.background : AppColors.white,
            border: const Border(
              bottom: BorderSide(
                width: 1,
                color: AppColors.gray100, // 아래쪽 divider만
              ),
            ),
          ),
          child: Row(
            children: [
              // 순위
              SizedBox(
                width: 24,
                child: Text(
                  stock.rank.toString(),
                  textAlign: TextAlign.center,
                  style: AppFonts.b2Regular.copyWith(color: AppColors.gray600),
                ),
              ),
              const SizedBox(width: 10),
              // 종목명
              Expanded(
                flex: 2,
                child: Text(
                  stock.name,
                  style: AppFonts.b1Regular.copyWith(
                    color: AppColors.gray900,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 가격
              SizedBox(
                width: 80,
                child: Text(
                  '\$${stock.price.toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                  style: AppFonts.b1Regular.copyWith(color: AppColors.gray900),
                ),
              ),
              // 변동률
              SizedBox(
                width: 80,
                child: Text(
                  '${stock.changePercentage >= 0 ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                  textAlign: TextAlign.center,
                  style: AppFonts.b1Regular.copyWith(
                    color: AppColors.loss, // 등락 텍스트는 항상 빨간색
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 주식 검색 처리
  void _searchStock(String symbol) {
    if (symbol.isNotEmpty) {
      // 검색 결과 페이지로 이동
      context.push('/stock/${symbol.toUpperCase()}');
    }
  }

  // 해외 주요 지수 섹션
  Widget _buildOverseasIndicesSection() {
    final items = _overseasIndices;
    // pageCount를 int로 명시적으로 캐스팅 (clamp가 num을 반환하므로)
    final int rawPageCount = (items.length / 2).ceil();
    final int pageCount = rawPageCount.clamp(1, 10) as int;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Inset.text(
            child: Text(
              '해외 주요 지수',
              style: AppFonts.t2Bold.copyWith(color: AppColors.gray900),
            ),
          ),
          SizedBox(height: context.h(12)),
          if (items.isNotEmpty) ...[
            SizedBox(
              height: 109,
              child: PageView.builder(
                controller: _indicesPageController,
                onPageChanged: (i) => setState(() => _overseasPage = i),
                itemCount: pageCount,
                itemBuilder: (context, page) {
                  final leftIndex = page * 2;
                  final rightIndex = leftIndex + 1;
                  return Inset.text(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double gap = 9;
                        final double cardWidth = (constraints.maxWidth - gap) / 2;
                        return Row(
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _buildIndexItem(
                                items[leftIndex].name,
                                _formatPrice(items[leftIndex].currentPrice),
                                _formatChange(items[leftIndex].changeAmount, items[leftIndex].changePercentage),
                                items[leftIndex].isPositive,
                              ),
                            ),
                            SizedBox(width: gap),
                            if (rightIndex < items.length)
                              SizedBox(
                                width: cardWidth,
                                child: _buildIndexItem(
                                  items[rightIndex].name,
                                  _formatPrice(items[rightIndex].currentPrice),
                                  _formatChange(items[rightIndex].changeAmount, items[rightIndex].changePercentage),
                                  items[rightIndex].isPositive,
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            // 인디케이터
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < pageCount; i++) ...[
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i == _overseasPage ? AppColors.gray600 : AppColors.gray100,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 가격 포맷팅
  String _formatPrice(dynamic price) {
    if (price is num) {
      return price.toStringAsFixed(2);
    }
    if (price is String) {
      final parsed = double.tryParse(price);
      if (parsed != null) {
        return parsed.toStringAsFixed(2);
      }
    }
    return '0.00';
  }

  // 변동률 포맷팅
  String _formatChange(dynamic change, dynamic changePercent) {
    final changeNum = change is num ? change : 0.0;
    final percentNum = changePercent is num ? changePercent : 0.0;
    
    final sign = changeNum >= 0 ? '+' : '';
    return '$sign${changeNum.toStringAsFixed(2)} (${percentNum.toStringAsFixed(2)}%)';
  }

  // 지수 이름을 표시용으로 변환
  String _getDisplayName(String name) {
    if (name.contains('나스닥') || name.contains('NASDAQ')) {
      return 'NASDAQ';
    } else if (name.contains('S&P') || name.contains('SPX')) {
      return 'S&P 500';
    }
    return name;
  }

  // 타임스탬프 포맷팅 (예: "11월 15일, 오후 07:59")
  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final month = date.month;
    final day = date.day;
    return '$month월 $day일';
  }

  // 기간 선택 버튼 (작고 미묘하게)
  Widget _buildPeriodButton(String period, String label) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        if (_selectedPeriod == period) return; // 이미 선택된 기간이면 무시
        print('기간 선택 버튼 클릭: $period');
        setState(() {
          _selectedPeriod = period;
          // 에러 발생 시 기존 데이터를 유지하기 위해 null로 초기화하지 않음
        });
        _loadPortfolioOverview();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.w(8),
          vertical: context.h(4),
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gray100 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: AppFonts.c2.copyWith(
            color: isSelected ? AppColors.gray900 : AppColors.gray400,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // 지수 아이템 위젯
  Widget _buildIndexItem(String name, String value, String change, bool isPositive) {
    return Container(
      height: 109,
      padding: const EdgeInsets.all(14), 
      decoration: BoxDecoration(
        color: AppColors.secondaryBG,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondaryMain, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/america.png',
                width: 16,
                height: 16,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.flag,
                      size: 10,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _getDisplayName(name),
                                  style: AppFonts.b2Regular.copyWith(color: AppColors.gray900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // gap: 0.625rem
          Text(
            value,
            style: AppFonts.t2Bold.copyWith(
              color: AppColors.gray900,
              fontWeight: FontWeight.w700,
              height: 1.20,
            ),
          ),
          const SizedBox(height: 8), 
          Row(
            children: [
              Icon(
                isPositive ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 16,
                color: isPositive ? AppColors.profit : AppColors.loss,
              ),
              Text(
                change,
                style: AppFonts.b2Regular.copyWith(
                  color: isPositive ? AppColors.profit : AppColors.loss, // Chart-Red : Blue
                  height: 1.71,
                ),
              ),
            ],
          ),
          ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: '거래',
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
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 72 + 8, // 네비게이션 바 높이 + 패딩
        ),
        child: Column(
          children: [
            // 검색바 섹션
            _buildSearchSection(),
            
            // 보유자산 섹션 (검색바 바로 아래)
            _buildAssetSection(),

            // 포트폴리오 포지션 섹션 (오버뷰 아래, 해외 주요 지수 위)
            if (_isAlpacaConnected)
              if (_isLoadingPositions)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: context.h(20)),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_positions.isNotEmpty) ...[
                SizedBox(height: context.h(16)),
                PortfolioPositionsWidget(
                  positions: _positions,
                  onViewAll: () {
                    // TODO: 전체 포트폴리오 상세 화면으로 이동
                    // context.push('/portfolio-detail');
                  },
                ),
                SizedBox(height: context.h(28)),
                Container(
                  width: double.infinity,
                  height: 8,
                  color: AppColors.gray30,
                ),
                SizedBox(height: context.h(28)),
              ],

            // 해외 주요 지수 섹션 (디바이더 아래)
            _buildOverseasIndicesSection(),
            
            const SizedBox(height: 20),
            
            // 해외 종목 순위 섹션
            _buildStockRankingSection(),
            
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _indicesPageController.dispose();
    _stockRankingPageController.dispose();
    super.dispose();
  }
}
