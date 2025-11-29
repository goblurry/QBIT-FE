import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/header_back.dart';

class LearningCardDetailScreen extends StatefulWidget {
  final String cardType;
  final List<String>? extractedTags; // AI 리포트에서 추출된 태그들
  
  const LearningCardDetailScreen({
    super.key,
    required this.cardType,
    this.extractedTags,
  });

  @override
  State<LearningCardDetailScreen> createState() => _LearningCardDetailScreenState();
}

class _LearningCardDetailScreenState extends State<LearningCardDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  int _totalPages = 5;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7), // Gray-30
      appBar: AppHeader(
        title: '학습 카드',
        onBack: () => context.pop(),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // PageView for card content
            Positioned(
              left: 16,
              top: 80,
              child: Container(
                width: 360,
                height: 450,
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Color(0x1E000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                      spreadRadius: 0,
                    )
                  ],
                ),
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: _buildCardPages(),
                ),
              ),
            ),
            
            // 카테고리 태그
            Positioned(
              left: 16,
              top: 40,
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: ShapeDecoration(
                  color: const Color(0xFF04B99A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _getCategoryTag(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w400,
                        height: 1.23,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 페이지 인디케이터
            Positioned(
              left: 171,
              top: 550,
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: ShapeDecoration(
                  color: const Color(0xFFD1D5DB), // Gray-300
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${_currentPage + 1}/$_totalPages',
                      style: TextStyle(
                        color: const Color(0xFF323232), // Gray-900
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w400,
                        height: 1.23,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 카드 페이지들을 동적으로 생성
  List<Widget> _buildCardPages() {
    return [
      Image.asset(
        'assets/cards/title.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: Text(
                '이미지를 불러올 수 없습니다',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
      Image.asset(
        'assets/cards/1.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: Text(
                '이미지를 불러올 수 없습니다',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
      Image.asset(
        'assets/cards/2.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: Text(
                '이미지를 불러올 수 없습니다',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
      Image.asset(
        'assets/cards/3.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: Text(
                '이미지를 불러올 수 없습니다',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
      Image.asset(
        'assets/cards/4.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: Text(
                '이미지를 불러올 수 없습니다',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    ];
  }

  /// 카테고리 태그 반환
  String _getCategoryTag() {
    switch (widget.cardType) {
      case 'risk_management':
        return '#리스크관리';
      case 'investment_psychology':
        return '#투자심리';
      case 'technical_analysis':
        return '#기술적분석';
      case 'basic_strategy':
        return '#투자전략';
      case 'market_analysis':
        return '#시장분석';
      default:
        return '#학습';
    }
  }
}
