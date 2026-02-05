/// Represents an installed Android application for VPN filtering.
class AppInfo {
  final String packageName;
  final String appName;
  final String? iconBase64;

  const AppInfo({
    required this.packageName,
    required this.appName,
    this.iconBase64,
  });

  factory AppInfo.fromMap(Map<String, dynamic> map) {
    return AppInfo(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      iconBase64: map['iconBase64'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'appName': appName,
      'iconBase64': iconBase64,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppInfo && other.packageName == packageName;
  }

  @override
  int get hashCode => packageName.hashCode;

  @override
  String toString() => 'AppInfo(packageName: $packageName, appName: $appName)';
}
