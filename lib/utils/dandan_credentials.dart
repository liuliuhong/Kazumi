// DanDanPlay API credentials for the client signature flow.
// Release/PR CI injects them via --dart-define=DANDANAPI_APPID / DANDANAPI_KEY.
const Map<String, String> _buildCredentials = {
  'id': String.fromEnvironment('DANDANAPI_APPID'),
  'value': String.fromEnvironment('DANDANAPI_KEY'),
};

Map<String, String>? _deviceCredentials;
Map<String, String> get dandanCredentials =>
    _deviceCredentials ?? _buildCredentials;
void setDeviceDandanCredentials(Map<String, String>? credentials) =>
    _deviceCredentials = credentials;
bool get hasDandanCredentials =>
    dandanCredentials.values.every((value) => value.trim().isNotEmpty);
const dandanMissingCredentialsMessage = '未配置弹幕应用凭证，请到“设置 → 弹幕设置 → 弹幕 API 凭证”配置';

class DanmakuCredentialsException implements Exception {
  @override
  String toString() => dandanMissingCredentialsMessage;
}
