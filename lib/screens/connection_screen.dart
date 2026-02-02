// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'package:p2novavpn/services/vpn_connection_service.dart';
import 'package:p2novavpn/widgets/vpn_ui_helpers.dart';
import '../models/vpn_server.dart';
import '../models/speed_metrics.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../config/api_config.dart';

class ConnectionScreen extends StatefulWidget {
  final VPNServer server;
  
  const ConnectionScreen({super.key, required this.server});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen>
    with TickerProviderStateMixin {
  VpnStage _currentStage = VpnStage.disconnected;
  bool _isProcessing = false;
  String? _sessionId;
  String? _connectedIP;
  SpeedMetrics? _speedMetrics;

  Timer? _statusTimer;
  Timer? _speedTimer;

  // VPN Connection Service
  final VPNConnectionService _vpnService = VPNConnectionService();

  @override
  void initState() {
    super.initState();
    _initializeVpn();
    _loadSavedSession();
    _startPolling();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _speedTimer?.cancel();
    _vpnService.onStageChanged = null;
    super.dispose();
  }

  Future<void> _initializeVpn() async {
    // Set up stage change listener for real-time UI updates
    _vpnService.onStageChanged = (stage) {
      if (mounted) {
        setState(() {
          _currentStage = stage;
        });
      }
    };

    // Get initial VPN stage
    final stage = await _vpnService.getStage();
    if (mounted) {
      setState(() {
        _currentStage = stage;
      });
    }
  }

  Future<void> _loadSavedSession() async {
    final saved = await StorageService.getSessionId();
    if (mounted && saved != null) {
      setState(() => _sessionId = saved);
      await _checkVPNStatus();
    }
  }

  Future<void> _checkVPNStatus() async {
    try {
      final stage = await _vpnService.getStage();
      if (mounted) {
        setState(() {
          _currentStage = stage;
        });
      }
    } catch (e) {
      debugPrint('Error checking VPN status: $e');
    }
  }

  void _startPolling() {
    // VPN status polling
    _statusTimer = Timer.periodic(ApiConfig.statusPollInterval, (_) async {
      await _checkVPNStatus();
      
      // Also check backend status
      try {
        final status = await ApiService.getStatus();
        final isConnected = _currentStage == VpnStage.connected;
        if (mounted && status.isConnected != isConnected) {
          // Backend and local state mismatch - sync them
          if (!status.isConnected && isConnected) {
            await _vpnService.disconnect();
            await StorageService.clearSession();
            setState(() {
              _currentStage = VpnStage.disconnected;
              _sessionId = null;
              _connectedIP = null;
              _speedMetrics = null;
            });
          }
        }
      } catch (_) {}
    });

    // Speed polling
    _speedTimer = Timer.periodic(ApiConfig.speedPollInterval, (_) async {
      if (_currentStage != VpnStage.connected) return;
      
      try {
        final speed = await ApiService.getSpeed();
        if (mounted) {
          setState(() => _speedMetrics = speed);
        }
      } catch (_) {}
    });
  }

  Future<void> _connect() async {
    if (_isProcessing || _currentStage == VpnStage.connected) return;

    setState(() => _isProcessing = true);

    try {
      // Step 1: Show permission explanation dialog
      final shouldProceed = await VpnDialogs.showPermissionExplanation(context);
      
      if (!shouldProceed) {
        setState(() => _isProcessing = false);
        return;
      }
      
      // Step 2: Show connecting dialog and get config from backend
      if (mounted) {
        VpnDialogs.showConnectingDialog(context);
      }
      
      final session = await ApiService.connect(widget.server.code);
      
      // Step 3: Prepare VPN config
      String vpnConfig = session.config;
      
      // Fix newlines if needed
      if (vpnConfig.contains('\\n')) {
        vpnConfig = vpnConfig.replaceAll('\\n', '\n');
      }
      
      // Ensure config ends with newline
      vpnConfig = vpnConfig.trim() + '\n';
      
      // Create tunnel name (clean, no hyphens)
      final tunnelName = 'p2nova_${widget.server.code}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Step 4: Establish VPN tunnel
      final result = await _vpnService.connectToVPN(vpnConfig, tunnelName);

      // Close connecting dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Step 5: Handle connection result
      if (!result.success) {
        // Handle permission denial specifically
        if (result.isPermissionDenied) {
          if (mounted) {
            final retry = await VpnDialogs.showPermissionDeniedDialog(context);
            
            if (retry) {
              // Cleanup backend session before retry
              try {
                await ApiService.disconnect(session.sessionId);
              } catch (_) {}
              
              // Retry connection
              setState(() => _isProcessing = false);
              _connect();
              return;
            }
          }
          
          // Cleanup backend session
          try {
            await ApiService.disconnect(session.sessionId);
          } catch (_) {}
          
          throw Exception('VPN permission denied');
        } else {
          // Other connection error
          throw Exception(result.errorMessage ?? 'VPN tunnel establishment failed');
        }
      }

      // Step 6: Save session and update UI
      await StorageService.saveSessionId(session.sessionId);
      await StorageService.saveServerCode(widget.server.code);
      await StorageService.saveVPNConfig(vpnConfig);

      if (mounted) {
        setState(() {
          _sessionId = session.sessionId;
          _connectedIP = session.ip;
          _currentStage = VpnStage.connected;
        });

        VpnDialogs.showSuccessMessage(
          context,
          '✓ Connected to ${widget.server.name}!',
        );
      }
    } catch (e) {
      // Cleanup on failure
      if (_sessionId != null) {
        try {
          await ApiService.disconnect(_sessionId!);
        } catch (_) {}
      }
      await _vpnService.disconnect();
      
      if (mounted) {
        // Close any open dialogs
        Navigator.of(context).popUntil((route) => route.isFirst);
        
        // User-friendly error messages
        String errorMessage = _getUserFriendlyErrorMessage(e);
        
        VpnDialogs.showErrorDialog(context, errorMessage);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'VPN permission is required to use this app. Please grant permission when asked.';
    } else if (errorStr.contains('invalid') || errorStr.contains('configuration')) {
      return 'Server configuration error. Please try a different server or contact support.';
    } else if (errorStr.contains('timeout')) {
      return 'Connection timeout. Please check your internet connection and try again.';
    } else if (errorStr.contains('network') || errorStr.contains('unreachable')) {
      return 'Network error. Please check your internet connection.';
    } else if (errorStr.contains('server')) {
      return 'Server error. Please try again or select a different server.';
    } else {
      return 'Connection failed. Please try again or contact support.';
    }
  }

  Future<void> _disconnect() async {
    if (_currentStage == VpnStage.disconnected || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Step 1: Disconnect VPN tunnel
      await _vpnService.disconnect();

      // Step 2: Notify backend
      if (_sessionId != null) {
        try {
          await ApiService.disconnect(_sessionId!);
        } catch (e) {
          debugPrint('Backend disconnect error: $e');
        }
      }

      // Step 3: Clear local storage
      await StorageService.clearSession();

      if (mounted) {
        setState(() {
          _currentStage = VpnStage.disconnected;
          _sessionId = null;
          _connectedIP = null;
          _speedMetrics = null;
        });

        VpnDialogs.showSuccessMessage(
          context,
          'Disconnected from VPN',
        );
      }
    } catch (e) {
      debugPrint('Disconnect error: $e');
      
      if (mounted) {
        VpnDialogs.showErrorMessage(
          context,
          'Failed to disconnect properly. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = widget.server;
    final isConnected = _currentStage == VpnStage.connected;
    final isConnecting = _currentStage == VpnStage.connecting || _isProcessing;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE5DC),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios),
                      color: const Color(0xFF2D3142),
                    ),
                    Expanded(
                      child: Text(
                        server.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF2D3142),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Connection Status Widget
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: VpnStatusWidget(
                  stage: _currentStage,
                  tunnelName: _vpnService.currentTunnelName,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Server Info Card
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          server.flag,
                          style: const TextStyle(fontSize: 40),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              server.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3142),
                              ),
                            ),
                            if (_connectedIP != null && isConnected)
                              Text(
                                'IP: $_connectedIP',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),

              // CONNECT / DISCONNECT BUTTON
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isConnecting 
                        ? null 
                        : (isConnected ? _disconnect : _connect),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected 
                          ? Colors.red.shade600 
                          : const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      elevation: isConnecting ? 0 : 8,
                      shadowColor: isConnected 
                          ? Colors.red.withOpacity(0.4)
                          : const Color(0xFFFF6B35).withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: isConnecting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _currentStage == VpnStage.connecting
                                    ? 'Connecting...'
                                    : 'Processing...',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isConnected 
                                    ? Icons.vpn_lock 
                                    : Icons.vpn_key,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isConnected ? 'Disconnect' : 'Connect',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Connection hint text
              if (!isConnected && !isConnecting)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Tap to connect and secure your connection',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),

              const Spacer(),

              // SPEED METRICS
              if (_speedMetrics != null && isConnected)
                Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.speed,
                            color: const Color(0xFFFF6B35),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Connection Speed',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3142),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetric(
                            Icons.arrow_downward,
                            'Download',
                            '${_speedMetrics!.download.toStringAsFixed(2)} Mbps',
                            const Color(0xFF4CAF50),
                          ),
                          _buildMetric(
                            Icons.arrow_upward,
                            'Upload',
                            '${_speedMetrics!.upload.toStringAsFixed(2)} Mbps',
                            const Color(0xFF2196F3),
                          ),
                          _buildMetric(
                            Icons.access_time,
                            'Ping',
                            '${_speedMetrics!.latency.toStringAsFixed(0)} ms',
                            const Color(0xFFFF6B35),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else if (isConnected)
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading connection stats...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}