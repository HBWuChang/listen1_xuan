
---
## 2.0.0+20
- 删除`EQ调节`功能
- 删除FFmpeg相关功能
- 不再向缓存文件写入封面、标题作者等元数据
- 改`just_audio`为`media_kit`
- macos及ios支持
- 添加音乐缓存命名设置
- 添加部分外观设置
  - 添加自定义颜色设置
- 升级flutter版本至3.35.7
- 添加歌单搜索
- 实现下一首播放模式选择并提供两种模式
- 桌面平台横屏播放栏添加亚克力效果
- 添加了`受限制的`Supabase歌单管理功能
## 1.1.4+19
- 安卓添加EQ音效调节功能
- 竖屏播放底栏鼠标拖动
  ~~~dart
  <!-- packages\smooth_sheets-0.15.0\lib\src\draggable.dart #87 -->
  () => VerticalDragGestureRecognizer(
                debugOwner: kDebugMode ? runtimeType : null,
                supportedDevices: const {
                  PointerDeviceKind.mouse, // 添加鼠标拖动
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                  PointerDeviceKind.trackpad,
                },
              ),
    ~~~
- 竖屏播放底栏集成控制、歌词，可上滑展开
- 竖屏底栏播放按钮添加环形进度条，可在外观设置修改旋转曲线及旋转速度
- 修复/优化
  - 优化~~没什么卵用的~~`HoverFollowWidget`性能
  - 优化正在播放列表性能
    ~~~dart
      child: ReorderableListView.builder(
          scrollController: controller.scrollController,
          buildDefaultDragHandles: false,
          padding: EdgeInsets.symmetric(horizontal: 16),
    +      prototypeItem: _buildTrackItem(
    +        context,
    +        playingList.first,
    +        0,
    +        playingList.first.id == currentTrackId,
    +        controller,
    +      ),
          itemCount: playingList.length,
    ~~~
  - 添加优化wintaskbar异常捕获
  - 优化竖屏歌词性能--stack三明治+ClipPath代替直接放到sheet中


## 1.1.3+18
- 添加WebSocket功能
  - 可基本控制服务端音乐播放
  - 可下载服务端缓存文件到本地
  - 可获取服务端的各平台登录
  - 可在歌曲弹窗中发送歌曲到服务端播放（当已连接WebSocket服务器时显示按钮）
- 添加分享功能 ~~（目前学习意义大于实用意义~~
  - 可从链接打开应用
- 优化设置页面布局
- 调整主题颜色
- win添加可记忆窗口大小选项
- android添加在通知中显示歌词功能（目前是通过直接更改displayTitle实现的；虽然通知更改成功，但在朋友车机上测试并没有卵用，据朋友说其车机只有汽水音乐可显示歌词；继续改进遇到现实阻力 ~~我没车（机）~~
~~~dart
if (lyric != null) {
  if (_currentMediaItem == null) return;
  MediaItem _item = _currentMediaItem!.copyWith(
    displayTitle: lyric.mainText,
    // displaySubtitle: lyric.extText,
  );
  if (Get.find<SettingsController>().showLyricTranslation.value) {
    _item = _item.copyWith(
      displaySubtitle: lyric.hasExt ? lyric.extText : null,
    );
  }
  (Get.find<AudioHandlerController>().audioHandler as AudioPlayerHandler)
      .change_playbackstate(_item);
    return;
}
~~~
- 图标感谢[Chris蒂娜じゃない](https://space.bilibili.com/104313435)
- 修改~~应该是~~所有的消息样式
## 1.1.1+15
- 添加下载功能，windows若原无ffmpeg则可在设置中下载（由于封了个ffmpeg导致安卓安装包变大了两倍多QAQ）
- 添加WebSocket功能，可远控另一台设备播放及播放指定歌曲
## 1.1.0+14
- 添加歌词页面，点击播放栏的封面图打开
- 添加正在播放列表
- 由于升级了构建Flutter版本导致原有自动适配三大金刚键的逻辑失效，现已添加设置项可手动设置竖屏下播放栏下方占位高度
- 修复播放闪退
- 存储部分大量换用Get控制
## 1.0.3+13
- 可自选主题色
- 播放区域添加设置播放模式按钮
## 1.0.1+10
- Windows平台支持
- 适配横屏
- 修复部分bug
## 1.0.1+9
- 大幅更改页面切换逻辑
- 去除歌单的标题滚动效果，大幅提升性能
- 发布及actions将生成分架构安装包，减小安装包体积
- 修复部分bug
## 1.0.0+7
- 酷狗音乐源可用（但无法登录账号~~原Listen1就没有实现~~
- QQ音乐登录会员可用
- 土法手搓音乐列表滚动条
- 设置添加“禁用ssl证书验证”开关
- 歌曲弹窗可长按复制作者、专辑、链接或点击“搜索此音乐”快速搜索歌名
- 返回主页后一秒内两次返回可退出应用
## 1.0.0+6
- 可使用Github同步歌单
- 修复歌单区域显示不全的bug
## 1.0.0+5
- QQ音乐可用
- 随系统自适应暗色
- 修复断网导致音乐停止播放
- 增加应用内音量调节
- 增加清除音乐缓存功能
#### 登陆状态不会储存到配置文件中，不同设备需分别登录
## 1.0.0+4
- 网易云歌单可用
## 1.0.0+3
- 左右滑动下方音乐控制条可切换上一首下一首（震动反馈
- 点击音乐控制条可显示当前歌曲信息
- 长按音乐控制条可切换播放模式（震动反馈
- 双击音乐控制条可暂停/播放（震动反馈
- 创建歌单内歌曲可拖动排序
- 可查看网易云歌曲的专辑及歌手对应歌曲
## 1.0.0+2
- 现在可以读取listen1导出的配置文件及导出配置文件
- 修复部分播放模式bug
- 改善随机模式逻辑
## 1.0.0
- 可以登录哔哩哔哩和网易云账号
- 可以搜索哔哩哔哩和网易云音乐
- 可以查看哔哩哔哩收藏夹和订阅
- 可查看哔哩哔哩和网易云歌单
- 请现在右上角设置输入哔哩哔哩cookie和登录网易云账号
- 输入哔哩哔哩cookie需扫码，可将网址在电脑打开或手机开小窗投屏：https://[mashir0-bilibili-qr-login.hf.space](https://mashir0-bilibili-qr-login.hf.space/)/
- 在未输入哔哩哔哩cookie时进入主页会报错（暂时没有判断
~~**通知中的白色方框为切换播放模式按钮**~~ 当点击按钮时会弹出当前播放模式（循环、随机、单曲）（但是在通知页面无法查看，需关闭通知页面（试过自定义图标但还没有成功QwQ
