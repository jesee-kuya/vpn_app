class ApiConfig {
  // Change this to your actual API URL
  static const String baseUrl = 'http://localhost:8000';
  
  // API Endpoints
  static const String serversEndpoint = '/api/servers';
  static const String serverSelectEndpoint = '/api/vpn/server';
  static const String connectEndpoint = '/api/vpn/connect';
  static const String disconnectEndpoint = '/api/vpn/disconnect';
  static const String speedEndpoint = '/api/vpn/speed';
  static const String statusEndpoint = '/api/vpn/status';
  
  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 10);
  static const Duration connectTimeout = Duration(seconds: 15);
  
  // Polling intervals
  static const Duration statusPollInterval = Duration(seconds: 5);
  static const Duration speedPollInterval = Duration(seconds: 3);
}
