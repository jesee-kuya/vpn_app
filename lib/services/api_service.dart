import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/vpn_server.dart';
import '../models/vpn_session.dart';
import '../models/speed_metrics.dart';
import '../models/vpn_status.dart';
import 'package:flutter/foundation.dart';
/*
===========================================
API DOCUMENTATION
===========================================

1. GET /api/servers
   Response: [{"code": "KE", "name": "Kenya", "ip": "41.220.x.x"}]

2. POST /api/vpn/server
   Body: {"serverCode": "KE"}

3. POST /api/vpn/connect
   Body: {"serverCode": "KE"}
   Response: {"sessionId":"uuid", "ip":"xx.xx.xx.xx", "startTime":12345}

4. POST /api/vpn/disconnect
   Body: {"sessionId":"uuid"}

5. GET /api/vpn/speed
   Response: {"download": 24.5, "upload": 7.3, "latency": 42}

6. GET /api/vpn/status
   Response: {"connected": true, "server": "KE", "duration": 248, "ip": "41.220.x.x"}
*/

class ApiService {
  static Future<Map<String, String>> _getHeaders() async {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // 1. GET /api/servers
static Future<List<VPNServer>> getServers() async {
  try {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.serversEndpoint}'),
          headers: await _getHeaders(),
        )
        .timeout(ApiConfig.apiTimeout);

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;

      final List<dynamic> data = decoded['data'];

      return data
          .map((server) => VPNServer.fromJson(server))
          .toList();
    } else {
      throw Exception('Failed to load servers: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Network error: $e');
  }
}

  // 2. POST /api/vpn/server
  static Future<bool> selectServer(String serverCode) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.serverSelectEndpoint}'),
            headers: await _getHeaders(),
            body: json.encode({'serverCode': serverCode}),
          )
          .timeout(ApiConfig.apiTimeout);

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to select server: $e');
    }
  }

  // 3. POST /api/vpn/connect
// 3. POST /api/vpn/connect
static Future<VPNSession> connect(String serverCode) async {
  try {
    final url = '${ApiConfig.baseUrl}${ApiConfig.connectEndpoint}';
    debugPrint('📡 Connecting to: $url');
    debugPrint('📤 Request body: {"serverCode": "$serverCode"}');
    
    final response = await http
        .post(
          Uri.parse(url),
          headers: await _getHeaders(),
          body: json.encode({'serverCode': serverCode}),
        )
        .timeout(ApiConfig.connectTimeout);

    debugPrint('📥 Response status: ${response.statusCode}');
    debugPrint('📥 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body) as Map<String, dynamic>;
      
      debugPrint('🔍 Decoded response: $responseData');
      
      // Extract the 'data' field from the response
      if (responseData['success'] == true && responseData['data'] != null) {
        final data = responseData['data'] as Map<String, dynamic>;
        
        debugPrint('🔍 Data field: $data');
        debugPrint('🔍 Config present: ${data['config'] != null}');
        debugPrint('🔍 SessionId present: ${data['sessionId'] != null}');
        debugPrint('🔍 IP present: ${data['ip'] != null}');
        
        return VPNSession.fromJson(data);
      } else {
        throw Exception('Invalid response format: missing success or data field');
      }
    } else {
      throw Exception('Connection failed: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('❌ Connect error: $e');
    throw Exception('Failed to connect: $e');
  }
}
  // 4. POST /api/vpn/disconnect
  static Future<bool> disconnect(String sessionId) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.disconnectEndpoint}'),
            headers: await _getHeaders(),
            body: json.encode({'sessionId': sessionId}),
          )
          .timeout(ApiConfig.apiTimeout);

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to disconnect: $e');
    }
  }

  // 5. GET /api/vpn/speed
  static Future<SpeedMetrics> getSpeed() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.speedEndpoint}'),
            headers: await _getHeaders(),
          )
          .timeout(ApiConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SpeedMetrics.fromJson(data);
      } else {
        throw Exception('Failed to get speed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch speed: $e');
    }
  }

  // 6. GET /api/vpn/status
  static Future<VPNStatus> getStatus() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.statusEndpoint}'),
            headers: await _getHeaders(),
          )
          .timeout(ApiConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return VPNStatus.fromJson(data);
      } else {
        throw Exception('Failed to get status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch status: $e');
    }
  }
}
