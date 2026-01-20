import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_server.dart';

class StorageService {
  static const String _selectedServerKey = 'selected_server';
  static const String _sessionIdKey = 'session_id';

  static Future<void> saveSelectedServer(VPNServer server) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedServerKey, json.encode(server.toJson()));
  }

  static Future<VPNServer?> getSelectedServer() async {
    final prefs = await SharedPreferences.getInstance();
    final serverJson = prefs.getString(_selectedServerKey);
    if (serverJson != null) {
      return VPNServer.fromJson(json.decode(serverJson));
    }
    return null;
  }

  static Future<void> saveSessionId(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdKey, sessionId);
  }

  static Future<String?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionIdKey);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
