import 'package:flutter/material.dart';
import 'package:nfc_use/core/constants/card_item.dart';
import 'package:nfc_use/core/services/sqlite_service.dart';
import 'package:nfc_use/pages/Home/card_use.dart';
import 'package:nfc_use/pages/Home/card.dart';
import 'package:nfc_use/pages/Home/card_sort.dart';

/// 主页组件
///
/// 展示卡片画廊列表，支持：
/// 1. 左右滑动切换卡片
/// 2. 上滑查看当前卡片详情
/// 3. 滑到最左/最右继续拖动时，卡片产生轻微拉伸效果
/// 4. 在边缘继续滑动达到阈值后打开统一的新页面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 页面控制器，用于卡片横向滑动
  final PageController _pageController = PageController(
    viewportFraction: kCardListViewportFraction,
    initialPage: 0,
  );

  /// 当前显示的页面索引
  int _currentPage = 0;

  /// 当前卡片的重置函数引用，用于页面返回后恢复卡片状态
  Function? _currentResetCard;

  /// 保存每个卡片的 GlobalKey，用于触发卡片动画
  final List<GlobalKey> _cardKeys = [];

  /// 是否正在加载卡片
  bool _isLoadingCards = true;

  /// 当前展示卡片数据列表
  List<CardItem> _cardItems = [];

  /// 示例卡片数据列表
  static final List<CardItem> _sampleCardItems = [
    CardItem(
      id: 'NONE',
      title: 'NONE',
      color: kCardDefaultColors['explore']!,
      imageUrl:
          'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800&q=80',
    ),
  ];

  // ============================================================
  // 边缘滑动状态
  // ============================================================

  /// 当前边缘拉伸程度
  ///
  /// 0.0 = 正常
  /// 1.0 = 达到最大拉伸
  double _edgeStretch = 0.0;

  /// 当前是否正在左边缘拉伸
  bool _atLeftEdge = false;

  /// 当前是否正在右边缘拉伸
  bool _atRightEdge = false;

  /// 本次边缘滑动累计距离
  double _edgeDragDistance = 0.0;

  /// 防止重复打开边缘页面
  bool _isOpeningEdgePage = false;

  bool _isHorizontalPointerDown = false;

  double? _lastPointerX;

  bool _isEdgeDragging = false;

  /// 开启边缘页面所需要的最小拖动距离
  static const double _edgeOpenThreshold = 82.0;

  // ============================================================
  // 生命周期
  // ============================================================

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

  // ============================================================
  // 数据
  // ============================================================

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
  // 当前卡片动画
  // ============================================================

  /// 触发当前卡片的上滑动画
  void _triggerCurrentCard() {
    if (_currentPage >= 0 && _currentPage < _cardKeys.length) {
      InteractiveGalleryCard.triggerAnimation(_cardKeys[_currentPage]);
    }
  }

  // ============================================================
  // 卡片详情页
  // ============================================================

  /// 打开详情页，等页面过渡完成后再重置卡片状态
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

    /// 防止某些情况下页面返回动画已经结束，
    /// 但是卡片状态没有及时恢复。
    Future.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      _resetCurrentCard();
    });
  }

  /// 执行当前卡片的重置操作
  void _resetCurrentCard() {
    final resetCard = _currentResetCard;

    _currentResetCard = null;

    resetCard?.call();
  }

  /// 打开排序页面
  ///
  /// 左边缘和右边缘最终进入同一个 CardSortPage。
  ///
  /// fromLeft == true
  ///     从左边进入排序页面
  ///
  /// fromLeft == false
  ///     从右边进入排序页面
  Future<void> _openEdgePage({required bool fromLeft}) async {
    if (_isOpeningEdgePage) {
      return;
    }

    if (_cardItems.isEmpty) {
      return;
    }

    _isOpeningEdgePage = true;

    try {
      final List<CardItem>?
      result = await Navigator.of(context).push<List<CardItem>>(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return CardSortPage(items: _cardItems, fromLeft: fromLeft);
          },

          // 页面进入动画
          transitionDuration: const Duration(milliseconds: 320),

          // 返回动画
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

      // ----------------------------------------------------------
      // 排序页面返回了新的列表
      // ----------------------------------------------------------
      //
      // CardSortPage 保存 SQLite 后会 pop(_items)
      //
      // 这里立即更新 HomePage。
      // 同时 cardsRevision 也会触发 _loadCards，
      // 两边最终保持一致。
      //
      if (!mounted || result == null) {
        return;
      }

      setState(() {
        _cardItems = List<CardItem>.from(result);

        _currentPage = _currentPage.clamp(0, _cardItems.length - 1).toInt();

        _syncCardKeys();
      });
    } finally {
      _isOpeningEdgePage = false;
    }
  }

  // ============================================================
  // Header
  // ============================================================

  /// 构建顶部标题区域
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

  // ============================================================
  // Card List
  // ============================================================

  /// 构建卡片列表区域
  Widget _buildCardList() {
    if (_isLoadingCards) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    return Expanded(
      child: Stack(
        children: [
          // ------------------------------------------------------
          // 上滑检测层
          // ------------------------------------------------------
          Positioned.fill(
            child: _SimpleSwipeDetector(
              onSwipeUp: _triggerCurrentCard,
              child: Container(color: Colors.transparent),
            ),
          ),

          // ------------------------------------------------------
          // PageView
          // ------------------------------------------------------
          Listener(
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,

            child: PageView.builder(
              controller: _pageController,

              // 使用 BouncingScrollPhysics，
              // 让 Android 也可以在边界继续产生 overscroll。
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

                    // ------------------------------------------------
                    // 只让当前卡片产生边缘拉伸
                    // ------------------------------------------------

                    final bool isCurrent = _currentPage == index;

                    final bool isStretching =
                        isCurrent &&
                        (_atLeftEdge || _atRightEdge) &&
                        _edgeStretch > 0;

                    final double stretch = isStretching ? _edgeStretch : 0.0;

                    // 左边缘继续右拖：
                    // 卡片向右移动
                    //
                    // 右边缘继续左拖：
                    // 卡片向左移动
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

                  // --------------------------------------------------
                  // 实际卡片
                  // --------------------------------------------------
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
    if (!_isHorizontalPointerDown) {
      return;
    }

    if (_lastPointerX == null) {
      return;
    }

    final double currentX = event.position.dx;
    final double deltaX = currentX - _lastPointerX!;

    _lastPointerX = currentX;

    if (deltaX == 0) {
      return;
    }

    if (!_pageController.hasClients) {
      return;
    }

    final position = _pageController.position;

    if (!position.hasContentDimensions) {
      return;
    }

    final bool isAtLeft = position.pixels <= position.minScrollExtent + 0.5;

    final bool isAtRight = position.pixels >= position.maxScrollExtent - 0.5;

    // 第一张，继续向右拖
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

    // 最后一张，继续向左拖
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
    if (!_isHorizontalPointerDown) {
      return;
    }

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

    if (mounted) {
      setState(() {});
    }

    if (!shouldOpen) {
      return;
    }

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

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // Bottom indicator
  // ============================================================

  /// 构建底部指示器区域
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

  // ============================================================
  // Build
  // ============================================================

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
// 上滑手势检测
// ================================================================

/// 简单的上滑手势检测组件
///
/// 检测用户的上滑操作，并触发回调。
class _SimpleSwipeDetector extends StatefulWidget {
  /// 上滑回调
  final VoidCallback? onSwipeUp;

  /// 子组件
  final Widget child;

  const _SimpleSwipeDetector({required this.child, this.onSwipeUp});

  @override
  State<_SimpleSwipeDetector> createState() => _SimpleSwipeDetectorState();
}

class _SimpleSwipeDetectorState extends State<_SimpleSwipeDetector> {
  /// 拖动起始位置
  Offset? _dragStartPosition;

  /// 当前拖动距离
  double _dragDistance = 0;

  /// 最小滑动距离阈值
  static const double _minSwipeDistance = 48;

  /// 最小滑动速度阈值
  static const double _minSwipeVelocity = 360;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onVerticalDragStart: (details) {
        _dragStartPosition = details.localPosition;

        _dragDistance = 0;
      },

      onVerticalDragUpdate: (details) {
        if (details.delta.dy < 0) {
          _dragDistance -= details.delta.dy;
        }
      },

      onVerticalDragEnd: (details) {
        if (_dragStartPosition == null) {
          return;
        }

        final bool hasEnoughDistance = _dragDistance >= _minSwipeDistance;

        final bool hasEnoughVelocity =
            details.primaryVelocity != null &&
            details.primaryVelocity! < -_minSwipeVelocity;

        if (hasEnoughDistance || hasEnoughVelocity) {
          widget.onSwipeUp?.call();
        }

        _dragStartPosition = null;
        _dragDistance = 0;
      },

      child: widget.child,
    );
  }
}

// ================================================================
// 边缘进入的新页面
// ================================================================

/// 左右边缘滑动后打开的统一页面
///
/// 左边缘和右边缘最终都会进入这个页面。
///
/// 这里先给一个完整可运行的示例页面。
/// 之后你只需要把这个页面的内容换成你的实际页面即可。
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
