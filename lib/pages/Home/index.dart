import 'package:flutter/material.dart';
import 'package:nfc_use/core/constants/card_item.dart';
import 'package:nfc_use/core/services/sqlite_service.dart';
import 'package:nfc_use/pages/Home/card_use.dart';
import 'package:nfc_use/pages/Home/card.dart';
import 'package:nfc_use/pages/Home/card_sort.dart';

/// 主页组件
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController(
    viewportFraction: kCardListViewportFraction,
    initialPage: 0,
  );

  int _currentPage = 0;
  Function? _currentResetCard;
  final List<GlobalKey> _cardKeys = [];
  bool _isLoadingCards = true;
  List<CardItem> _cardItems = [];

  static final List<CardItem> _sampleCardItems = [
    CardItem(
      id: 'NONE',
      title: 'NONE',
      color: kCardDefaultColors['explore']!,
      imageUrl:
          'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800&q=80',
    ),
  ];

  // 边缘滑动状态
  double _edgeStretch = 0.0;
  bool _atLeftEdge = false;
  bool _atRightEdge = false;
  double _edgeDragDistance = 0.0;
  bool _isOpeningEdgePage = false;
  bool _isHorizontalPointerDown = false;
  double? _lastPointerX;
  bool _isEdgeDragging = false;
  static const double _edgeOpenThreshold = 82.0;

  @override
  void initState() {
    super.initState();
    CardDatabaseHelper.instance.cardsRevision.addListener(_loadCards);
    _loadCards();
  }

  @override
  void dispose() {
    CardDatabaseHelper.instance.cardsRevision.removeListener(_loadCards);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    final cards = await CardDatabaseHelper.instance.getAllCards();
    if (!mounted) return;

    setState(() {
      _cardItems = cards.isEmpty ? _sampleCardItems : cards;
      _isLoadingCards = false;
      _currentPage = _cardItems.isEmpty
          ? 0
          : _currentPage.clamp(0, _cardItems.length - 1).toInt();
      _syncCardKeys();
    });
  }

  void _syncCardKeys() {
    while (_cardKeys.length < _cardItems.length) {
      _cardKeys.add(GlobalKey());
    }
    if (_cardKeys.length > _cardItems.length) {
      _cardKeys.removeRange(_cardItems.length, _cardKeys.length);
    }
  }

  // ============================================================
  // 当前卡片动画（增加滚动互斥保护）
  // ============================================================

  void _triggerCurrentCard() {
    // 1. 如果当前正在处理边缘拉伸或正在打开边缘页面，拦截上滑
    if (_isEdgeDragging || _isOpeningEdgePage) {
      return;
    }

    // 2. 如果 PageView 尚未停稳（页面仍处于滑动切换过渡中），拦截上滑
    if (_pageController.hasClients && _pageController.page != null) {
      final double pageOffset = (_pageController.page! - _currentPage).abs();
      if (pageOffset > 0.12) {
        return;
      }
    }

    if (_currentPage >= 0 && _currentPage < _cardKeys.length) {
      InteractiveGalleryCard.triggerAnimation(_cardKeys[_currentPage]);
    }
  }

  void _openDetailPage(CardItem item, Function resetCard) {
    _currentResetCard = resetCard;

    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return CardDetailScreen(item: item);
            },
            transitionDuration: kCardExitDuration,
            reverseTransitionDuration: const Duration(milliseconds: 340),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  final tween = Tween<Offset>(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: Curves.easeOutCubic));

                  final offsetAnimation = animation.drive(tween);
                  final opacityAnimation = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutQuad,
                  );

                  return SlideTransition(
                    position: offsetAnimation,
                    child: FadeTransition(
                      opacity: opacityAnimation,
                      child: child,
                    ),
                  );
                },
          ),
        )
        .then((_) {
          _resetCurrentCard();
        });

    Future.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      _resetCurrentCard();
    });
  }

  void _resetCurrentCard() {
    final resetCard = _currentResetCard;
    _currentResetCard = null;
    resetCard?.call();
  }

  Future<void> _openEdgePage({required bool fromLeft}) async {
    if (_isOpeningEdgePage || _cardItems.isEmpty) return;

    _isOpeningEdgePage = true;

    try {
      final List<CardItem>?
      result = await Navigator.of(context).push<List<CardItem>>(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return CardSortPage(items: _cardItems, fromLeft: fromLeft);
          },
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final Offset begin = fromLeft
                ? const Offset(-1.0, 0.0)
                : const Offset(1.0, 0.0);
            final Animatable<Offset> tween = Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic));

            final Animation<Offset> offsetAnimation = animation.drive(tween);
            final Animation<double> opacityAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuad,
            );

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(opacity: opacityAnimation, child: child),
            );
          },
        ),
      );

      if (!mounted || result == null) return;

      setState(() {
        _cardItems = List<CardItem>.from(result);
        _currentPage = _currentPage.clamp(0, _cardItems.length - 1).toInt();
        _syncCardKeys();
      });
    } finally {
      _isOpeningEdgePage = false;
    }
  }

  Widget _buildHeader() {
    return _SimpleSwipeDetector(
      onSwipeUp: _triggerCurrentCard,
      child: const Padding(
        padding: EdgeInsets.only(left: 24, top: 40, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '精选画廊',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '左右滑动切换 · 上滑任意位置查看详情',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardList() {
    if (_isLoadingCards) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    return Expanded(
      child: Stack(
        children: [
          Positioned.fill(
            child: _SimpleSwipeDetector(
              onSwipeUp: _triggerCurrentCard,
              child: Container(color: Colors.transparent),
            ),
          ),
          Listener(
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
              itemCount: _cardItems.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final CardItem item = _cardItems[index];

                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 1.0;
                    if (_pageController.position.haveDimensions &&
                        _pageController.page != null) {
                      value = _pageController.page! - index;
                      value = (1 - (value.abs() * 0.1)).clamp(0.8, 1.0);
                    }

                    final bool isCurrent = _currentPage == index;
                    final bool isStretching =
                        isCurrent &&
                        (_atLeftEdge || _atRightEdge) &&
                        _edgeStretch > 0;
                    final double stretch = isStretching ? _edgeStretch : 0.0;

                    final double horizontalOffset = _atLeftEdge
                        ? stretch * 12.0
                        : _atRightEdge
                        ? -stretch * 12.0
                        : 0.0;

                    return Center(
                      child: SizedBox(
                        height:
                            Curves.easeInOut.transform(value) *
                            kCardDefaultHeight,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          curve: Curves.easeOut,
                          transformAlignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..translateByDouble(
                              horizontalOffset,
                              0.0,
                              0.0,
                              1.0,
                            ),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: InteractiveGalleryCard(
                    key: _cardKeys[index],
                    item: item,
                    isActive: _currentPage == index,
                    onTriggerWithReset: (resetCard) {
                      _openDetailPage(item, resetCard);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _isHorizontalPointerDown = true;
    _lastPointerX = event.position.dx;
    _edgeDragDistance = 0.0;
    _edgeStretch = 0.0;
    _atLeftEdge = false;
    _atRightEdge = false;
    _isEdgeDragging = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isHorizontalPointerDown || _lastPointerX == null) return;

    final double currentX = event.position.dx;
    final double deltaX = currentX - _lastPointerX!;
    _lastPointerX = currentX;

    if (deltaX == 0 || !_pageController.hasClients) return;

    final position = _pageController.position;
    if (!position.hasContentDimensions) return;

    final bool isAtLeft = position.pixels <= position.minScrollExtent + 0.5;
    final bool isAtRight = position.pixels >= position.maxScrollExtent - 0.5;

    if (isAtLeft && deltaX > 0) {
      _atLeftEdge = true;
      _atRightEdge = false;
      _isEdgeDragging = true;
      _edgeDragDistance += deltaX;

      if (mounted) {
        setState(() {
          _edgeStretch = (_edgeDragDistance / 100.0).clamp(0.0, 1.0);
        });
      }
      return;
    }

    if (isAtRight && deltaX < 0) {
      _atLeftEdge = false;
      _atRightEdge = true;
      _isEdgeDragging = true;
      _edgeDragDistance += -deltaX;

      if (mounted) {
        setState(() {
          _edgeStretch = (_edgeDragDistance / 100.0).clamp(0.0, 1.0);
        });
      }
      return;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_isHorizontalPointerDown) return;

    final bool shouldOpen =
        _isEdgeDragging && _edgeDragDistance >= _edgeOpenThreshold;
    final bool fromLeft = _atLeftEdge;
    final bool fromRight = _atRightEdge;

    _isHorizontalPointerDown = false;
    _lastPointerX = null;
    _edgeDragDistance = 0.0;
    _edgeStretch = 0.0;
    _isEdgeDragging = false;
    _atLeftEdge = false;
    _atRightEdge = false;

    if (mounted) setState(() {});

    if (!shouldOpen) return;

    if (fromLeft) {
      _openEdgePage(fromLeft: true);
    } else if (fromRight) {
      _openEdgePage(fromLeft: false);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _isHorizontalPointerDown = false;
    _lastPointerX = null;
    _edgeDragDistance = 0.0;
    _edgeStretch = 0.0;
    _isEdgeDragging = false;
    _atLeftEdge = false;
    _atRightEdge = false;

    if (mounted) setState(() {});
  }

  Widget _buildEnd() {
    return _SimpleSwipeDetector(
      onSwipeUp: _triggerCurrentCard,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_cardItems.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentPage == index
                        ? const Color(0xFF00966A)
                        : Colors.grey[300],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildHeader(), _buildCardList(), _buildEnd()],
        ),
      ),
    );
  }
}

// ================================================================
// 上滑手势检测（防斜滑误触重构版）
// ================================================================

/// 带方向角与比例过滤的上滑检测组件
class _SimpleSwipeDetector extends StatefulWidget {
  final VoidCallback? onSwipeUp;
  final Widget child;

  const _SimpleSwipeDetector({required this.child, this.onSwipeUp});

  @override
  State<_SimpleSwipeDetector> createState() => _SimpleSwipeDetectorState();
}

class _SimpleSwipeDetectorState extends State<_SimpleSwipeDetector> {
  Offset? _startGlobalPos;
  Offset? _lastGlobalPos;

  /// 本轮手势是否已被作废（一旦检测到明显横滑意图，设为 true，绝不触发上滑）
  bool _isDisqualified = false;

  /// 触发上滑的最小向上位移（提升至 64，避免手指轻微抖动即触发）
  static const double _minSwipeDistance = 64.0;

  /// 触发快速上滑的最小向上速度
  static const double _minSwipeVelocity = 450.0;

  /// 垂直位移与水平位移的最小比例（dy / dx 需 >= 1.5，对应夹角约 56° 以上）
  static const double _directionRatio = 1.5;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (details) {
        _startGlobalPos = details.globalPosition;
        _lastGlobalPos = details.globalPosition;
        _isDisqualified = false;
      },
      onVerticalDragUpdate: (details) {
        if (_isDisqualified || _startGlobalPos == null) return;

        _lastGlobalPos = details.globalPosition;

        final double totalDx = (details.globalPosition.dx - _startGlobalPos!.dx)
            .abs();
        final double totalDy =
            _startGlobalPos!.dy - details.globalPosition.dy; // 向上为正

        // 1. 水平位移已经产生（>18px），且水平位移大于或接近垂直位移，说明是横滑或斜滑，立即永久否决本次上滑
        if (totalDx > 18.0 && totalDx >= totalDy) {
          _isDisqualified = true;
          return;
        }

        // 2. 如果是明显向下滑动（>24px），也立即否决
        if (totalDy < -24.0) {
          _isDisqualified = true;
          return;
        }
      },
      onVerticalDragEnd: (details) {
        if (_isDisqualified ||
            _startGlobalPos == null ||
            _lastGlobalPos == null) {
          _reset();
          return;
        }

        final double totalDx = (_lastGlobalPos!.dx - _startGlobalPos!.dx).abs();
        final double totalDy = _startGlobalPos!.dy - _lastGlobalPos!.dy; // 向上为正

        final double vy = details.velocity.pixelsPerSecond.dy; // 向上为负
        final double vx = details.velocity.pixelsPerSecond.dx.abs();

        // 判定 1：距离判定（净向上位移达标，且垂直位移显著大于水平位移）
        final bool isDistanceValid =
            totalDy >= _minSwipeDistance &&
            totalDy >= (totalDx * _directionRatio);

        // 判定 2：速度判定（垂直速度达标，且向上速度明显大于横向速度，防止横甩时误触）
        final bool isVelocityValid =
            vy <= -_minSwipeVelocity &&
            (-vy) >= (vx * _directionRatio) &&
            totalDy > 16.0;

        if (isDistanceValid || isVelocityValid) {
          widget.onSwipeUp?.call();
        }

        _reset();
      },
      onVerticalDragCancel: _reset,
      child: widget.child,
    );
  }

  void _reset() {
    _startGlobalPos = null;
    _lastGlobalPos = null;
    _isDisqualified = false;
  }
}

// ================================================================
// 边缘进入的新页面
// ================================================================

class EdgeActionPage extends StatelessWidget {
  const EdgeActionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('新页面'),
        elevation: 0,
        backgroundColor: Colors.grey[100],
        foregroundColor: Colors.black87,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF00966A),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '边缘页面',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              '从左右任意一侧滑到尽头即可进入',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}
