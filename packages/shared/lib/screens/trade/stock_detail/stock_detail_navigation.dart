import 'package:flutter/material.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';
import 'package:qbit_shared/screens/trade/stock_detail/stock_chart_tab.dart';
import 'package:qbit_shared/screens/trade/stock_detail/stock_orderbook_tab.dart';
import 'package:qbit_shared/screens/trade/stock_detail/stock_order_tab.dart';
import 'package:qbit_shared/screens/trade/stock_detail/stock_market_tab.dart';
import 'package:qbit_shared/widgets/common/header_back.dart';

class StockDetailNavigation extends StatefulWidget {
  final String symbol;
  final String name;
  final String assetClass;
  final String? binanceSymbol;

  const StockDetailNavigation({
    super.key,
    required this.symbol,
    required this.name,
    required this.assetClass,
    this.binanceSymbol,
  });

  @override
  State<StockDetailNavigation> createState() => _StockDetailNavigationState();
}

class _StockDetailNavigationState extends State<StockDetailNavigation> {
  int _selectedTabIndex = 0; // 0: 차트, 1: 호가, 2: 주문, 3: 시세
  
  // 가격 정보 상태 (차트/호가에서 사용)
  String _currentPriceKRW = "0원";
  String _currentPriceUSD = r"$0";
  String _priceChange = "+0.00%";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildCustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _buildTabContent(),
          ),
          _buildBottomTabNavigation(),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0: // 차트
        return StockChartTab(
          symbol: widget.symbol,
          name: widget.name,
          assetClass: widget.assetClass,
          binanceSymbol: widget.binanceSymbol,
          onPriceUpdateDetailed: updatePriceInfoDetailed,
        );
      case 1: // 호가
        return StockOrderbookTab(
          symbol: widget.symbol,
          name: widget.name,
          assetClass: widget.assetClass,
          binanceSymbol: widget.binanceSymbol,
        );
      case 2: // 주문
        return StockOrderTab(
          symbol: widget.symbol,
          name: widget.name,
          assetClass: widget.assetClass,
          binanceSymbol: widget.assetClass == 'crypto' && (widget.binanceSymbol?.isNotEmpty ?? false)
              ? widget.binanceSymbol
              : null,
        );
      case 3: // 시세
        return StockMarketTab(
          symbol: widget.symbol,
          name: widget.name,
          assetClass: widget.assetClass,
          binanceSymbol: widget.assetClass == 'crypto' && (widget.binanceSymbol?.isNotEmpty ?? false)
              ? widget.binanceSymbol
              : null,
        );
      default:
        return StockChartTab(
          symbol: widget.symbol,
          name: widget.name,
          assetClass: widget.assetClass,
          binanceSymbol: widget.binanceSymbol,
        );
    }
  }

  Widget _buildBottomTabNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(72, 16, 72, 44),
      child: Container(
        width: 249,
        height: 49,
        decoration: ShapeDecoration(
          color: AppColors.gray600.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildTabItem('차트', 0),
            _buildTabItem('호가', 1),
            _buildTabItem('주문', 2),
            _buildTabItem('시세', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          title,
          style: AppFonts.b1Semibold.copyWith(
            color: isSelected ? AppColors.primary : Colors.white,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildCustomAppBar() {
    return AppHeader(
      title: widget.name,
      onBack: () => context.pop(),
    );
  }

  // 가격 정보 업데이트 메서드 (차트/호가에서 사용)
  void updatePriceInfo(String price, String change) {
    setState(() {
      if (price.endsWith('원')) {
        _currentPriceKRW = price;
      } else if (price.startsWith(r'$')) {
        _currentPriceUSD = price;
      }
      _priceChange = change;
    });
  }
  
  // 가격 정보 업데이트 메서드 (USD/KRW 분리)
  void updatePriceInfoDetailed(String priceUSD, String priceKRW) {
    setState(() {
      _currentPriceUSD = priceUSD;
      _currentPriceKRW = priceKRW;
    });
  }
}