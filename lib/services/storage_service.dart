import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _sessionIdKey = 'session_id';
  static const String _serverCodeKey = 'server_code';
  static const String _vpnConfigKey = 'vpn_config';

  static Future<void> saveSessionId(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdKey, sessionId);
  }

  static Future<String?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionIdKey);
  }

  static Future<void> saveServerCode(String serverCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverCodeKey, serverCode);
  }

  static Future<String?> getServerCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverCodeKey);
  }

  static Future<void> saveVPNConfig(String config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vpnConfigKey, config);
  }

  static Future<String?> getVPNConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_vpnConfigKey);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey);
    await prefs.remove(_serverCodeKey);
    await prefs.remove(_vpnConfigKey);
  }
}