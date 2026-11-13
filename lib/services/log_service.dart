/// 日志服务：IO 平台落盘，Web 平台只保留内存日志。
library;

export 'log_service_io.dart'
    if (dart.library.js_interop) 'log_service_web.dart';
