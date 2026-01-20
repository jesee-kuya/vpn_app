class VPNServer {
  final String code;
  final String name;
  final String ip;

  VPNServer({
    required this.code,
    required this.name,
    required this.ip,
  });

  factory VPNServer.fromJson(Map<String, dynamic> json) {
    return VPNServer(
      code: json['code'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'ip': ip,
    };
  }

  String getFlag() {
    const flags = {
      'KE': '🇰🇪',
      'US': '🇺🇸',
      'FR': '🇫🇷',
      'GB': '🇬🇧',
      'DE': '🇩🇪',
      'IT': '🇮🇹',
      'SE': '🇸🇪',
      'FI': '🇫🇮',
      'NL': '🇳🇱',
      'CA': '🇨🇦',
      'JP': '🇯🇵',
      'AU': '🇦🇺',
    };
    return flags[code] ?? '🌍';
  }
}
