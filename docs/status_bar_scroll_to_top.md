# 页面回顶接入

按 2026-10-14 用户要求，先回退本项目所有 Git 改动并移出旧诊断文件，
确认 Git 状态干净后重新接入。旧源码补丁与未跟踪文件备份位于
/tmp/listen1-scroll-rollback-20261014-144553，未修改同级状态栏插件。

本地依赖：../status_bar_scroll_to_top、../super_sliver_list。
歌单详情 PlaylistInfoPage 使用单层 CustomScrollView，状态栏点击通过同一个 ScrollController.jumpTo(0) 回到页面顶部，普通与排序模式共用该目标。弹窗/底部面板暂不接入，横向列表不处理。

PageScrollToTop 统一注册页面目标：普通滚动直接 jumpTo(0)；
SuperListView 等待 ListController.animateToItem(index: 0) 的 Future，
启用 teleport 与 precalculateTargetItemCount: true。
带前置 padding 的 SuperListView 以首项对齐为顶部，不额外跳动清除 padding。

接入页面：平台歌单目录、我的歌单、搜索歌曲/歌单/电台、当前播放队列、
歌曲替换、均衡器纵向列表、下载、设置、README、提示说明、缓存命名、
播放按钮设置、通知按钮排序、Supabase 两种登录、哔哩哔哩扫码登录、启动页。
搜索三个标签改为 SuperListView.builder，仅当前标签响应；提示说明改为
SuperListView.separated。当前播放排序模式仍使用普通 jumpTo(0)。
SongReplacePage 后续改为单一 CustomScrollView 配合 SuperSliverList，
固定“源歌曲/替换歌曲”标题，其下说明行可滚走，添加区域使用自然高度
PinnedHeaderSliver 固定。状态栏回顶通过唯一 ScrollController.jumpTo(0)。
滚动条的命中区域排除固定添加区域，保留其边缘按钮点击。
既有当前播放歌曲定位 animateToItem 也显式开启预计算。

同级 super_sliver_list 的 animateToItem 返回 Future<void>，包含普通动画、
teleport 后续帧、目标预布局、取消与清理。请求自行管理 ticker，避免
Scrollable 在动画中销毁时出现 active ticker 断言。取消不等于抵达目标，
调用方仍检查最终位置与控制器附着状态。库层清理重定向时避开已销毁的
ListController notifier，避免泄漏或迟到通知。

验证：本项目三项页面回顶测试通过；库五项 Future 测试通过，库修改文件
静态检查无问题。三项既有 teleport 视觉测试通过：原测试使用较新 Flutter
的 ScrollCacheExtent API，本次临时复制为 Flutter 3.41.9 的等价 cacheExtent
参数运行，随后删除副本，原测试文件没有修改。
本项目修改文件没有 analyzer error，既有 warning/info 保留。两仓库 diff
检查通过。Android arm64 debug APK 构建成功。没有运行代码格式化。

当前 adb 没有连接设备，本轮真机验收待完成。
