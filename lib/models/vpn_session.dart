class VPNSession {
  final String sessionId;
  final String ip;
  final int startTime;
  final String config;

  VPNSession({
    required this.sessionId,
    required this.ip,
    required this.startTime,
    required this.config,
  });

  factory VPNSession.fromJson(Map<String, dynamic> json) {
    return VPNSession(
      sessionId: json['sessionId'] as String,
      ip: json['ip'] as String,
      startTime: json['startTime'] as int,
      config: json['config'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'ip': ip,
      'startTime': startTime,
    };
  }
}