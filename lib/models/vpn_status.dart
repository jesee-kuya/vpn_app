enum VPNConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

class VPNStatus {
  final bool isConnected;
  final VPNConnectionStatus status;
  final String? error;
  final String? ip;
  final int duration;
  final String? server;

  VPNStatus({
    required this.isConnected,
    required this.status,
    required this.duration,
    this.error,
    this.server,
    this.ip,
  });

  factory VPNStatus.fromJson(Map<String, dynamic> json) {
    return VPNStatus(
      isConnected: json['connected'] as bool? ?? false,
      server: json['server'] as String?,
      duration: json['duration'] as int? ?? 0,
      ip: json['ip'] as String?,
      status: (json['connected'] as bool? ?? false)
          ? VPNConnectionStatus.connected
          : VPNConnectionStatus.disconnected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'connected': isConnected,
      'server': server,
      'duration': duration,
      'ip': ip,
    };
  }
}