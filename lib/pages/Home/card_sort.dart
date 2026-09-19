import 'package:flutter/material.dart';
import 'package:nfc_use/core/constants/card_item.dart';
import 'package:nfc_use/core/services/sqlite_service.dart';

/// 卡片排序页面
///
/// 功能：
/// 1. 显示当前所有 CardItem
/// 2. 拖动修改顺序
/// 3. 点击完成后保存到 SQLite
/// 4. 点击取消放弃本次修改
class CardSortPage extends StatefulWidget {
  /// 当前卡片列表
  final List<CardItem> items;

  /// 页面进入方向
  ///
  /// true:
  ///   从左边进入
  ///
  /// false:
  ///   从右边进入
  final bool fromLeft;

  const CardSortPage({super.key, required this.items, this.fromLeft = false});

  @override
  State<CardSortPage> createState() => _CardSortPageState();
}

class _CardSortPageState extends State<CardSortPage> {
  /// 当前正在编辑的列表
  late List<CardItem> _items;

  /// 是否修改过顺序
  bool _hasChanged = false;

  /// 是否正在保存
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // 创建副本，避免直接修改 HomePage 的原列表
    _items = List<CardItem>.from(widget.items);
  }

  // ============================================================
  // 排序
  // ============================================================

  /// 拖动排序
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final CardItem item = _items.removeAt(oldIndex);

      _items.insert(newIndex, item);

      _hasChanged = true;
    });
  }

  // ============================================================
  // 保存
  // ============================================================

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 直接使用你现有的 SQLite 接口
      await CardDatabaseHelper.instance.updateCardOrders(_items);

      if (!mounted) {
        return;
      }

      // 返回当前最新列表
      Navigator.of(context).pop(List<CardItem>.from(_items));
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存排序失败：$e')));
    }
  }

  // ============================================================
  // 取消
  // ============================================================

  void _cancel() {
    if (_isSaving) {
      return;
    }

    Navigator.of(context).pop();
  }

  // ============================================================
  // 卡片缩略图
  // ============================================================

  Widget _buildCardImage(CardItem item) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildImageContent(item),
    );
  }

  Widget _buildImageContent(CardItem item) {
    if (item.imageUrl.trim().isEmpty) {
      return Center(
        child: Icon(Icons.image_outlined, color: item.color, size: 26),
      );
    }

    return Image.network(
      item.imageUrl,
      fit: BoxFit.cover,

      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: item.color),
          ),
        );
      },

      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Icon(Icons.broken_image_outlined, color: item.color, size: 26),
        );
      },
    );
  }

  // ============================================================
  // 单个列表项
  // ============================================================

  Widget _buildCard(BuildContext context, int index) {
    final CardItem item = _items[index];

    return Container(
      key: ValueKey(item.id),

      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

        child: Row(
          children: [
            // ----------------------------------------------------
            // 序号
            // ----------------------------------------------------
            Container(
              width: 32,
              height: 32,

              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),

                borderRadius: BorderRadius.circular(10),
              ),

              alignment: Alignment.center,

              child: Text(
                '${index + 1}',

                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ----------------------------------------------------
            // 图片
            // ----------------------------------------------------
            _buildCardImage(item),

            const SizedBox(width: 14),

            // ----------------------------------------------------
            // 标题
            // ----------------------------------------------------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    item.title,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    item.id,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            // ----------------------------------------------------
            // 拖动图标
            // ----------------------------------------------------
            ReorderableDragStartListener(
              index: index,

              child: Padding(
                padding: const EdgeInsets.all(8),

                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 28,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 空列表
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            size: 64,
            color: Colors.grey[400],
          ),

          const SizedBox(height: 16),

          Text(
            '暂无卡片',

            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
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

      appBar: AppBar(
        backgroundColor: Colors.grey[100],

        surfaceTintColor: Colors.transparent,

        elevation: 0,

        leading: IconButton(
          onPressed: _isSaving ? null : _cancel,

          icon: const Icon(Icons.close_rounded),
        ),

        title: const Text(
          '调整卡片顺序',

          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        actions: [
          TextButton(
            onPressed: (_hasChanged && !_isSaving) ? _save : null,

            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '完成',

                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _hasChanged
                          ? const Color(0xFF00966A)
                          : Colors.grey,
                    ),
                  ),
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          // ------------------------------------------------------
          // 提示
          // ------------------------------------------------------
          Container(
            width: double.infinity,

            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),

            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),

            decoration: BoxDecoration(
              color: const Color(0xFF00966A).withValues(alpha: 0.08),

              borderRadius: BorderRadius.circular(14),
            ),

            child: Row(
              children: [
                const Icon(
                  Icons.swap_vert_rounded,
                  size: 21,
                  color: Color(0xFF00966A),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    '长按右侧拖动按钮即可调整卡片顺序',

                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------
          // 列表
          // ------------------------------------------------------
          Expanded(
            child: _items.isEmpty
                ? _buildEmptyState()
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),

                    itemCount: _items.length,

                    onReorder: _onReorder,

                    buildDefaultDragHandles: false,

                    itemBuilder: (context, index) {
                      return _buildCard(context, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
