import 'package:flutter/material.dart';
import 'package:nfc_use/core/constants/card_item.dart';

class CardDetailScreen extends StatefulWidget {
  final CardItem item;

  const CardDetailScreen({super.key, required this.item});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // 单一真相源：当前垂直位移。0 = 原位，正数 = 向下拖。
  double _totalDy = 0;

  // 简单“令牌”：每次启动动画就递增，老动画的 listener 会比较这个值，
  // 一旦不匹配就不再 setState，避免多段动画互相干扰。
  int _animToken = 0;
  bool _isClosing = false;

  static const double _closeThreshold = 150;
  static const double _velocityThreshold = 700;
  static const double _maxDragDistance = 280;
  static const Duration _closeDuration = Duration(milliseconds: 360);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: _closeDuration,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 在 [duration] 内把 `_totalDy` 从 [from] 平滑动画到 [to]。
  /// 返回的 Future 在动画正常完成且未被新动画打断时为 `true`。
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

  /// 立即丢弃正在运行的“回位 / 关闭”动画。
  void _cancelAnimation() {
    _animToken++;
    _animationController.reset();
  }

  /// 用户触发的正式关闭流程：直接让页面向下飞出，然后 pop。
  /// 不再在这个路径上做任何 NFC 操作——“下滑即返回”。
  Future<void> _closePage() async {
    if (_isClosing) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final startDy = _totalDy;

    setState(() => _isClosing = true);
    await _animateTo(
      from: startDy,
      to: screenHeight,
      duration: _closeDuration,
      curve: Curves.easeInCubic,
    );
    if (mounted) Navigator.of(context).pop();
  }

  // 系统返回键 / 右上角关闭按钮：统一走“动画 + pop”，避免直接 pop 时没有过渡。
  Future<bool> _handleSystemPop() async {
    if (_isClosing) return false;
    setState(() => _isClosing = true);
    final screenHeight = MediaQuery.sizeOf(context).height;
    await _animateTo(
      from: _totalDy,
      to: screenHeight,
      duration: _closeDuration,
      curve: Curves.easeInCubic,
    );
    if (mounted) Navigator.of(context).pop();
    return true;
  }

  double get _dragProgress => (_totalDy / _closeThreshold).clamp(0.0, 1.0);

  double get _currentScale => 1.0 - (_dragProgress * 0.08);

  double get _currentOpacity => 1.0 - (_dragProgress * 0.3);

  Widget _nfcPage() {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _isClosing ? null : () => _handleSystemPop(),
            ),
          ),
          Center(
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
                  _isClosing ? '正在写入...' : '下滑返回',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // `canPop: _isClosing`：
    // - 正常交互时 (_isClosing=false) → canPop=false → 系统返回被拦截，
    //   进入 onPopInvokedWithResult 后播放我们的关闭动画，再 setState _isClosing=true，
    //   随后 Navigator.pop 就会被真正执行。
    // - 进入关闭流程后 (_isClosing=true) → canPop=true → 不再拦截，
    //   避免“永远退不出去”的死循环。
    return PopScope(
      canPop: _isClosing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemPop();
      },
      child: Scaffold(
        backgroundColor: widget.item.color,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          // 正在关闭时不再接受任何手势。
          onVerticalDragStart: (_) {
            if (_isClosing) return;
            _cancelAnimation();
          },
          onVerticalDragUpdate: (details) {
            if (_isClosing) return;
            setState(() {
              final next = _totalDy + details.delta.dy;
              // 允许向上滑回 0，向下最大到 _maxDragDistance。
              if (next < 0) {
                _totalDy = 0;
              } else if (next > _maxDragDistance) {
                _totalDy = _maxDragDistance;
              } else {
                _totalDy = next;
              }
            });
          },
          onVerticalDragEnd: (details) async {
            if (_isClosing) return;
            final double dragDistance = _totalDy;
            final double? velocity = details.primaryVelocity;
            final bool isFastSwipe =
                velocity != null && velocity > _velocityThreshold;
            if (dragDistance > _closeThreshold || isFastSwipe) {
              await _closePage();
            } else {
              await _animateTo(
                from: dragDistance,
                to: 0,
                duration: _closeDuration,
                curve: Curves.easeOutCubic,
              );
            }
          },
          // 动画只作用于内部内容，手势探测器永远保持在屏幕原位。
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
            child: _nfcPage(),
          ),
        ),
      ),
    );
  }
}
