part of '../../main.dart';

void _showFilterSelection(
  BuildContext context,
  Map<String, dynamic> filter,
  dynamic now_id,
  Function change_fliter,
) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择过滤器',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Divider(),
            Expanded(
              child: ListView(
                children: filter.entries.map<Widget>((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: entry.value.map<Widget>((filterItem) {
                          return FilterChip(
                            label: Text(filterItem['name']),
                            onSelected: (bool selected) {
                              // 处理过滤器选择逻辑
                              change_fliter(
                                filterItem['id'],
                                filterItem['name'],
                              );
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16.0),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _clickCloseBtn() {
  showTriStateConfirmDialog(
    title: '请选择默认操作',
    message: '关闭应用还是隐藏到托盘？',
    currentValue: Get.find<SettingsController>().windowsCloseBtnCloseOrHideApp,
    confirmText: '关闭应用',
    rejectText: '隐藏到托盘',
    autoRem: true,
    onRemember: (value) {
      // 用户勾选"记住选择"时保存设置
      Get.find<SettingsController>().windowsCloseBtnCloseOrHideApp = value;
    },
  ).then((value) async {
    if (value == null) return;
    if (value == true) {
      closeApp();
    } else {
      windowManager.hide();
      windowManager.setSkipTaskbar(true);
    }
  });
}
