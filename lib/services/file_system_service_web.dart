/// Web 平台没有本地日志文件，全部能力降级为空实现。
class FileSystemService {
  FileSystemService._();

  static final FileSystemService instance = FileSystemService._();

  Future<String> getLogRootPath() async => '';

  Future<bool> openDirectory(String path) async => false;

  Future<bool> openLogFolder() async => false;
}
