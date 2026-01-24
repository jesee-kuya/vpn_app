// lib/models/vpn_server.dart
class VPNServer {
  final String code;
  final String name;
  final String ip;
  final String flag;

  VPNServer({
    required this.code,
    required this.name,
    required this.ip,
    required this.flag,
  });

  factory VPNServer.fromJson(Map<String, dynamic> json) {
    // Handle backend responses that might be missing fields
    final code = json['code'] as String? ?? json['countryCode'] as String? ?? '';
    final name = json['name'] as String? ?? '';
    
    return VPNServer(
      code: code,
      name: name,
      ip: json['ip'] as String? ?? '',
      flag: json['flag'] as String? ?? _getFlagEmoji(code),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'ip': ip,
      'flag': flag,
    };
  }

  // Helper to get flag emoji from country code
  static String _getFlagEmoji(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'KE':
        return '🇰🇪';
      case 'US':
        return '🇺🇸';
      case 'UK':
      case 'GB':
        return '🇬🇧';
      case 'DE':
        return '🇩🇪';
      case 'SG':
        return '🇸🇬';
      case 'JP':
        return '🇯🇵';
      default:
        return '🌍';
    }
  }
}