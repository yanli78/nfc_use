// ==========================================
// 核心：独立的卡片类（后续所有卡片功能都在这里扩展）
// ==========================================
import 'package:flutter/material.dart';

class GalleryCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color color;
  final String imageUrl;
  final VoidCallback? onTrigger; // 滑动触发成功的回调
  final bool isActive; // 是否为当前活跃卡片（只有活跃卡片能滑动）

  const GalleryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.imageUrl,
    this.onTrigger,
    this.isActive = false,
  });

  @override
  State<GalleryCard> createState() => _GalleryCardState();
}

class _GalleryCardState extends State<GalleryCard>
    with SingleTickerProviderStateMixin {
  // 动画相关
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // 手势偏移量
  Offset _dragOffset = Offset.zero;
  // 是否正在触发功能
  bool _isTriggering = false;

  // 触发阈值（滑动超过这个距离就触发功能）
  static const double _triggerThreshold = 150;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  // 初始化动画控制器
  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // 初始时设置默认动画值
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOutBack,
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 手势开始
  void _handleVerticalDragStart(DragStartDetails details) {
    if (!widget.isActive || _isTriggering) return;
    _animationController.stop(); // 停止正在进行的动画
  }

  // 手势更新（卡片跟随手指移动）
  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!widget.isActive || _isTriggering) return;

    // 只允许向上滑动（dy < 0）
    if (details.delta.dy < 0) {
      setState(() {
        _dragOffset += details.delta;
      });
    }
  }

  // 手势结束（判断是回弹还是触发）
  void _handleVerticalDragEnd(DragEndDetails details) async {
    if (!widget.isActive || _isTriggering) return;

    final double dragDistance = -_dragOffset.dy; // 向上滑动的距离（取正值）

    if (dragDistance > _triggerThreshold) {
      // 1. 超过阈值：触发功能
      await _triggerAction();
    } else {
      // 2. 未超过阈值：回弹到原位
      _animateBackToStart();
    }
  }

  // 触发功能的动画
  Future<void> _triggerAction() async {
    setState(() => _isTriggering = true);

    // 定义触发动画：继续向上飞出屏幕，同时缩小、变透明
    _slideAnimation =
        Tween<Offset>(
          begin: _dragOffset,
          end: const Offset(0, -1000), // 向上飞出屏幕
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInBack,
          ),
        );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.5,
    ).animate(_animationController);
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_animationController);

    _animationController.forward(from: 0);

    // 等待动画完成
    await _animationController.forward();

    // 触发回调
    if (widget.onTrigger != null) {
      widget.onTrigger!();
    }

    // 重置状态（为了演示效果，这里延迟重置，实际项目中可能是移除卡片）
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _dragOffset = Offset.zero;
          _isTriggering = false;
        });
        _animationController.reset();
      }
    });
  }

  // 回弹到原位的动画
  void _animateBackToStart() {
    _slideAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOutBack,
          ),
        );

    _animationController.forward(from: 0);

    // 动画完成后重置偏移量
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _dragOffset = Offset.zero);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 计算实时缩放和透明度（跟随手指滑动时变化）
    final double progress = (-_dragOffset.dy / _triggerThreshold).clamp(
      0.0,
      1.0,
    );
    final double currentScale = 1.0 - (progress * 0.1); // 最大缩小到 0.9
    final double currentOpacity = 1.0 - (progress * 0.2); // 最大透明度降到 0.8

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // 合并动画偏移和手势偏移
        final Offset totalOffset = _isTriggering
            ? _slideAnimation.value
            : (_dragOffset + (_slideAnimation.value - Offset.zero));

        return Opacity(
          opacity: _isTriggering ? _opacityAnimation.value : currentOpacity,
          child: Transform.translate(
            offset: totalOffset,
            child: Transform.scale(
              scale: _isTriggering ? _scaleAnimation.value : currentScale,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onVerticalDragStart: _handleVerticalDragStart,
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: _handleVerticalDragEnd,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 背景图片
                Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        color: widget.color,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: widget.color,
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
                        Colors.black.withOpacity(0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // 底部文字 + 提示箭头
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 提示：只有活跃卡片显示滑动提示
                      if (widget.isActive && !_isTriggering)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.keyboard_arrow_up,
                              color: Colors.white.withOpacity(0.8),
                              size: 30,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '上滑查看详情',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.keyboard_arrow_up,
                              color: Colors.white.withOpacity(0.8),
                              size: 30,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
