import 'constants.dart';

/// 关于信息：版本号与本地运行声明，设置页与首页共用。
String aboutLine() =>
    '${AppConstants.appName} v${AppConstants.version} · 本地运行，无需联网';

/// 首页底部的简短版本行。
String versionLine() => 'v${AppConstants.version} · 本地运行，无需联网';
