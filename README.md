# 血战上海滩 🎯

基于 Flutter + Flame 的本地单机街机射击游戏，支持 Android、Windows 与 Web。
一九三七年的上海街巷，你是守在南岸街垒后的抵抗军士兵：拖动移动、火力自动倾泻、手雷清理装甲车，
在五波敌军中守住阵地，或进入无尽模式比拼得分。

## 玩法

- 🕹️ **操作**：拖动战场任意位置移动士兵，火力自动朝正前方射击；桌面端用 WASD / 方向键移动。
- 💣 **手雷**：按钮或空格投掷，自动飞向最近敌军，12 秒冷却，优先炸装甲车与头目。
- 🎯 **武器**：手枪常驻；弹药箱提供冲锋枪（20 秒）或霰弹枪（16 秒）。
- ❤️ **补给**：急救包回复 30 生命、钢盔提供 6 秒护盾，精英单位更容易掉落。
- 👥 **敌军**：步兵推进、枪手点射、掷弹兵抛雷、装甲车三连发、头目四段弹幕。
- 🏁 **模式**：战役五波通关；无尽模式波次无限，每五波一个头目。
- 🏆 **计分**：连续击杀累积倍率（最高 3 倍），清波与击破头目有额外奖励，战绩保存在本机。

## 特性

- 🎨 **全程序化美术**：街道、屋顶、探照灯、街垒、士兵、战车与爆炸全部由 Canvas 绘制，仓库不存放图片资源。
- 🔊 **全程序化音频**：十种提示音与 8 秒军鼓号声循环在运行时合成，SoLoud 内存音源播放，仓库不存放音频文件。
- ⚡ **固定步长战斗**：逻辑 30 / 60 / 120Hz 可选（默认 60Hz），与渲染刷新解耦；暂停、切后台立即停帧。
- 📱 **自适应布局**：手机 / 折叠屏 / 平板 / Windows 窗口自适应；战场居中，标题与生命在上、得分在右上、
  战况与头目血条浮在战场上方或左侧、控制按钮统一在下方；窄屏自动切换紧凑 HUD。
- 🔄 **按面积选方向**：3:4 的战场在手机上竖屏更大，只有横屏确实能放大战场时才旋转全屏，退出即恢复。
- 🌓 **深色 / 浅色主题**、简体中文、Windows 优先 `Microsoft YaHei UI` 字体、Web 使用 soup_fonts 思源黑体。
- 🧾 **日志落盘**：按天写入用户目录，保留 7 天并在超过 5MB 时轮转；设置页可直接查看日志与打开目录。
- 🚫 **零联网**：没有任何网络请求，成绩与偏好全部保存在本机。

## 下载

v0.1.0：[Gitea Release](http://192.168.31.120:3020/GTech/flutter-battle-in-shanghai/releases/tag/v0.1.0)

| 平台 | 产物 |
| --- | --- |
| Android (arm64, minSdk 35) | `flutter-battle-in-shanghai-0.1.0-android-aarch64.apk` |
| Windows (x64, Win10+) | 待补：v0.1.0 构建时 Windows runner 不在线，任务排队未执行，runner 恢复后补发 |
| Web | `flutter-battle-in-shanghai-0.1.0-web.zip`（解压后起静态服务器） |

在线试玩：<http://192.168.31.120:3020/GTech/flutter-battle-in-shanghai/src/branch/tea-pages>

## 开发

```bash
flutter pub get
flutter analyze
flutter test
```

构建产物由 CI 生成：在 GitHub Actions / Gitea Actions 里手动运行 `build` 工作流并选定 `v*` Tag，
即按该 Tag 的版本构建 Android / Windows / Web 并创建 Release；运行 `main` 则只产出预览产物与调试站点。
音频在运行时合成、Web 字体来自 soup_fonts，仓库不存放字体与音频文件，本地无需安装 Android SDK 等大型工具链。

## 日志位置

| 平台 | 路径 |
| --- | --- |
| Windows | `%USERPROFILE%\Documents\BattleInShanghai\logs\app_YYYYMMDD.log` |
| Android | 应用外部存储目录 `BattleInShanghai/logs/app_YYYYMMDD.log` |
| Web | 仅内存日志，设置页可查看，刷新后清空 |

## 代码结构

```
lib/
├── flame/       Flame 游戏入口与战场渲染组件
├── game/        战斗模拟、实体、波次、配置与控制器
├── models/      战绩模型
├── pages/       首页、战斗页、设置页与悬浮 HUD 组件
├── providers/   偏好状态
├── services/    日志、存储、音效合成与播放
├── theme/       主题与程序化战场美术
└── utils/       布局几何、横竖屏判定、窗口与系统栏
```
