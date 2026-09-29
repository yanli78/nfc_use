import 'package:flutter/material.dart';
import 'package:nfc_use/core/constants/card_item.dart';
import 'dart:io';

/// 卡片详情页面组件
class CardDetailScreen extends StatefulWidget {
  final CardItem item;

  const CardDetailScreen({super.key, required this.item});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  double _totalDy = 0;
  int _animToken = 0;
  bool _isClosing = false;
  final ScrollController _scrollController = ScrollController();
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

  void _cancelAnimation() {
    _animToken++;
    _animationController.reset();
  }

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

  double get _dragProgress =>
      (_totalDy / kDetailPageCloseThreshold).clamp(0.0, 1.0);

  double get _currentScale =>
      1.0 - (_dragProgress * kDetailPageDragScaleChange);

  double get _currentOpacity =>
      1.0 - (_dragProgress * kDetailPageDragOpacityChange);

  /// 构建详情页内容区域：底层全屏背景图 + 上层安全区交互内容
  Widget _buildDetailContent() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackgroundImage(),
        SafeArea(
          child: Stack(children: [_buildCloseButton(), _buildMainContent()]),
        ),
      ],
    );
  }

  /// 构建背景图片及保护性半透明遮罩
  Widget _buildBackgroundImage() {
    if (widget.item.imageUrl.isEmpty) {
      return Container(color: widget.item.color);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(widget.item.imageUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: widget.item.color),
        ),
        // 半透明遮罩，保证上层白色字体在任意图片背景下的对比度
        Container(color: Colors.black.withValues(alpha: 0.35)),
      ],
    );
  }

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

  Widget _buildMainContent() {
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        _buildNfcHint(),
        const SizedBox(height: 32),
        _buildTitleSection(),
      ],
    );
  }

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

  /// 构建标题区域：居中对齐
  Widget _buildTitleSection() {
    return Center(
      child: Text(
        widget.item.title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

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
        // 底层兜底色维持卡片主色
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
