import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../models/CurveOption.dart';

/// 曲线选择对话框
/// 
/// 显示所有可用的曲线选项，并提供实时预览
/// 用户选择后返回曲线的名称（String类型）
/// 
/// 使用方法:
/// ```dart
/// final selectedCurveName = await showCurveSelectorDialog(
///   context,
///   currentCurveName: 'easeInSine',
///   title: '选择动画曲线',
/// );
/// if (selectedCurveName != null) {
///   // 使用选中的曲线名称
///   print('选中的曲线: $selectedCurveName');
/// }
/// ```
Future<String?> showCurveSelectorDialog(
  BuildContext context, {
  String? currentCurveName,
  String? title,
  bool showPreview = true,
}) async {
  return await Get.dialog<String>(
    CurveSelectorDialog(
      currentCurveName: currentCurveName,
      title: title,
      showPreview: showPreview,
    ),
    barrierDismissible: true,
  );
}

/// 曲线选择对话框 Widget
class CurveSelectorDialog extends StatefulWidget {
  /// 当前选中的曲线名称
  final String? currentCurveName;
  
  /// 对话框标题
  final String? title;
  
  /// 是否显示预览区域
  final bool showPreview;

  const CurveSelectorDialog({
    Key? key,
    this.currentCurveName,
    this.title,
    this.showPreview = true,
  }) : super(key: key);

  @override
  State<CurveSelectorDialog> createState() => _CurveSelectorDialogState();
}

class _CurveSelectorDialogState extends State<CurveSelectorDialog>
    with SingleTickerProviderStateMixin {
  late String? selectedCurveName;
  late AnimationController _previewController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    selectedCurveName = widget.currentCurveName;
    _scrollController = ScrollController();
    
    // 初始化预览动画控制器
    _previewController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _previewController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = CurveOption.getAllCategories();

    return Dialog(
      child: Container(
        width: 0.8.sw,
        height: 0.8.sh,
        padding: EdgeInsets.all(48.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title ?? '选择曲线',
                  style: TextStyle(
                    fontSize: 56.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 64.w),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            SizedBox(height: 32.w),

            // 预览区域
            if (widget.showPreview && selectedCurveName != null)
              _buildPreviewSection(),

            SizedBox(height: 32.w),

            // 曲线列表
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final curvesInCategory =
                      CurveOption.getCurvesByCategory(category);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 分类标题
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 24.w,
                          horizontal: 32.w,
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 48.sp,
                            fontWeight: FontWeight.bold,
                            color: Get.theme.primaryColor,
                          ),
                        ),
                      ),

                      // 该分类下的曲线选项
                      ...curvesInCategory.map(
                        (option) => _buildCurveItem(option),
                      ),

                      SizedBox(height: 32.w),
                    ],
                  );
                },
              ),
            ),

            SizedBox(height: 32.w),

            // 底部按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: Text(
                    '取消',
                    style: TextStyle(fontSize: 44.sp),
                  ),
                ),
                SizedBox(width: 32.w),
                ElevatedButton(
                  onPressed: () => Get.back(result: selectedCurveName),
                  child: Text(
                    '确定',
                    style: TextStyle(fontSize: 44.sp),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建预览区域
  Widget _buildPreviewSection() {
    final option = CurveOption.findByName(selectedCurveName!);
    if (option == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(48.w),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(24.w),
        border: Border.all(
          color: Get.theme.dividerColor,
          width: 2.w,
        ),
      ),
      child: Column(
        children: [
          Text(
            '预览: ${option.displayName}',
            style: TextStyle(
              fontSize: 48.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24.w),
          Text(
            option.description,
            style: TextStyle(
              fontSize: 40.sp,
              color: Get.theme.textTheme.bodySmall?.color,
            ),
          ),
          SizedBox(height: 48.w),

          // 动画预览
          SizedBox(
            height: 200.w,
            child: AnimatedBuilder(
              animation: _previewController,
              builder: (context, child) {
                final curvedValue =
                    option.curve.transform(_previewController.value);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 旋转示例
                    Transform.rotate(
                      angle: curvedValue * 2 * pi,
                      child: Container(
                        width: 120.w,
                        height: 120.w,
                        decoration: BoxDecoration(
                          color: Get.theme.primaryColor,
                          borderRadius: BorderRadius.circular(24.w),
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 80.w,
                        ),
                      ),
                    ),

                    // 位置移动示例
                    Container(
                      width: 400.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: Get.theme.dividerColor,
                        borderRadius: BorderRadius.circular(20.w),
                      ),
                      child: Align(
                        alignment:
                            Alignment(-1 + curvedValue * 2, 0),
                        child: Container(
                          width: 80.w,
                          height: 80.w,
                          decoration: BoxDecoration(
                            color: Get.theme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),

                    // 缩放示例
                    Transform.scale(
                      scale: 0.5 + curvedValue * 0.5,
                      child: Container(
                        width: 120.w,
                        height: 120.w,
                        decoration: BoxDecoration(
                          color: Get.theme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建单个曲线选项
  Widget _buildCurveItem(CurveOption option) {
    final isSelected = selectedCurveName == option.name;

    return InkWell(
      onTap: () {
        setState(() {
          selectedCurveName = option.name;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 48.w,
          vertical: 32.w,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Get.theme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected
                  ? Get.theme.primaryColor
                  : Colors.transparent,
              width: 8.w,
            ),
          ),
        ),
        child: Row(
          children: [
            // 选中指示器
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Get.theme.primaryColor
                      : Get.theme.dividerColor,
                  width: 4.w,
                ),
                color: isSelected ? Get.theme.primaryColor : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 32.w,
                    )
                  : null,
            ),

            SizedBox(width: 32.w),

            // 曲线信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.displayName,
                    style: TextStyle(
                      fontSize: 48.sp,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: 8.w),
                  Text(
                    option.description,
                    style: TextStyle(
                      fontSize: 40.sp,
                      color: Get.theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),

            // 曲线名称标签
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 12.w,
              ),
              decoration: BoxDecoration(
                color: Get.theme.dividerColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12.w),
              ),
              child: Text(
                option.name,
                style: TextStyle(
                  fontSize: 36.sp,
                  fontFamily: 'monospace',
                  color: Get.theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
