import 'package:flutter/material.dart';
import 'package:nfc_use/core/constants/card_item.dart';

/// 卡片详情页面组件
///
/// 展示卡片的详细信息，支持下滑返回交互效果。
/// 页面背景使用卡片颜色，包含标题等内容。
class CardDetailScreen extends StatefulWidget {
  /// 卡片数据对象
  final CardItem item;

  /// 创建卡片详情页面
  ///
  /// [item] 要展示的卡片数据对象
  const CardDetailScreen({super.key, required this.item});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

/// 卡片详情页面状态类
///
/// 管理页面的动画控制器、拖动状态、关闭状态等内部状态。
/// 实现下滑返回、系统返回键处理等交互功能。
class _CardDetailScreenState extends State<CardDetailScreen>
    with SingleTickerProviderStateMixin {
  /// 动画控制器，用于驱动页面关闭动画
  late AnimationController _animationController;

  /// 单一真相源：当前垂直位移。0 = 原位，正数 = 向下拖。
  double _totalDy = 0;

  /// 动画令牌：每次启动动画就递增，老动画的listener会比较这个值，
  /// 一旦不匹配就不再setState，避免多段动画互相干扰。
  int _animToken = 0;

  /// 是否正在关闭页面
  bool _isClosing = false;

  /// ListView 滚动控制器，用于判断列表是否在顶部
  final ScrollController _scrollController = ScrollController();

  /// 是否正在下拉（列表在顶部 + 用户继续向下拖）
  bool _isPullingDown = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: kDetailPageCloseDuration,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 在指定时间内把 `_totalDy` 从 [from] 平滑动画到 [to]。
  ///
  /// 返回的Future在动画正常完成且未被新动画打断时为 `true`。
  ///
  /// [from] 起始位置
  /// [to] 目标位置
  /// [duration] 动画时长
  /// [curve] 动画曲线，默认为线性
  Future<bool> _animateTo({
    required double from,
    required double to,
    required Duration duration,
    Curve curve = Curves.linear,
  }) async {
    if (!mounted) return false;
    final myToken = ++_animToken;
    _animationController.duration = duration;
    final animation = Tween<double>(
      begin: from,
      end: to,
    ).animate(CurvedAnimation(parent: _animationController, curve: curve));

    void listener() {
      if (mounted && _animToken == myToken) {
        setState(() => _totalDy = animation.value);
      }
    }

    animation.addListener(listener);
    try {
      await _animationController.forward(from: 0);
    } finally {
      animation.removeListener(listener);
      if (mounted && _animToken == myToken) {
        setState(() => _totalDy = to);
      }
    }
    return _animToken == myToken && mounted;
  }

  /// 立即丢弃正在运行的"回位 / 关闭"动画。
  ///
  /// 通过递增动画令牌并重置动画控制器来取消当前动画。
  void _cancelAnimation() {
    _animToken++;
    _animationController.reset();
  }

  /// 用户触发的正式关闭流程：直接让页面向下飞出，然后pop。
  ///
  /// 不再在这个路径上做任何NFC操作——"下滑即返回"。
  Future<void> _closePage() async {
    if (_isClosing) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final startDy = _totalDy;

    setState(() => _isClosing = true);
    await _animateTo(
      from: startDy,
      to: screenHeight,
      duration: kDetailPageCloseDuration,
      curve: Curves.easeInCubic,
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// 系统返回键 / 右上角关闭按钮：统一走"动画 + pop"，避免直接pop时没有过渡。
  ///
  /// 返回 `true` 表示已处理返回操作，`false` 表示未处理。
  Future<bool> _handleSystemPop() async {
    if (_isClosing) return false;
    setState(() => _isClosing = true);
    final screenHeight = MediaQuery.sizeOf(context).height;
    await _animateTo(
      from: _totalDy,
      to: screenHeight,
      duration: kDetailPageCloseDuration,
      curve: Curves.easeInCubic,
    );
    if (mounted) Navigator.of(context).pop();
    return true;
  }

  /// 拖动进度（0-1）
  ///
  /// 根据当前拖动距离与关闭阈值的比例计算
  double get _dragProgress =>
      (_totalDy / kDetailPageCloseThreshold).clamp(0.0, 1.0);

  /// 当前缩放比例
  ///
  /// 随着拖动距离增加而减小
  double get _currentScale =>
      1.0 - (_dragProgress * kDetailPageDragScaleChange);

  /// 当前透明度
  ///
  /// 随着拖动距离增加而降低
  double get _currentOpacity =>
      1.0 - (_dragProgress * kDetailPageDragOpacityChange);

  /// 构建详情页内容区域
  ///
  /// 包含关闭按钮、NFC提示图标和标题
  Widget _buildDetailContent() {
    return SafeArea(
      child: Stack(children: [_buildCloseButton(), _buildMainContent()]),
    );
  }

  /// 构建右上角关闭按钮
  Widget _buildCloseButton() {
    return Positioned(
      top: 0,
      right: 0,
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: _isClosing ? null : () => _handleSystemPop(),
      ),
    );
  }

  /// 构建主要内容区域
  ///
  /// 包含NFC提示和卡片详细信息
  Widget _buildMainContent() {
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        _buildNfcHint(),
        const SizedBox(height: 32),
        _buildTitleSection(),
      ],
    );
  }

  /// 构建NFC提示区域
  ///
  /// 根据页面状态显示不同的提示内容：
  /// - 正常状态：显示下滑返回提示
  /// - 关闭状态：显示正在关闭提示
  Widget _buildNfcHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isClosing ? Icons.nfc : Icons.keyboard_arrow_down,
            color: Colors.white70,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            _isClosing ? '正在关闭...' : '下滑返回',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// 构建标题区域
  ///
  /// 包含卡片标题
  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.item.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 判断 ListView 是否在顶部（不能继续向上滚动）
  bool get _isAtTop {
    if (!_scrollController.hasClients) return true;
    return _scrollController.offset <= 0;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isClosing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemPop();
      },
      child: Scaffold(
        backgroundColor: widget.item.color,
        body: Listener(
          onPointerDown: (_) {
            if (_isClosing) return;
            _cancelAnimation();
          },
          onPointerMove: (event) {
            if (_isClosing) return;
            final dy = event.delta.dy;

            if (_isPullingDown) {
              setState(() {
                final next = _totalDy + dy;
                if (next < 0) {
                  _totalDy = 0;
                  _isPullingDown = false;
                } else if (next > kDetailPageMaxDragDistance) {
                  _totalDy = kDetailPageMaxDragDistance;
                } else {
                  _totalDy = next;
                }
              });
              return;
            }

            if (dy > 0 && _isAtTop) {
              _isPullingDown = true;
              setState(() {
                final next = dy;
                _totalDy = next.clamp(0, kDetailPageMaxDragDistance);
              });
            }
          },
          onPointerUp: (event) async {
            if (_isClosing) return;
            if (!_isPullingDown && _totalDy == 0) return;

            final dragDistance = _totalDy;
            final velocity = event.delta.dy;
            final isFastSwipe =
                velocity > kDetailPageCloseVelocityThreshold * 0.016;

            _isPullingDown = false;

            if (dragDistance > kDetailPageCloseThreshold || isFastSwipe) {
              await _closePage();
            } else {
              await _animateTo(
                from: dragDistance,
                to: 0,
                duration: kDetailPageCloseDuration,
                curve: Curves.easeOutCubic,
              );
            }
          },
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _currentOpacity,
                child: Transform.translate(
                  offset: Offset(0, _totalDy),
                  child: Transform.scale(scale: _currentScale, child: child),
                ),
              );
            },
            child: _buildDetailContent(),
          ),
        ),
      ),
    );
  }
}
