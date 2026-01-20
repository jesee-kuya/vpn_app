class VPNStatus {
  final bool connected;
  final String server;
  final int duration;
  final String ip;

  VPNStatus({
    required this.connected,
    required this.server,
    required this.duration,
    required this.ip,
  });

  factory VPNStatus.fromJson(Map<String, dynamic> json) {
    return VPNStatus(
      connected: json['connected'] as bool,
      server: json['server'] as String,
      duration: json['duration'] as int,
      ip: json['ip'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'connected': connected,
      'server': server,
      'duration': duration,
      'ip': ip,
    };
  }
}