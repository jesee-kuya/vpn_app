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

  // VPN Connection Service with enhanced error handling
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
            // Backend says disconnected but we think we're connected
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
      debugPrint('═══════════════════════════════════════');
      debugPrint('🔌 Starting VPN Connection Process');
      debugPrint('Server: ${widget.server.name} (${widget.server.code})');
      debugPrint('═══════════════════════════════════════');
      
      // Step 1: Show permission explanation dialog (first time or after denial)
      debugPrint('📋 Step 1: Showing permission explanation...');
      final shouldProceed = await VpnDialogs.showPermissionExplanation(context);
      
      if (!shouldProceed) {
        debugPrint('⚠️  User cancelled at permission explanation');
        setState(() => _isProcessing = false);
        return;
      }
      debugPrint('✅ Step 1 Complete: User accepted explanation');
      
      // Step 2: Get VPN configuration from backend
      debugPrint('📡 Step 2: Requesting config from backend...');
      if (mounted) {
        VpnDialogs.showConnectingDialog(context);
      }
      
      final session = await ApiService.connect(widget.server.code);
      debugPrint('✅ Step 2 Complete: Session ID: ${session.sessionId}');
      debugPrint('   IP: ${session.ip}');
      
      // Step 3: Establish actual VPN tunnel using WireGuard
      debugPrint('🔐 Step 3: Establishing VPN tunnel...');
      debugPrint('   This will trigger Android VPN permission dialog if needed');
      
      final result = await _vpnService.connectToVPN(
        session.config,
        'p2nova_${session.sessionId}',
      );

      // Close connecting dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Step 4: Handle connection result
      if (!result.success) {
        debugPrint('❌ Step 3 Failed: ${result.errorMessage}');
        
        // Handle permission denial specifically
        if (result.isPermissionDenied) {
          debugPrint('⚠️  VPN Permission was denied by user');
          
          if (mounted) {
            final retry = await VpnDialogs.showPermissionDeniedDialog(context);
            
            if (retry) {
              debugPrint('🔄 User chose to retry connection');
              // Disconnect backend session before retry
              try {
                await ApiService.disconnect(session.sessionId);
              } catch (_) {}
              
              // Retry connection
              setState(() => _isProcessing = false);
              _connect();
              return;
            } else {
              debugPrint('⚠️  User chose not to retry');
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
      
      debugPrint('✅ Step 3 Complete: VPN tunnel established');

      // Step 5: Save session and update UI
      debugPrint('💾 Step 4: Saving session data...');
      await StorageService.saveSessionId(session.sessionId);
      await StorageService.saveServerCode(widget.server.code);
      await StorageService.saveVPNConfig(session.config);

      if (mounted) {
        setState(() {
          _sessionId = session.sessionId;
          _connectedIP = session.ip;
          _currentStage = VpnStage.connected;
        });

        debugPrint('✅ Step 4 Complete: Session saved');
        debugPrint('═══════════════════════════════════════');
        debugPrint('🎉 VPN CONNECTION SUCCESSFUL!');
        debugPrint('═══════════════════════════════════════');

        VpnDialogs.showSuccessMessage(
          context,
          '✓ Connected to ${widget.server.name}!',
        );
      }
    } catch (e) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('❌ VPN CONNECTION FAILED');
      debugPrint('Error: $e');
      debugPrint('═══════════════════════════════════════');
      
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
      return 'Connection failed: ${error.toString().length > 100 ? error.toString().substring(0, 100) + '...' : error.toString()}';
    }
  }

  Future<void> _disconnect() async {
    if (_currentStage == VpnStage.disconnected || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      debugPrint('🔌 Disconnecting VPN...');
      
      // Step 1: Disconnect VPN tunnel
      final success = await _vpnService.disconnect();
      
      if (!success) {
        debugPrint('⚠️  VPN disconnect returned false');
      }

      // Step 2: Notify backend
      if (_sessionId != null) {
        try {
          await ApiService.disconnect(_sessionId!);
          debugPrint('✅ Backend notified of disconnect');
        } catch (e) {
          debugPrint('⚠️  Backend disconnect error: $e');
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

        debugPrint('✅ Disconnected successfully');
        
        VpnDialogs.showSuccessMessage(
          context,
          'Disconnected from VPN',
        );
      }
    } catch (e) {
      debugPrint('❌ Disconnect error: $e');
      
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
    final txtColor = const Color(0xFF2D3142);
    final isConnected = _currentStage == VpnStage.connected;
    final isConnecting = _currentStage == VpnStage.connecting || _isProcessing;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          server.name,
          style: const TextStyle(
            color: Color(0xFF2D3142),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // Connection Status Widget - Using the new VpnStatusWidget
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: VpnStatusWidget(
                stage: _currentStage,
                tunnelName: _vpnService.currentTunnelName,
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Server Info
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        server.flag,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        server.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: txtColor,
                        ),
                      ),
                    ],
                  ),
                  
                  // Display connected IP
                  if (_connectedIP != null && isConnected) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.public,
                            size: 16,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Your IP: $_connectedIP',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 40),

            // CONNECT / DISCONNECT BUTTON
            ElevatedButton(
              onPressed: isConnecting 
                  ? null 
                  : (isConnected ? _disconnect : _connect),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected 
                    ? Colors.red.shade600 
                    : const Color(0xFF4CAF50),
                minimumSize: const Size(220, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: isConnecting ? 0 : 6,
                shadowColor: isConnected 
                    ? Colors.red.withOpacity(0.3)
                    : Colors.green.withOpacity(0.3),
              ),
              child: isConnecting
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
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
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
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
                            color: Colors.white,
                          ),
                        ),
                      ],
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

            // SPEED METRICS BOTTOM
            if (_speedMetrics != null && isConnected)
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.green.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.speed,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Connection Speed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetric(
                          Icons.arrow_downward,
                          'Download',
                          '${_speedMetrics!.download.toStringAsFixed(2)} Mbps',
                          Colors.green.shade600,
                        ),
                        _buildMetric(
                          Icons.arrow_upward,
                          'Upload',
                          '${_speedMetrics!.upload.toStringAsFixed(2)} Mbps',
                          Colors.blue.shade600,
                        ),
                        _buildMetric(
                          Icons.access_time,
                          'Ping',
                          '${_speedMetrics!.latency.toStringAsFixed(0)} ms',
                          Colors.orange.shade600,
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else if (isConnected)
              // Placeholder for speed metrics loading
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
              ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
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