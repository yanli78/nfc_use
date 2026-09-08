import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nfc_use/core/constants/card_item.dart';
import 'package:nfc_use/core/services/nfc_service.dart';

/// 交互式画廊卡片组件
///
/// 实现卡片的上滑写入NFC、下滑取消、悬停动画等交互效果。
/// 支持手势拖动、动画过渡、NFC写入状态反馈等功能。
class InteractiveGalleryCard extends StatefulWidget {
  /// 卡片数据对象
  final CardItem item;

  /// 触发回调（不带重置函数）
  final VoidCallback? onTrigger;

  /// 是否为当前激活的卡片（居中显示的卡片）
  final bool isActive;

  /// 触发回调（带重置函数），用于卡片飞出后重置状态
  final Function(Function resetCard)? onTriggerWithReset;

  /// 创建交互式画廊卡片
  ///
  /// [item] 卡片数据对象
  /// [onTrigger] 触发回调（可选）
  /// [isActive] 是否为激活状态（默认false）
  /// [onTriggerWithReset] 带重置函数的触发回调（可选）
  const InteractiveGalleryCard({
    super.key,
    required this.item,
    this.onTrigger,
    this.isActive = false,
    this.onTriggerWithReset,
  });

  /// 公开静态方法，通过GlobalKey触发卡片上滑动画
  ///
  /// [key] 卡片组件的GlobalKey
  static void triggerAnimation(GlobalKey key) {
    final state = key.currentState as _InteractiveGalleryCardState?;
    if (state != null && state.mounted) {
      state.triggerCardAnimation();
    }
  }

  @override
  State<InteractiveGalleryCard> createState() => _InteractiveGalleryCardState();
}

/// 交互式画廊卡片状态类
///
/// 管理卡片的动画控制器、手势状态、滑动偏移等内部状态。
class _InteractiveGalleryCardState extends State<InteractiveGalleryCard>
    with SingleTickerProviderStateMixin {
  /// 动画控制器，用于驱动各种卡片动画
  late AnimationController _animationController;

  /// 滑动偏移动画
  late Animation<Offset> _slideAnimation;

  /// 缩放动画
  late Animation<double> _scaleAnimation;

  /// 透明度动画
  late Animation<double> _opacityAnimation;

  /// 阴影动画
  late Animation<double> _shadowAnimation;

  /// 当前拖动偏移量
  Offset _dragOffset = Offset.zero;

  /// 卡片交互状态机：idle/dragging/hovering/writing/closing/cancelling
  String _phase = 'idle';

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  /// 初始化动画控制器和动画对象
  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: kCardHoverDuration,
    );
    _resetAnimations();
  }

  /// 重置所有动画对象到初始状态
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

  // ================== 手势处理 ==================

  /// 处理垂直拖动开始事件
  ///
  /// 仅在卡片处于激活状态且非写入/关闭阶段时响应
  void _handleVerticalDragStart(DragStartDetails details) {
    if (!widget.isActive) return;
    if (_phase == 'writing' || _phase == 'closing') return;
    _animationController.stop();
    setState(() {
      _phase = 'dragging';
    });
  }

  /// 处理垂直拖动更新事件
  ///
  /// 根据拖动方向和距离更新卡片位置，支持向上拖动和向下推回原位
  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!widget.isActive) return;
    if (_phase != 'dragging') return;

    if (details.delta.dy < 0) {
      setState(() {
        final nextOffset = _dragOffset.dy + details.delta.dy;
        _dragOffset = Offset(0, nextOffset.clamp(-kCardMaxDragDistance, 0));
      });
    } else {
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

  /// 处理垂直拖动结束事件
  ///
  /// 根据拖动距离和速度判断是触发NFC写入还是回弹原位
  Future<void> _handleVerticalDragEnd(DragEndDetails details) async {
    if (!widget.isActive) return;
    if (_phase != 'dragging') return;

    final double dragDistance = -_dragOffset.dy;
    final bool isFastSwipe =
        details.primaryVelocity != null &&
        details.primaryVelocity! < -kCardSwipeVelocityThreshold;

    if (dragDistance > kCardSwipeTriggerThreshold || isFastSwipe) {
      await _triggerAction();
    } else {
      await _animateBackToStart();
    }
  }

  // ================== 对外接口 ==================

  /// 触发卡片上滑动画（对外公开方法）
  ///
  /// 通常由父组件通过GlobalKey调用此方法
  void triggerCardAnimation() {
    if (!widget.isActive) return;
    if (_phase == 'writing' || _phase == 'closing') return;
    _triggerAction();
  }

  // ================== 核心交互流程：上滑 => NFC => 详情页 ==================

  /// 触发卡片核心操作流程
  ///
  /// 完整流程：
  /// 1. 卡片悬停到上方位置
  /// 2. 执行NFC写入操作
  /// 3a. 成功：卡片飞出屏幕，打开详情页
  /// 3b. 失败：卡片回弹原位，显示错误提示
  Future<void> _triggerAction() async {
    if (_phase == 'writing' || _phase == 'closing') return;

    final screenHeight = MediaQuery.sizeOf(context).height;
    final startOffset = _dragOffset;

    // 步骤1：卡片悬停到上方位置
    setState(() => _phase = 'hovering');
    _animationController.duration = kCardHoverDuration;
    _slideAnimation =
        Tween<Offset>(
          begin: startOffset,
          end: Offset(0, -screenHeight * kCardHoverPositionRatio),
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _scaleAnimation = Tween<double>(begin: _currentScale, end: kCardHoverScale)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
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

    // 步骤2：执行NFC写入操作
    setState(() {
      _phase = 'writing';
      _dragOffset = Offset(0, -screenHeight * kCardHoverPositionRatio);
    });

    NfcWriteResult result;
    try {
      result = await NfcService.instance
          .writeCardId(widget.item)
          .timeout(
            kNfcWriteTimeout,
            onTimeout: () => const NfcWriteResult(
              status: NfcWriteStatus.tagNotFound,
              message: '未检测到NFC卡片，请重试',
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
      // 步骤3a：成功 - 卡片飞出屏幕，打开详情页
      setState(() => _phase = 'closing');
      _animationController.duration = kCardExitDuration;
      _slideAnimation =
          Tween<Offset>(
            begin: Offset(0, -screenHeight * kCardHoverPositionRatio),
            end: Offset(0, -screenHeight),
          ).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInCubic,
            ),
          );
      _scaleAnimation =
          Tween<double>(begin: kCardHoverScale, end: kCardExitScale).animate(
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
      // 步骤3b：失败 - 卡片回弹原位，显示错误提示
      _showError(result.message);
      setState(() => _phase = 'cancelling');
      _animationController.duration = kCardSnapBackDuration;
      _slideAnimation =
          Tween<Offset>(
            begin: Offset(0, -screenHeight * kCardHoverPositionRatio),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOutCubic,
            ),
          );
      _scaleAnimation = Tween<double>(begin: kCardHoverScale, end: 1.0).animate(
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

  /// 打开详情页并设置重置回调
  ///
  /// 当详情页关闭时，通过重置回调恢复卡片状态
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

  /// 显示错误提示消息
  ///
  /// 使用SnackBar在屏幕底部显示错误信息
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ================== 回位动画 ==================

  /// 将卡片动画回退到初始位置
  ///
  /// 用于用户取消操作或NFC写入失败时的恢复动画
  Future<void> _animateBackToStart() async {
    final startOffset = _dragOffset;
    setState(() => _phase = 'cancelling');
    _animationController.duration = kCardSnapBackDuration;
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

  // ================== 辅助计算属性 ==================

  /// 拖动进度（0-1）
  ///
  /// 根据当前拖动距离与触发阈值的比例计算
  double get _dragProgress =>
      (-_dragOffset.dy / kCardSwipeTriggerThreshold).clamp(0.0, 1.0);

  /// 当前缩放比例
  ///
  /// 随着拖动距离增加而减小
  double get _currentScale => 1.0 - (_dragProgress * kCardDragScaleChange);

  /// 当前透明度
  ///
  /// 随着拖动距离增加而降低
  double get _currentOpacity => 1.0 - (_dragProgress * kCardDragOpacityChange);

  /// 当前阴影进度（0-1）
  ///
  /// 与拖动进度一致，用于控制阴影效果
  double get _currentShadowProgress => _dragProgress;

  // ================== UI构建 ==================

  /// 构建卡片主体内容
  ///
  /// 包含背景图片、渐变遮罩、文字内容和状态提示
  Widget _buildCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kCardBorderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackgroundImage(),
          _buildGradientOverlay(),
          _buildCardContent(),
        ],
      ),
    );
  }

  /// 构建卡片背景图片
  Widget _buildBackgroundImage() {
    final imageUrl = widget.item.imageUrl;
    final isRemoteImage =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    if (!isRemoteImage) {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageFallback(),
      );
    }

    return Image.network(
      imageUrl,
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
        return _buildImageFallback();
      },
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: widget.item.color,
      child: const Icon(Icons.broken_image, color: Colors.white, size: 60),
    );
  }

  /// 构建渐变遮罩层
  ///
  /// 从透明渐变到半透明黑色，增强文字可读性
  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  /// 构建卡片内容区域
  ///
  /// 包含标题和状态提示
  Widget _buildCardContent() {
    return Padding(
      padding: kCardDefaultPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(),
          const SizedBox(height: 20),
          _buildStatusIndicator(),
        ],
      ),
    );
  }

  /// 构建卡片标题
  Widget _buildTitle() {
    return Text(
      widget.item.title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// 构建状态指示器
  ///
  /// 根据当前交互状态显示不同的提示内容：
  /// - writing状态：显示"正在写入NFC..."和加载动画
  /// - 其他状态：显示"上滑写入NFC"提示
  Widget _buildStatusIndicator() {
    if (_phase == 'writing') {
      return const Row(
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
            '正在写入NFC...',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      );
    }

    if (widget.isActive && _phase != 'closing') {
      return Row(
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
                ? '上滑写入NFC · 下滑取消'
                : '上滑写入NFC',
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
      );
    }

    return const SizedBox.shrink();
  }

  /// 构建卡片效果层
  ///
  /// 整合动画效果和手势检测，应用滑动、缩放、透明度和阴影变换
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
                  borderRadius: BorderRadius.circular(kCardBorderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: widget.item.color.withValues(
                        alpha:
                            kCardShadowBaseOpacity +
                            (shadowProgress * kCardShadowExpandedOpacity),
                      ),
                      blurRadius:
                          kCardShadowBaseBlurRadius +
                          (shadowProgress * kCardShadowExpandedBlurRadius),
                      spreadRadius: shadowProgress * 2,
                      offset: Offset(
                        0,
                        kCardShadowBaseOffset -
                            (shadowProgress * kCardShadowExpandedOffsetChange),
                      ),
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
          child: Container(margin: kCardDefaultMargin, child: _buildCard()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildEffect();
  }
}
