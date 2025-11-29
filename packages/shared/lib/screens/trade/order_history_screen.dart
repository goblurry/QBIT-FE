import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qbit_shared/widgets/common/header_back.dart';
import 'package:qbit_shared/widgets/common/button/filter_button.dart';
import 'package:qbit_shared/widgets/common/padding/horizontal_inset.dart';
import 'package:qbit_shared/screens/trade/stock_detail/stock_detail_navigation.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:qbit_services/api/order_api_service.dart';
import 'package:qbit_services/api/stock_api_service.dart';
import 'package:qbit_services/api/order_websocket_service.dart';
import 'package:qbit_services/models/order_update_message.dart';
import 'package:qbit_services/models/trade_cycle_response.dart';
import 'package:qbit_shared/widgets/order/order_history_item.dart';
import 'package:qbit_shared/widgets/order/trade_cycle_item.dart';
import 'package:qbit_shared/utils/responsive_utils.dart';

// OrderModel - API 응답 데이터 모델
class OrderModel {
  final int orderId;
  final String alpacaOrderId;
  final String symbol;
  final String side;
  final String quantity;
  final String filledQuantity;
  final String? filledAvgPrice;
  final String type;
  final String timeInForce;
  final String? limitPrice;
  final String? stopPrice;
  final String status;
  final String createdAt;
  final String submittedAt;
  final String? filledAt;
  final String? canceledAt;
  final String? replacedAt;
  final String? replacedBy;
  final String? replaces;

  OrderModel({
    required this.orderId,
    required this.alpacaOrderId,
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.filledQuantity,
    this.filledAvgPrice,
    required this.type,
    required this.timeInForce,
    this.limitPrice,
    this.stopPrice,
    required this.status,
    required this.createdAt,
    required this.submittedAt,
    this.filledAt,
    this.canceledAt,
    this.replacedAt,
    this.replacedBy,
    this.replaces,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      orderId: json['orderId'],
      alpacaOrderId: json['alpacaOrderId'],
      symbol: json['symbol'],
      side: json['side'],
      quantity: json['quantity'],
      filledQuantity: json['filledQuantity'],
      filledAvgPrice: json['filledAvgPrice'],
      type: json['type'],
      timeInForce: json['timeInForce'],
      limitPrice: json['limitPrice'],
      stopPrice: json['stopPrice'],
      status: json['status'],
      createdAt: json['createdAt'],
      submittedAt: json['submittedAt'],
      filledAt: json['filledAt'],
      canceledAt: json['canceledAt'],
      replacedAt: json['replacedAt'],
      replacedBy: json['replacedBy'],
      replaces: json['replaces'],
    );
  }
}

// 날짜 포맷팅 함수 (YY.MM.DD)
String _formatDate(String dateString) {
  try {
    final date = DateTime.parse(dateString);
    final yearShort = date.year.toString().substring(2);
    return '$yearShort.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  } catch (e) {
    return '--.--.--';
  }
}

// 상태 라벨 생성 함수
String _getStatusLabel(OrderModel order) {
  final status = (order.status ?? '').toLowerCase();
  final filledQuantity = double.tryParse(order.filledQuantity ?? '0') ?? 0.0;
  final quantity = double.tryParse(order.quantity ?? '0') ?? 0.0;
  
  // 취소된 경우
  if (status == 'canceled' || status == 'cancelled') {
    return '취소됨';
  }
  
  // 체결 수량 기반 판단
  if (filledQuantity > 0) {
    if (filledQuantity >= quantity) {
      // 완전 체결
      return order.side == 'buy' ? '매수 완료' : '매도 완료';
    } else {
      // 부분 체결
      return order.side == 'buy' ? '매수 부분체결' : '매도 부분체결';
    }
  }
  
  // 상태 기반 판단
  if (status == 'filled' || status == 'partially_filled') {
    if (status == 'partially_filled') {
      return order.side == 'buy' ? '매수 부분체결' : '매도 부분체결';
    } else {
      return order.side == 'buy' ? '매수 완료' : '매도 완료';
    }
  } else if (status == 'accepted' || status == 'pending_new' || status == 'new') {
    return order.type == 'limit' ? '지정가 대기' : '시장가 대기';
  } else {
    return '처리 중';
  }
}

Color _getStatusColor(OrderModel order) {
  final status = (order.status ?? '').toLowerCase();
  final filledQuantity = double.tryParse(order.filledQuantity ?? '0') ?? 0.0;
  final quantity = double.tryParse(order.quantity ?? '0') ?? 0.0;
  
  // 취소된 경우
  if (status == 'canceled' || status == 'cancelled') {
    return AppColors.gray600; // 진한 회색
  }
  
  // 체결 수량 기반 판단
  if (filledQuantity > 0) {
    // 완전 체결 또는 부분 체결 모두 매수/매도 색상 사용
    return order.side == 'buy' ? AppColors.profit : AppColors.loss;
  }
  
  // 상태 기반 판단
  if (status == 'filled' || status == 'partially_filled') {
    return order.side == 'buy' ? AppColors.profit : AppColors.loss;
  } else if (status == 'accepted' || status == 'pending_new' || status == 'new') {
    return AppColors.primary; // 기본 색상 (대기 중)
  } else {
    return AppColors.primary; // 기본 색상 (처리 중)
  }
}

// 심볼이 암호화폐인지 판단하는 함수
bool _isCryptoSymbol(String symbol) {
  // 일반적인 암호화폐 심볼 패턴들
  final cryptoPatterns = [
    'BTC', 'ETH', 'ADA', 'SOL', 'MATIC', 'AVAX', 'DOT', 'LINK', 'UNI', 'AAVE',
    'USDT', 'USDC', 'BUSD', 'DAI', 'WBTC', 'WETH', 'DOGE', 'SHIB', 'XRP', 'LTC'
  ];
  
  final upperSymbol = symbol.toUpperCase();
  
  // 심볼에서 암호화폐 패턴이 포함되어 있는지 확인
  // 단, 주식 심볼과 구분하기 위해 더 정확한 매칭 사용
  for (final pattern in cryptoPatterns) {
    if (upperSymbol.contains(pattern)) {
      // 추가 검증: 주식 심볼과 구분
      // 예: BTC/USD, ETH/USDT, BTCUSD 등은 암호화폐
      if (upperSymbol.contains('/') || upperSymbol.endsWith('USD') || upperSymbol.endsWith('USDT')) {
        return true;
      }
      // 단일 심볼인 경우 (BTC, ETH 등)
      if (upperSymbol == pattern) {
        return true;
      }
    }
  }
  
  return false;
}

// 수량과 가격 포맷팅 함수
String _formatQuantityAndPrice(OrderModel order) {
  final quantity = double.tryParse(order.quantity) ?? 0;
  final price = order.filledAvgPrice != null 
      ? double.tryParse(order.filledAvgPrice!) 
      : order.limitPrice != null 
          ? double.tryParse(order.limitPrice!) 
          : null;
  
  final isCrypto = _isCryptoSymbol(order.symbol);
  
  final quantityText = isCrypto 
      ? '${quantity.toStringAsFixed(9).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}개'
      : '${quantity.toStringAsFixed(2)}주';
  
  if (price != null) {
    final priceText = isCrypto 
        ? '\$${price.toStringAsFixed(2)}'
        : '\$${price.toStringAsFixed(2)}';
    return '$quantityText · $priceText';
  } else {
    return quantityText;
  }
}


class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  bool _isLoading = false;
  List<OrderModel> _orders = [];
  List<TradeCycleResponseDto> _cycleData = [];
  StreamSubscription? _wsSub;
  bool _wsConnected = false;
  
  // 탭 상태
  String _selectedTab = '개별'; // 개별, 사이클
  String _selectedFilter = '전체'; // 전체, 매수, 매도
  
  // 검색 관련 상태
  final TextEditingController _searchController = TextEditingController();
  String? _searchSymbol;
  Timer? _searchDebounce;
  bool _isSearchVisible = false;
  
  // 삭제 관련 상태
  int? _selectedOrderId;
  final Map<String, Uint8List?> _logoCache = {};
  final Map<String, Future<Uint8List?>> _logoRequestCache = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchOrders();
    _fetchTradeCycles();
    _connectWs();
  }
  
  void _onSearchChanged() {
    // 기존 타이머 취소
    _searchDebounce?.cancel();
    
    final symbol = _searchController.text.trim();
    if (symbol.isEmpty) {
      setState(() {
        _searchSymbol = null;
      });
      _fetchOrders();
    } else {
      // 디바운싱: 사용자가 입력을 멈춘 후 500ms 후에 검색
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          final currentSymbol = _searchController.text.trim();
          if (currentSymbol == symbol) {
            setState(() {
              _searchSymbol = symbol.toUpperCase();
            });
            _fetchOrders();
          }
        }
      });
    }
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    
    try {
      // side 필터 변환 (매수/매도 -> BUY/SELL)
      String? side;
      if (_selectedFilter == '매수') {
        side = 'BUY';
      } else if (_selectedFilter == '매도') {
        side = 'SELL';
      }
      
      final response = await OrderApiService.getOrderHistory(
        symbol: _searchSymbol,
        status: null,
        side: side,
      );
      
      if (mounted) {
        List<OrderModel> orders = response?['content']?.map<OrderModel>((json) => OrderModel.fromJson(json)).toList() ?? [];
        
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (error) {
      print('주문 내역 조회 실패: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 거래 사이클 데이터 로드
  Future<void> _fetchTradeCycles() async {
    print('💡💡💡 _fetchTradeCycles 호출됨');
    if (_selectedTab == '사이클') {
      setState(() => _isLoading = true);
    }
    
    try {
      print('💡 거래 사이클 조회 시작');
      final response = await OrderApiService.getTradeCycles(page: 0, size: 100);
      print('💡 API 응답 받음: ${response != null ? "성공" : "null"}');
      
      if (mounted && response != null) {
        print('💡 거래 사이클 응답 받음: ${response.content.length}개');
        if (response.content.isNotEmpty) {
          final first = response.content.first;
          print('💡 첫 번째 사이클: symbol=${first.symbol}, tradeCycleId=${first.tradeCycleId}');
          print('💡 손익률: ${first.profitLossRate}, 손익금액: ${first.profitLossAmount}');
          print('💡 시작일: ${first.startDate}, 종료일: ${first.endDate}');
        }
        setState(() {
          _cycleData = response.content
            ..sort((a, b) {
              // 종료일이 가장 최신인 순으로 정렬 (null인 경우 startDate 사용)
              final aEndDate = a.endDate ?? a.startDate;
              final bEndDate = b.endDate ?? b.startDate;
              return bEndDate.compareTo(aEndDate);
            });
          _isLoading = false;
        });
        print('💡 사이클 데이터 업데이트 완료: ${_cycleData.length}개');
        if (_cycleData.isNotEmpty) {
          print('💡 업데이트된 첫 번째 사이클: ${_cycleData.first.symbol}, 손익률: ${_cycleData.first.profitLossRate}');
        }
      } else {
        print('💡 거래 사이클 응답이 null입니다 (mounted: $mounted)');
        if (mounted) {
          setState(() {
            _cycleData = [];
            _isLoading = false;
          });
        }
      }
    } catch (error, stackTrace) {
      print('💡 거래 사이클 조회 실패: $error');
      print('💡 에러 타입: ${error.runtimeType}');
      print('💡 에러 스택: $stackTrace');
      if (mounted) {
        setState(() {
          _cycleData = [];
          _isLoading = false;
        });
      }
    }
  }

  void _connectWs() {
    // WebSocket 연결 및 실시간 주문 상태 업데이트 구독
    OrderWebSocketService.instance.connect();
    
    // 주문 업데이트 구독
    _wsSub = OrderWebSocketService.instance.orderUpdates.listen((orderUpdate) {
      if (mounted) {
        setState(() {
          _wsConnected = true;
        });
        
        // 주문 상태 업데이트 처리
        _handleOrderUpdate(orderUpdate);
        
        // 주문이 완료되면 사이클 데이터 다시 로드
        if (orderUpdate.status?.toUpperCase() == 'FILLED') {
          _fetchTradeCycles();
        }
      }
    }, onError: (error) {
      print('WebSocket 에러: $error');
      if (mounted) {
        setState(() {
          _wsConnected = false;
        });
      }
    });
  }

  // 실시간 주문 상태 업데이트 처리
  void _handleOrderUpdate(OrderUpdateMessage orderUpdate) {
    try {
      final alpacaOrderId = orderUpdate.alpacaOrderId;
      // 상태를 소문자로 정규화하여 일관성 유지
      final newStatus = orderUpdate.status?.toLowerCase();
      
      if (alpacaOrderId != null && newStatus != null) {
        // 기존 주문 목록에서 alpacaOrderId로 주문 찾기
        final orderIndex = _orders.indexWhere((order) => 
          order.alpacaOrderId == alpacaOrderId
        );
        
        if (orderIndex != -1) {
          final updatedOrder = OrderModel(
            orderId: _orders[orderIndex].orderId,
            alpacaOrderId: _orders[orderIndex].alpacaOrderId,
            symbol: _orders[orderIndex].symbol,
            side: _orders[orderIndex].side,
            quantity: _orders[orderIndex].quantity,
            filledQuantity: orderUpdate.filledQuantity?.toString() ?? _orders[orderIndex].filledQuantity,
            filledAvgPrice: orderUpdate.filledAvgPrice?.toString() ?? _orders[orderIndex].filledAvgPrice,
            type: _orders[orderIndex].type,
            timeInForce: _orders[orderIndex].timeInForce,
            limitPrice: _orders[orderIndex].limitPrice,
            stopPrice: _orders[orderIndex].stopPrice,
            status: newStatus,
            createdAt: _orders[orderIndex].createdAt,
            submittedAt: _orders[orderIndex].submittedAt,
            filledAt: orderUpdate.filledAt?.toIso8601String() ?? _orders[orderIndex].filledAt,
            canceledAt: _orders[orderIndex].canceledAt,
            replacedAt: _orders[orderIndex].replacedAt,
            replacedBy: _orders[orderIndex].replacedBy,
            replaces: _orders[orderIndex].replaces,
          );
          
          setState(() {
            _orders[orderIndex] = updatedOrder;
          });
          
          print('주문 ${alpacaOrderId} 상태 업데이트: ${_orders[orderIndex].status}');
        }
      }
    } catch (e) {
      print('주문 업데이트 처리 실패: $e');
    }
  }

  // 주문 삭제 메서드
  Future<void> _deleteOrder(int orderId) async {
    try {
      final success = await OrderApiService.cancelOrder(orderId.toString());
      
      if (success) {
        // 성공 시 로컬 목록에서도 제거
        setState(() {
          _orders.removeWhere((order) => order.orderId == orderId);
          _selectedOrderId = null;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('주문이 삭제되었습니다'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('주문 삭제에 실패했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (error) {
      print('주문 삭제 에러: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('주문 삭제 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 삭제 확인 다이얼로그
  void _showDeleteDialog(OrderModel order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('주문 삭제'),
          content: Text('${order.symbol} 주문을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _selectedOrderId = null;
                });
              },
              child: Text(
                '취소',
                style: TextStyle(color: AppColors.gray600),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteOrder(order.orderId);
              },
              child: Text(
                '삭제',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _wsSub?.cancel();
    // WebSocket 연결은 다른 화면에서도 사용할 수 있으므로 여기서는 구독만 취소
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: '주문 내역',
        onBack: () => context.pop(),
      ),
      body: Column(
        children: [
          // 탭 선택
          _buildTabSelector(),
          
          // WebSocket 연결 상태 표시
          if (_wsConnected)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.h(4)),
              color: AppColors.primary.withOpacity(0.1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: context.w(8),
                    height: context.h(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: context.w(8)),
                  Text(
                    '실시간 업데이트 중',
                    style: AppFonts.c2.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          
          // 필터 버튼 및 검색바
          _buildFilterButtons(),
          
          // 검색바 (검색 아이콘 클릭 시 표시)
          if (_isSearchVisible) _buildInlineSearchBar(),
          
          // 내용
          Expanded(
            child: _selectedTab == '개별' ? _buildOrderList() : _buildCycleList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: EdgeInsets.only(left: context.w(20), right: context.w(20), top: 0, bottom: context.h(12)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedTab = '개별'),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: context.h(8), horizontal: context.w(16)),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 1.3,
                    color: _selectedTab == '개별' ? AppColors.gray900 : Colors.transparent,
                  ),
                ),
              ),
              child: Text(
                '개별',
                style: TextStyle(
                  color: _selectedTab == '개별' ? AppColors.gray900 : AppColors.gray300,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  height: 1.31,
                ),
              ),
            ),
          ),
          SizedBox(width: context.w(17)),
          GestureDetector(
            onTap: () => setState(() => _selectedTab = '사이클'),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: context.h(8), horizontal: context.w(16)),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 1.3,
                    color: _selectedTab == '사이클' ? AppColors.gray900 : Colors.transparent,
                  ),
                ),
              ),
              child: Text(
                '사이클',
                style: TextStyle(
                  color: _selectedTab == '사이클' ? AppColors.gray900 : AppColors.gray300,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  height: 1.31,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.w(16)),
      margin: EdgeInsets.only(top: context.h(4), bottom: context.h(8)),
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
              child: TextField(
                controller: _searchController,
                style: AppFonts.b1Regular.copyWith(
                  color: AppColors.gray900,
                  height: 1.40,
                ),
                decoration: InputDecoration(
                  hintText: '종목 심볼 (예: AAPL)',
                  hintStyle: AppFonts.b1Regular.copyWith(
                    color: AppColors.gray600,
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
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, child) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () {
                    // _onSearchChanged 리스너에서 _searchSymbol 초기화 및 _fetchOrders 호출을 처리
                    _searchController.clear();
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(left: 4, right: 12),
                    child: Icon(
                      Icons.clear,
                      color: AppColors.gray600,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    if (_selectedTab != '개별') return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.w(16)),
      // 필터 탭과 리스트 간 상하 여백을 조금 더 촘촘하게 조정
      margin: EdgeInsets.only(top: context.h(4), bottom: context.h(4)),
      child: Row(
        children: [
          FilterButton(
            label: '전체',
            isSelected: _selectedFilter == '전체',
            onTap: () {
              setState(() => _selectedFilter = '전체');
              _fetchOrders();
            },
          ),
          SizedBox(width: context.w(8)),
          FilterButton(
            label: '매수',
            isSelected: _selectedFilter == '매수',
            onTap: () {
              setState(() => _selectedFilter = '매수');
              _fetchOrders();
            },
          ),
          SizedBox(width: context.w(8)),
          FilterButton(
            label: '매도',
            isSelected: _selectedFilter == '매도',
            onTap: () {
              setState(() => _selectedFilter = '매도');
              _fetchOrders();
            },
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  // 검색바 닫을 때 검색 초기화
                  _searchController.clear();
                  _searchSymbol = null;
                  _fetchOrders();
                }
              });
            },
            child: Icon(
              _isSearchVisible ? Icons.close : Icons.search,
              size: 24,
              color: AppColors.gray900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.w(16)),
      margin: EdgeInsets.only(top: context.h(8), bottom: context.h(8)),
      child: Container(
        width: double.infinity,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.gray200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: AppColors.gray600,
              size: 20,
            ),
            SizedBox(width: context.w(12)),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: AppFonts.b1Regular.copyWith(
                  color: AppColors.gray900,
                ),
                decoration: InputDecoration(
                  hintText: '종목 심볼 (예: AAPL)',
                  hintStyle: AppFonts.b1Regular.copyWith(
                    color: AppColors.gray400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, child) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchSymbol = null;
                    });
                    _fetchOrders();
                  },
                  child: Icon(
                    Icons.clear,
                    color: AppColors.gray600,
                    size: 20,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    // 이미 _fetchOrders에서 필터링이 완료되었으므로 정렬만 수행
    final filteredOrders = List<OrderModel>.from(_orders)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // 최신순으로 정렬

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: context.w(64),
              color: AppColors.gray400,
            ),
            SizedBox(height: context.h(16)),
            Text(
              '주문 내역이 없습니다',
              style: AppFonts.b1Semibold.copyWith(color: AppColors.gray600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      // 필터 탭과 첫 컴포넌트 사이 여백을 줄이기 위해 상단 패딩 축소
      padding: EdgeInsets.only(
        top: context.h(8),
        bottom: context.h(12),
      ),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return _buildOrderItem(order);
      },
    );
  }

  Widget _buildOrderItem(OrderModel order) {
    final isSelected = _selectedOrderId == order.orderId;
    final isBuy = order.side.toLowerCase() == 'buy';
    final quantityAndPriceText = _formatQuantityAndPrice(order);
    final statusLabel = _getStatusLabel(order);
    final orderDateText = _formatDate(order.createdAt);
    
    return OrderHistoryItem(
      orderDateText: orderDateText,
      symbol: order.symbol,
      quantityAndPriceText: quantityAndPriceText,
      statusText: statusLabel,
      isBuy: isBuy,
      isSelected: isSelected,
      onTap: () {
        if (isSelected) {
          _showDeleteDialog(order);
        } else {
          context.push('/order-detail/${order.orderId}');
        }
      },
      onLongPress: () {
        setState(() {
          _selectedOrderId = isSelected ? null : order.orderId;
        });
      },
      onDeleteTap: () => _showDeleteDialog(order),
    );
  }

  Widget _buildCycleList() {
    print('💡 _buildCycleList 호출됨 - _isLoading: $_isLoading, _cycleData.length: ${_cycleData.length}');
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (_cycleData.isEmpty) {
      print('💡 사이클 데이터가 비어있습니다');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '완료된 거래 사이클이 없습니다',
              style: AppFonts.b1Regular.copyWith(
                color: AppColors.gray400,
              ),
            ),
            SizedBox(height: context.h(8)),
            Text(
              '매수부터 전량 매도까지 완료된 거래가 여기에 표시됩니다.',
              style: AppFonts.c2.copyWith(
                color: AppColors.gray300,
              ),
            ),
          ],
        ),
      );
    }

    print('💡 사이클 리스트 빌드 시작 - ${_cycleData.length}개 아이템');
    return ListView.builder(
      padding: EdgeInsets.only(
        top: context.h(8),
        bottom: context.h(12),
      ),
      itemCount: _cycleData.length,
      itemBuilder: (context, index) {
        final cycle = _cycleData[index];
        print('💡 사이클 아이템 $index: ${cycle.symbol}, 손익률: ${cycle.profitLossRate}, 손익금액: ${cycle.profitLossAmount}');
        return _buildCycleItem(cycle);
      },
    );
  }

  Widget _buildCycleItem(TradeCycleResponseDto cycle) {
    // 날짜 범위 포맷팅
    final startDate = cycle.startDate;
    final endDate = cycle.endDate ?? startDate; // endDate가 null이면 startDate 사용
    final startDateText = '${startDate.year.toString().substring(2)}.${startDate.month.toString().padLeft(2, '0')}.${startDate.day.toString().padLeft(2, '0')}';
    final endDateText = '${endDate.year.toString().substring(2)}.${endDate.month.toString().padLeft(2, '0')}.${endDate.day.toString().padLeft(2, '0')}';
    final dateRangeText = '$startDateText - $endDateText';
    
    // 손익률 포맷팅
    final profitLossRate = cycle.profitLossRate;
    // -0.03 같은 경우 -0.0%가 되지 않도록 처리
    String profitLossRateText;
    if (profitLossRate.abs() < 0.05) {
      // 0.05 미만이면 소수점 둘째 자리까지 표시
      profitLossRateText = '${profitLossRate >= 0 ? '+' : ''}${profitLossRate.toStringAsFixed(2)}%';
    } else {
      profitLossRateText = '${profitLossRate >= 0 ? '+' : ''}${profitLossRate.toStringAsFixed(1)}%';
    }
    
    // 손익 금액 포맷팅
    final profitLossAmount = cycle.profitLossAmount;
    final profitLossAmountText = '\$${profitLossAmount.abs().toStringAsFixed(2)}';
    
    // 손익률 색상 (양수: 빨간색, 음수: 파란색)
    final profitLossColor = profitLossRate >= 0 ? AppColors.loss : AppColors.profit;
    
    print('💡 _buildCycleItem - symbol: ${cycle.symbol}, rate: $profitLossRate, amount: $profitLossAmount');
    print('💡 포맷팅된 텍스트: $profitLossRateText · $profitLossAmountText');
    
    return TradeCycleItem(
      dateRangeText: dateRangeText,
      leading: _buildCycleLogo(context, cycle.logoUrl, cycle.symbol),
      symbol: cycle.symbol,
      profitLossText: '$profitLossRateText · $profitLossAmountText',
      profitLossColor: profitLossColor,
      onReportTap: () {
        context.push('/trade-report/${cycle.tradeCycleId}');
      },
    );
  }

  Widget _buildCycleLogo(BuildContext context, String? logoUrl, String symbol) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return _buildCompanyLogo(symbol);
    }

    return FutureBuilder<Uint8List?>(
      future: _getLogoBytes(logoUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCompanyLogo(symbol);
        }

        final bytes = snapshot.data;
        if (bytes != null) {
          return ClipOval(
            child: Image.memory(
              bytes,
              width: context.w(44),
              height: context.h(44),
              fit: BoxFit.cover,
            ),
          );
        }

        return _buildCompanyLogo(symbol);
      },
    );
  }

  Future<Uint8List?> _getLogoBytes(String url) {
    if (_logoCache.containsKey(url)) {
      return Future.value(_logoCache[url]);
    }

    if (_logoRequestCache.containsKey(url)) {
      return _logoRequestCache[url]!;
    }

    final future = _fetchLogoBytes(url);
    _logoRequestCache[url] = future;
    future.then((bytes) {
      _logoCache[url] = bytes;
      _logoRequestCache.remove(url);
    });
    return future;
  }

  Future<Uint8List?> _fetchLogoBytes(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        debugPrint('잘못된 로고 URL: $url');
        return null;
      }

      final response = await http.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }

      debugPrint('회사 로고 로드 실패 ($url): ${response.statusCode}');
      return null;
    } catch (error) {
      debugPrint('회사 로고 로드 중 오류 ($url): $error');
      return null;
    }
  }

  Widget _buildCompanyLogo(String ticker) {
    // 빈 문자열 가드: ticker가 비어있으면 '?' 사용
    final safeTicker = ticker.isNotEmpty ? ticker : '?';
    final initial = safeTicker.substring(0, 1).toUpperCase();
    
    return Container(
      width: context.w(40),
      height: context.h(40),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          initial,
          style: AppFonts.b1Semibold.copyWith(
            color: AppColors.gray600,
          ),
        ),
      ),
    );
  }
}
