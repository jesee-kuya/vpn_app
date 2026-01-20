class VPNSession {
  final String sessionId;
  final String ip;
  final int startTime;

  VPNSession({
    required this.sessionId,
    required this.ip,
    required this.startTime,
  });

  factory VPNSession.fromJson(Map<String, dynamic> json) {
    return VPNSession(
      sessionId: json['sessionId'] as String,
      ip: json['ip'] as String,
      startTime: json['startTime'] as int,
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