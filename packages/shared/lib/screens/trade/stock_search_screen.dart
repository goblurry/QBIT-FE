import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';
import 'package:qbit_services/api/stock_api_service.dart';
import 'package:qbit_services/models/stock_model.dart';
import 'package:qbit_shared/widgets/stock_search_screen/stock_search_item.dart';
import 'package:qbit_shared/widgets/common/header_back.dart';
import 'package:qbit_shared/widgets/common/button/filter_button.dart';

// 종목 검색 화면
class StockSearchScreen extends StatefulWidget {
  final String? symbol;
  
  const StockSearchScreen({super.key, this.symbol});

  @override
  State<StockSearchScreen> createState() => _StockSearchScreenState();
}

class _StockSearchScreenState extends State<StockSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<StockModel> _searchResults = [];
  bool _isLoading = false;
  String? _error;
  
  // 검색 필터 상태
  String _selectedFilter = 'all'; // 'all', 'us_equity', 'crypto'

  @override
  void initState() {
    super.initState();
    // URL 파라미터로 전달된 symbol이 있으면 검색 실행
    if (widget.symbol != null && widget.symbol!.isNotEmpty) {
      _searchController.text = widget.symbol!;
      _searchStocks(widget.symbol!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 검색 결과를 심볼명 관련도순으로 정렬
  List<StockModel> _sortBySymbolRelevance(List<StockModel> results, String query) {
    final queryUpper = query.toUpperCase();
    
    results.sort((a, b) {
      final aSymbol = a.symbol.toUpperCase();
      final bSymbol = b.symbol.toUpperCase();
      
      // 1. 심볼이 검색어와 정확히 일치
      final aExactMatch = aSymbol == queryUpper;
      final bExactMatch = bSymbol == queryUpper;
      if (aExactMatch && !bExactMatch) return -1;
      if (!aExactMatch && bExactMatch) return 1;
      if (aExactMatch && bExactMatch) return 0;
      
      // 2. 심볼이 검색어로 시작
      final aStartsWith = aSymbol.startsWith(queryUpper);
      final bStartsWith = bSymbol.startsWith(queryUpper);
      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;
      
      // 3. 심볼에 검색어 포함
      final aContains = aSymbol.contains(queryUpper);
      final bContains = bSymbol.contains(queryUpper);
      if (aContains && !bContains) return -1;
      if (!aContains && bContains) return 1;
      
      // 4. 알파벳 순
      return aSymbol.compareTo(bSymbol);
    });
    
    return results;
  }

  Future<void> _searchStocks(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 필터에 따라 assetClass 설정
      String? assetClass;
      if (_selectedFilter == 'us_equity') {
        assetClass = 'us_equity';
      } else if (_selectedFilter == 'crypto') {
        assetClass = 'crypto';
      }
      // 'all'인 경우 assetClass는 null (모든 자산 클래스 검색)
      
      final results = await StockApiService.searchStocks(query.trim(), assetClass: assetClass);
      if (mounted) {
        // 심볼명 관련도순으로 정렬
        final sortedResults = _sortBySymbolRelevance(results ?? [], query.trim());
        setState(() {
          _searchResults = sortedResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: '주식 검색',
        onBack: () => context.pop(),
      ),
      body: Column(
        children: [
        // 검색 입력 필드
        Container(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity, // 좌우 여백 끝까지 채움
            height: 48,
            padding: const EdgeInsets.all(2),
            decoration: ShapeDecoration(
              color: AppColors.gray50, 
              shape: RoundedRectangleBorder(
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
                    size: 24,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: AppFonts.b1Regular.copyWith(
                      color: AppColors.gray900, 
                      height: 1.40,
                      backgroundColor: Colors.transparent, 
                    ),
                    decoration: InputDecoration(
                      hintText: '종목을 입력하세요',
                      hintStyle: AppFonts.b1Regular.copyWith(
                        color: AppColors.gray600
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: true,
                      fillColor: Colors.transparent,
                      isDense: true,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      setState(() {});
                      if (value.length >= 2) {
                        _searchStocks(value);
                      } else {
                        setState(() {
                          _searchResults = [];
                          _error = null;
                        });
                      }
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(left: 4, right: 12),
                    padding: const EdgeInsets.all(5),
                    child: GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _error = null;
                        });
                      },
                      child: SvgPicture.asset(
                        'assets/icons/stock_search_screen/search-cancel.svg',
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // 필터 버튼들
        FilterButtonGroup(
          labels: ['전체', '주식', '암호화폐'],
          values: ['all', 'us_equity', 'crypto'],
          initialValue: _selectedFilter,
          scrollable: false, // 왼쪽 정렬
          onChanged: (value) {
            setState(() {
              _selectedFilter = value;
            });
            
            // 검색어가 있으면 다시 검색
            if (_searchController.text.isNotEmpty) {
              _searchStocks(_searchController.text);
            }
          },
        ),
          
          // 검색 결과
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('검색 중 오류가 발생했습니다: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _searchStocks(_searchController.text),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty 
              ? '종목명 또는 종목코드를 입력해주세요'
              : '검색 결과가 없습니다',
          style: AppFonts.b1Regular.copyWith(color: AppColors.gray600),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final stock = _searchResults[index];
        return _buildStockItem(stock);
      },
    );
  }

  Widget _buildStockItem(StockModel stock) {
    return StockSearchItem(
      stock: stock,
      searchQuery: _searchController.text,
    );
  }

}