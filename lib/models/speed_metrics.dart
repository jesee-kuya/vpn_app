class SpeedMetrics {
  final double download;
  final double upload;
  final int latency;

  SpeedMetrics({
    required this.download,
    required this.upload,
    required this.latency,
  });

  factory SpeedMetrics.fromJson(Map<String, dynamic> json) {
    return SpeedMetrics(
      download: (json['download'] as num).toDouble(),
      upload: (json['upload'] as num).toDouble(),
      latency: json['latency'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'download': download,
      'upload': upload,
      'latency': latency,
    };
  }
}