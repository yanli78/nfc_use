import 'package:flutter/material.dart';
import 'package:nfc_use/core/constants/card_item.dart';
import 'package:nfc_use/core/services/nfc_service.dart';

class InteractiveGalleryCard extends StatefulWidget {
  final CardItem item;
  final VoidCallback? onTrigger;
  final bool isActive;
  final Function(Function resetCard)? onTriggerWithReset;

  const InteractiveGalleryCard({
    super.key,
    required this.item,
    this.onTrigger,
    this.isActive = false,
    this.onTriggerWithReset,
  });

  // 公开方法，让外部可以触发上滑动画
  static void triggerAnimation(GlobalKey key) {
    final state = key.currentState as _InteractiveGalleryCardState?;
    if (state != null && state.mounted) {
      state.triggerCardAnimation();
    }
  }

  @override
  State<InteractiveGalleryCard> createState() => _InteractiveGalleryCardState();
}

class _InteractiveGalleryCardState extends State<InteractiveGalleryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _shadowAnimation;

  Offset _dragOffset = Offset.zero;

  // null / dragging / hovering / writing / closing / cancelling
  String _phase = 'idle';

  static const double _triggerThreshold = 150;
  static const double _velocityThreshold = 700;
  static const double _maxDragDistance = 240;
  static const Duration _snapBackDuration = Duration(milliseconds: 320);
  static const Duration _hoverDuration = Duration(milliseconds: 360);
  static const Duration _exitDuration = Duration(milliseconds: 360);
  static const Duration _nfcTimeout = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: _hoverDuration,
    );
    _resetAnimations();
  }

  void _resetAnimations() {
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(_animationController);
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(_animationController);
    _shadowAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(_animationController);
    _animationController.value = 0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ================== 手势 ==================

  void _handleVerticalDragStart(DragStartDetails details) {
    if (!widget.isActive) return;
    if (_phase == 'writing' || _phase == 'closing') return;
    _animationController.stop();
    setState(() {
      _phase = 'dragging';
    });
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!widget.isActive) return;
    if (_phase != 'dragging') return;

    if (details.delta.dy < 0) {
      setState(() {
        final nextOffset = _dragOffset.dy + details.delta.dy;
        _dragOffset = Offset(0, nextOffset.clamp(-_maxDragDistance, 0));
      });
    } else {
      // 允许用户把卡片推回 0
      setState(() {
        final nextOffset = _dragOffset.dy + details.delta.dy;
        if (nextOffset >= 0) {
          _dragOffset = Offset.zero;
          _phase = 'idle';
        } else {
          _dragOffset = Offset(0, nextOffset);
        }
      });
    }
  }

  Future<void> _handleVerticalDragEnd(DragEndDetails details) async {
    if (!widget.isActive) return;
    if (_phase != 'dragging') return;

    final double dragDistance = -_dragOffset.dy;
    final bool isFastSwipe =
        details.primaryVelocity != null &&
        details.primaryVelocity! < -_velocityThreshold;

    if (dragDistance > _triggerThreshold || isFastSwipe) {
      // 上滑成功：先悬停在上方 → 扫描 NFC
      await _triggerAction();
    } else {
      // 距离不足：用户“下滑取消”，平滑回位
      await _animateBackToStart();
    }
  }

  // ================== 对外接口 ==================

  void triggerCardAnimation() {
    if (!widget.isActive) return;
    if (_phase == 'writing' || _phase == 'closing') return;
    _triggerAction();
  }

  // ================== 核心：上滑 => NFC => 详情页 ==================

  Future<void> _triggerAction() async {
    if (_phase == 'writing' || _phase == 'closing') return;

    final screenHeight = MediaQuery.sizeOf(context).height;
    final startOffset = _dragOffset;

    // 1. 先让卡片飞到“悬停在上方”的位置
    setState(() => _phase = 'hovering');
    _animationController.duration = _hoverDuration;
    _slideAnimation =
        Tween<Offset>(
          begin: startOffset,
          end: Offset(0, -screenHeight * 0.22),
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _scaleAnimation = Tween<double>(begin: _currentScale, end: 0.96).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _opacityAnimation = Tween<double>(begin: _currentOpacity, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _shadowAnimation = Tween<double>(begin: _currentShadowProgress, end: 1.0)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    await _animationController.forward(from: 0);
    if (!mounted) return;

    // 2. 扫描 NFC
    setState(() {
      _phase = 'writing';
      _dragOffset = Offset(0, -screenHeight * 0.22);
    });

    NfcWriteResult result;
    try {
      result = await NfcService.instance
          .writeCardId(widget.item)
          .timeout(
            _nfcTimeout,
            onTimeout: () => const NfcWriteResult(
              status: NfcWriteStatus.tagNotFound,
              message: '未检测到 NFC 卡片，请重试',
            ),
          );
    } catch (error) {
      result = NfcWriteResult(
        status: NfcWriteStatus.writeFailed,
        message: '写入失败：$error',
        error: error,
      );
    }
    if (!mounted) return;

    if (result.isSuccess) {
      // 3a. 成功：卡片继续飞出屏幕，然后打开详情页
      setState(() => _phase = 'closing');
      _animationController.duration = _exitDuration;
      _slideAnimation =
          Tween<Offset>(
            begin: Offset(0, -screenHeight * 0.22),
            end: Offset(0, -screenHeight),
          ).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInCubic,
            ),
          );
      _scaleAnimation = Tween<double>(begin: 0.96, end: 0.90).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInCubic,
        ),
      );
      _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutQuad,
        ),
      );
      _shadowAnimation = Tween<double>(
        begin: 1.0,
        end: 1.0,
      ).animate(_animationController);

      await _animationController.forward(from: 0);

      if (mounted) _openDetailPage();
    } else {
      // 3b. 失败：卡片平滑回到原位，并提示错误
      _showError(result.message);
      setState(() => _phase = 'cancelling');
      _animationController.duration = _snapBackDuration;
      _slideAnimation =
          Tween<Offset>(
            begin: Offset(0, -screenHeight * 0.22),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOutCubic,
            ),
          );
      _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      );
      _opacityAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      );
      _shadowAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      );

      await _animationController.forward(from: 0);
      if (mounted) {
        setState(() {
          _dragOffset = Offset.zero;
          _phase = 'idle';
        });
      }
    }
  }

  void _openDetailPage() {
    void resetCard() {
      if (mounted) {
        _animationController.stop();
        _resetAnimations();
        setState(() {
          _dragOffset = Offset.zero;
          _phase = 'idle';
        });
      }
    }

    if (widget.onTriggerWithReset != null) {
      widget.onTriggerWithReset!(resetCard);
    } else {
      widget.onTrigger?.call();
      Future.delayed(const Duration(milliseconds: 100), resetCard);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ================== 回位 ==================

  Future<void> _animateBackToStart() async {
    final startOffset = _dragOffset;
    setState(() => _phase = 'cancelling');
    _animationController.duration = _snapBackDuration;
    _slideAnimation = Tween<Offset>(begin: startOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _scaleAnimation = Tween<double>(begin: _currentScale, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _opacityAnimation = Tween<double>(begin: _currentOpacity, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _shadowAnimation = Tween<double>(begin: _currentShadowProgress, end: 0.0)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    await _animationController.forward(from: 0);
    if (mounted) {
      setState(() {
        _dragOffset = Offset.zero;
        _phase = 'idle';
      });
    }
  }

  // ================== 辅助属性 ==================

  double get _dragProgress =>
      (-_dragOffset.dy / _triggerThreshold).clamp(0.0, 1.0);

  double get _currentScale => 1.0 - (_dragProgress * 0.08);

  double get _currentOpacity => 1.0 - (_dragProgress * 0.18);

  double get _currentShadowProgress => _dragProgress;

  // ================== UI ==================

  Widget _buildCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景图片
          Image.network(
            widget.item.imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  color: widget.item.color,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: widget.item.color,
                child: const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 60,
                ),
              );
            },
          ),
          // 渐变遮罩
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // 底部文字 + 状态提示
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.item.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                if (_phase == 'writing')
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        '正在写入 NFC...',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  )
                else if (widget.isActive && _phase != 'closing')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 30,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _phase == 'hovering' || _phase == 'writing'
                            ? '上滑写入 NFC · 下滑取消'
                            : '上滑写入 NFC',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 30,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEffect() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final Offset totalOffset = _slideAnimation.value + _dragOffset;
        final double scale = _animationController.isAnimating
            ? _scaleAnimation.value
            : _currentScale;
        final double opacity = _animationController.isAnimating
            ? _opacityAnimation.value
            : _currentOpacity;
        final double shadowProgress = _animationController.isAnimating
            ? _shadowAnimation.value
            : _currentShadowProgress;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: totalOffset,
            child: Transform.scale(
              scale: scale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: widget.item.color.withValues(
                        alpha: 0.32 + (shadowProgress * 0.18),
                      ),
                      blurRadius: 18 + (shadowProgress * 18),
                      spreadRadius: shadowProgress * 2,
                      offset: Offset(0, 10 - (shadowProgress * 4)),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: _handleVerticalDragStart,
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: _handleVerticalDragEnd,
        child: RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            child: _buildCard(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildEffect();
  }
}
