<div align=center>

<h1>Kazumi TV 兼容版</h1>


## 社区 TV 兼容性构建声明

本仓库是对 Kazumi 做的 TV 端兼容改造。明确声明：“是对kazimu做的tv端兼容改造。原项目版权、代码与维护归属于上游项目作者及贡献者。 本仓库仅为社区兼容性构建与分发用途。”

上游项目：[Predidit/Kazumi](https://github.com/Predidit/Kazumi)。本仓库保留原项目的 GPL-3.0 许可证、美术资源版权、赞助及全部感谢声明；以下原项目介绍与声明继续保留。TV 改动经过组件测试与小米盒子实机验证。本构建不是上游官方发行版。

[下载社区 TV 最新版](https://github.com/liuliuhong/Kazumi/releases/latest) · [2026-10-06 发布说明](docs/releases/tv-2026.10.06.md)

## 支持平台

- 目前仅测试 HyperOS 3.0.2.0、Android 14、32 位 ARM


## 本分支的 Android TV 适配

TV 构建使用独立包名 `com.predidit.kazumi.tv`，与普通版共存。加入电视启动入口、横屏、遥控器焦点提示、播放控制栏和选集面板导航。TV 默认使用 MediaCodec 硬件解码，普通缓存上限为 64 MiB；已有的低内存策略仍然生效。TV 版不会从原版应用更新渠道下载 APK。

Windows 上可以使用本仓库的 PowerShell 脚本准备便携开发环境，默认存放到 `D:\KazumiToolchain`，不修改系统 PATH：

```powershell
./tools/setup-android.ps1
./tools/test-tv.ps1
./tools/build-tv.ps1
```

APK 输出为 `build/tv/Kazumi-TV-arm-release.apk`，包含 ARM 32 位和 64 位。当前构建沿用项目的本机开发签名，用于侧载测试。一般安卓构建仍使用原有包名；也可以手动执行 `flutter build apk --release --dart-define=KAZUMI_TV=true --target-platform=android-arm,android-arm64` 生成 TV 版。

播放时，确定键唤出控制栏，再次确定执行当前按钮；控制栏显示时方向键移动焦点，隐藏时左右键快退／快进 10 秒。返回键先关闭控制栏或选集面板，再退出播放。音量键保留系统行为。

TV 搜索按钮使用 Android 原生输入对话框，兼容小米盒子的搜狗 TV 输入法。自行编译时没有上游镜像的签名凭据，搜索和受保护的评论接口会使用 Bangumi 官方公开接口；无需获取上游私有凭据。

TV 输入框使用方向键移动焦点，按确定才打开原生输入窗口；取消输入保留当前页面。输入框获得焦点时，返回键先离开输入框，再次返回才关闭页面。设置的左右两栏可使用左右键切换。

TV 模式禁用桌面的字母键、组合键快捷操作，保留遥控器方向、确定、返回和媒体键。追番页面支持分类、列表和网格卡片的焦点导航；状态菜单打开后，返回键只收起菜单并回到按钮。

下拉菜单打开后会自动聚焦第一个可操作选项，配色方案卡片支持方向键和确定键。设置进度条默认只参与焦点导航：上下选择其他设置项，左键回到设置侧栏；按确定进入调整状态，左右减小／增大，按返回结束调整并保留当前页。

主界面左栏上下移动到边界后停住，右键进入内容区。离线下载的每集播放和删除按钮可分别聚焦，删除仍需二次确认。播放侧栏的评论页可向下选中“阅读评论”，使用上下键滚动正文；滚回顶部后再按上键回到工具栏。

弹弹 play 接口需要应用凭证，源码不包含上游 CI 的私有凭证。可在“设置 → 弹幕设置 → 弹幕 API 凭证”填写自己从[弹弹 play 开放平台](https://doc.dandanplay.com/open/)申请的 AppId / AppSecret，或者构建时注入 `DANDANAPI_APPID` / `DANDANAPI_KEY`。盒子上的密钥使用 Android Keystore 加密后保存，不进入设置同步。缺少凭证时来源页会明确提示原因；配置有效凭证后，打开来源页自动检索当前番剧，实际结果取决于接口收录情况。

已在 MiTV-AZFU0（HyperOS 3.0.2.0、Android 14、32 位 ARM）侧载实测：遥控搜索、搜狗 TV 输入法、来源选择、视频画面、暂停／恢复、10 秒快进、选集及换集。部分源站检索和弹幕接口仍可能失败，音频输出与长时间播放稳定性需继续实机验证。

`tools/test-tv.ps1` 在忽略的临时目录中测试实际 TV 组件，以避免安卓开发环境额外依赖 Windows C++ 工具；项目完整测试在 Windows 下仍需满足 `ech_http` 的原生构建要求。

### 2026-10-06 全部改动列表

基于 Kazumi 2.3.7（20307），包含当天各轮修复的最终结果：

- **TV 构建与入口**：增加 TV 模式检测和 `KAZUMI_TV` 构建开关、独立包名、Leanback 启动入口、电视横幅、固定横屏及无触屏设备兼容；普通构建继续使用原有包名。
- **遥控基础操作**：增加可见焦点框及方向、确定、返回、媒体键处理；TV 模式禁用桌面字母和组合快捷键，支持遥控器确定键和手柄确认键。
- **主界面左栏**：侧栏内部上下导航在首尾停住，右键进入内容区，修复连续下键从“我的”泄漏到右侧列表的问题。
- **播放器控制栏**：支持暂停、恢复、快进、快退、上下集、弹幕、选集和线路；隐藏控制栏时左右跳转 10 秒。返回先关闭控制栏或侧栏，再退出视频，修复返回同时退出播放的问题。
- **选集和线路面板**：打开后建立独立焦点范围、聚焦可操作控件，关闭后恢复播放器焦点；支持遥控选集与换集。
- **评论阅读**：评论页新增“阅读评论”入口，上下键滚动长评论列表；回到顶部后上键返回工具栏，也可继续选择正文内的交互控件。
- **离线下载**：每集的播放与删除按钮分别接受焦点和确认操作，删除保留二次确认，修复只能播放不能选择删除的问题。
- **追番页面**：修复右侧内容区无法获得焦点的问题，支持分类、网格和列表卡片导航；移除 TV 页面中干扰方向键的桌面快捷键焦点层。
- **输入和返回层级**：新增 Android 原生 TV 输入对话框，兼容搜狗 TV 输入法；方向键用于页面导航，确认进入输入；取消输入保留页面，返回先离开输入状态，再关闭上一级。覆盖搜索、设置和弹幕来源输入场景。
- **设置两栏导航**：左键返回设置分类侧栏，右键进入设置内容并恢复焦点，修复进入内容后无法返回分类的问题。
- **弹出菜单和配色**：深色模式、界面设置、追番状态等菜单打开后自动进入独立焦点范围；返回只关闭菜单并恢复入口焦点。配色方案卡片支持遥控移动与确认。
- **设置进度条**：下载、播放、弹幕及弹幕时间偏移统一采用“确认后调整”模式；默认上下选择其他项、左键返回分类；确认后左右调整，返回结束调整，避免进度条吞掉上下导航。
- **弹幕来源与凭证**：修复来源页焦点和输入取消行为；缺少应用凭证时明确说明原因，支持设置 AppId / AppSecret 或构建注入。设备密钥由 Android Keystore 加密保存，不参与设置同步。源码不包含上游私有凭证。
- **搜索与评论接口**：未配置上游镜像签名凭据时回退到 Bangumi 官方公开接口，降低社区构建对私有凭据的依赖。
- **电视播放与更新**：TV 默认 MediaCodec 硬件解码、64 MiB 普通播放缓存，保留低内存策略；禁用原版 APK 自动更新和初次启动的原版更新检查，避免社区 TV 包被普通版替换。
- **构建和验证工具**：新增便携 Flutter、JDK、Android SDK 环境准备、TV 编译和组件测试 PowerShell 脚本；忽略本地缓存与 Kotlin 临时产物。新增播放器、侧栏、输入、菜单、进度条、侧栏边界与长评论滚动测试。

最新版 APK 包含 ARM 32 位和 ARM 64 位，已在小米盒子（HyperOS 3.0.2.0 / Android 14 / 32 位 ARM）安装并验证上述主要遥控流程。删除流程实测到确认弹窗并取消，未删除用户文件。10 个 TV 组件测试通过；完整 Windows 测试仍需要 `ech_http` 的 C++ 构建环境。未配置有效弹弹 play 凭证，因此不宣称弹幕加载已完成实机验证；音频和长时间播放稳定性仍需继续验证。

## 屏幕截图

<table>
  <tr>
    <td><img alt="homepage" src="static/screenshot/img_1.png"></td>
    <td><img alt="timetable" src="static/screenshot/img_2.png"></td>
    <td><img alt="details" src="static/screenshot/img_3.png"></td>
  <tr>
  <tr>
    <td><img alt="selection-page" src="static/screenshot/img_4.png"></td>
    <td><img alt="rules-mange" src="static/screenshot/img_5.png"></td>
    <td><img alt="rules-edit" src="static/screenshot/img_6.png"></td>
  <tr>
</table>

## 功能 / 开发计划

- [X]  规则编辑器
- [X]  番剧目录
- [X]  番剧搜索
- [X]  番剧时间表
- [X]  番剧字幕
- [X]  分集播放
- [X]  视频播放器
- [X]  多视频源支持
- [X]  规则分享
- [X]  硬件加速
- [X]  高刷适配
- [X]  追番列表
- [X]  番剧弹幕
- [X]  在线更新
- [X]  历史记录
- [X]  倍速播放
- [X]  配色方案
- [X]  跨设备同步
- [X]  无线投屏 (DLNA)
- [X]  外部播放器播放
- [X]  超分辨率
- [X]  一起看
- [X]  番剧下载
- [ ]  番剧更新提醒
- [ ]  还有更多 (/・ω・＼)

## 下载

社区 TV 版请通过本仓库 [Releases](https://github.com/liuliuhong/Kazumi/releases/latest) 下载 APK。上游普通版继续通过 [上游 Releases](https://github.com/Predidit/Kazumi/releases/latest) 下载；以下 F-Droid 和 Linux 分发入口属于上游普通版。

<a href="https://github.com/liuliuhong/Kazumi/releases">
  <img src="static/svg/get_it_on_github.svg" alt="Get it on Github" width="200"/>
</a>

### Android

<a href="https://f-droid.org/packages/com.predidit.kazumi">
  <img src="https://fdroid.gitlab.io/artwork/badge/get-it-on-zh-hans.svg"
  alt="Get it on F-Droid" width="200">
</a>

### GNU/Linux

<a href="https://flathub.org/apps/io.github.Predidit.Kazumi">
  <img src="https://flathub.org/api/badge?svg&locale=zh-Hans" alt="Get it on Flathub" width="175"/>
</a>




## 美术资源

本项目图标来自 [Yuquanaaa](https://www.pixiv.net/users/66219277) 发表在 [Pixiv](https://www.pixiv.net/artworks/116666979) 上的作品。

此图标由其原作者 [Yuquanaaa](https://www.pixiv.net/users/66219277) 拥有版权。我们已获得原作者的授权和许可, 可以在本项目中使用这一图标。这一图标不是自由使用的, 未经原作者明确授权, 任何人不得擅自使用、复制、修改或分发这一图标。

本项目内嵌字体为 [Mi Sans](https://hyperos.mi.com/font/zh/details/sc/) 字体, 由 [Xiaomi](https://www.mi.com/index.html) 开发和拥有版权。

## 免责声明

本项目基于 GNU 通用公共许可证第 3 版（GPL-3.0）授权。我们不对其适用性、可靠性或准确性作出任何明示或暗示的保证。在法律允许的最大范围内, 作者和贡献者不承担任何因使用本软件而产生的直接、间接、偶然、特殊或后果性的损害赔偿责任。

使用本项目需遵守所在地法律法规, 不得进行任何侵犯第三方知识产权的行为。因使用本项目而产生的数据和缓存应在24小时内清除, 超出 24 小时的使用需获得相关权利人的授权。

## 隐私政策

我们不收集任何用户数据, 不使用任何遥测组件。

## 代码签名策略

以下为上游原有签名策略。社区 TV APK 当前使用本机开发签名侧载，与上游官方签名不同；自行编译的签名也可能不同。

提交者: [贡献者](https://github.com/Predidit/Kazumi/graphs/contributors)
审阅者: [所有者](https://github.com/Predidit)

## 赞助


| ![signpath](https://signpath.org/assets/favicon-50x50.png)                                                                                                                      | Free code signing on Windows provided by[SignPath.io](https://about.signpath.io/), certficate by [SignPath Foundation](https://signpath.org/) |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| <img src="https://kilo.ai/favicon/favicon.svg" width="50">                                                                                                                      | **Automatic PR review provided by [Kilo Code](https://kilo.ai/), sponsored by the [Kilo OSS Program](https://kilo.ai/oss)**                   |
| <a href="https://m.do.co/c/0062035db3e4"><img src="https://opensource.nyc3.cdn.digitaloceanspaces.com/attribution/assets/SVG/DO_Logo_icon_blue.svg" width="50" height="50"></a> | **Cloud infrastructure is supported by [DigitalOcean](https://m.do.co/c/0062035db3e4)**                                                       |

## 致谢

特别感谢 Predidit kazumi 是目前最优秀的动漫观看平台，这使得我愿意创建这个兼容性副本仓库

特别感谢 [XpathSelector](https://github.com/simonkimi/xpath_selector) 这个优秀的项目是本项目的基石。

特别感谢 [弹弹play](https://www.dandanplay.com/) 本项目使用了 弹弹play开放平台 以提供弹幕交互。

特别感谢 [Bangumi](https://bangumi.tv/) 本项目使用了 Bangumi 开放 API 以提供番剧元数据。

特别感谢 [Anime4K](https://github.com/bloc97/Anime4K) 本项目使用 Anime4K 进行实时超分。

特别感谢 [SyncPlay](https://github.com/Syncplay/syncplay) 本项目使用 SyncPlay 协议并通过 SyncPlay 公共服务器实现一起看功能。

特别感谢 [所有贡献者](https://github.com/Predidit/Kazumi/graphs/contributors) 本项目因为你们变得更好。

特别感谢 [trace.moe](https://trace.moe) 本项目使用了 trace.moe 提供的图片识别番剧功能。

感谢 [media-kit](https://github.com/media-kit/media-kit) 本项目跨平台媒体播放能力来自 media-kit。

感谢 [avbuild](https://github.com/wang-bin/avbuild) 本项目使用了来自 avbuild 的树外补丁实现非标准视频流播放。

感谢 [hive](https://github.com/isar/hive) 本项目持久化储存能力来自 hive。
