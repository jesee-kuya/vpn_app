// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'package:p2novavpn/services/vpn_connection_service.dart';
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
  bool _isConnected = false;
  bool _isConnecting = false;
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
    _loadSavedSession();
    _checkVPNStatus();
    _startPolling();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _speedTimer?.cancel();
    super.dispose();
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
          _isConnected = stage == VpnStage.connected;
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
        if (mounted && status.isConnected != _isConnected) {
          setState(() {
            _isConnected = status.isConnected;
          });
        }
      } catch (_) {}
    });

    // Speed polling
    _speedTimer = Timer.periodic(ApiConfig.speedPollInterval, (_) async {
      if (!_isConnected) return;
      
      try {
        final speed = await ApiService.getSpeed();
        if (mounted) {
          setState(() => _speedMetrics = speed);
        }
      } catch (_) {}
    });
  }

  Future<void> _connect() async {
  if (_isConnecting || _isConnected) return;

  setState(() => _isConnecting = true);

  try {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔌 Starting VPN Connection Process');
    debugPrint('Server: ${widget.server.name} (${widget.server.code})');
    debugPrint('═══════════════════════════════════════');
    
    // Step 1: Get VPN configuration from backend
    debugPrint('📡 Step 1: Requesting config from backend...');
    final session = await ApiService.connect(widget.server.code);
    debugPrint('✅ Step 1 Complete: Session ID: ${session.sessionId}');
    debugPrint('   IP: ${session.ip}');
    
    // Step 2: Establish actual VPN tunnel using WireGuard
    debugPrint('🔐 Step 2: Establishing VPN tunnel...');
    final vpnConnected = await _vpnService.connectToVPN(
      session.config,
      'p2nova_${session.sessionId}',
    );

    if (!vpnConnected) {
      throw Exception('VPN tunnel establishment failed');
    }
    
    debugPrint('✅ Step 2 Complete: VPN tunnel established');

    // Step 3: Save session and update UI
    debugPrint('💾 Step 3: Saving session data...');
    await StorageService.saveSessionId(session.sessionId);
    await StorageService.saveServerCode(widget.server.code);
    await StorageService.saveVPNConfig(session.config);

    if (mounted) {
      setState(() {
        _sessionId = session.sessionId;
        _connectedIP = session.ip;
        _isConnected = true;
      });

      debugPrint('✅ Step 3 Complete: Session saved');
      debugPrint('═══════════════════════════════════════');
      debugPrint('🎉 VPN CONNECTION SUCCESSFUL!');
      debugPrint('═══════════════════════════════════════');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Connected to ${widget.server.name}!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
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
      // User-friendly error messages
      String errorMessage = 'Connection failed';
      if (e.toString().contains('permission')) {
        errorMessage = 'VPN permission required. Please grant permission and try again.';
      } else if (e.toString().contains('Invalid')) {
        errorMessage = 'Server configuration error. Please try a different server.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Connection timeout. Please check your internet.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _connect,
          ),
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isConnecting = false);
  }
}
  Future<void> _disconnect() async {
    if (!_isConnected) return;

    setState(() => _isConnecting = true);

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
          _isConnected = false;
          _sessionId = null;
          _connectedIP = null;
          _speedMetrics = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Disconnect error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = widget.server;
    final txtColor = const Color(0xFF2D3142);

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
            
            // Connection Status Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Column(
                children: [
                  Icon(
                    _isConnected ? Icons.shield : Icons.shield_outlined,
                    size: 80,
                    color: _isConnected ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isConnected ? 'Connected' : 'Not Connected',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Server Info
            Text(
              '${server.flag} ${server.name}',
              style: TextStyle(
                fontSize: 18,
                color: txtColor.withOpacity(0.8),
              ),
            ),
            
            // Display connected IP (fixes unused field warning)
            if (_connectedIP != null && _isConnected) ...[
              const SizedBox(height: 8),
              Text(
                'Your IP: $_connectedIP',
                style: TextStyle(
                  fontSize: 14,
                  color: txtColor.withOpacity(0.6),
                ),
              ),
            ],
            
            const SizedBox(height: 60),

            // CONNECT / DISCONNECT BUTTON
            ElevatedButton(
              onPressed: _isConnecting ? null : (_isConnected ? _disconnect : _connect),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isConnected ? Colors.red : const Color(0xFFFF6B35),
                minimumSize: const Size(200, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                elevation: _isConnecting ? 0 : 4,
              ),
              child: _isConnecting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isConnected ? 'Disconnect' : 'Connect',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),

            const Spacer(),

            // SPEED METRICS BOTTOM
            if (_speedMetrics != null && _isConnected)
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetric(
                          Icons.arrow_downward,
                          'Download',
                          '${_speedMetrics!.download.toStringAsFixed(2)} Mbps',
                          Colors.green,
                        ),
                        _buildMetric(
                          Icons.arrow_upward,
                          'Upload',
                          '${_speedMetrics!.upload.toStringAsFixed(2)} Mbps',
                          Colors.blue,
                        ),
                        _buildMetric(
                          Icons.speed,
                          'Ping',
                          '${_speedMetrics!.latency.toStringAsFixed(0)} ms',
                          Colors.orange,
                        ),
                      ],
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
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3142),
          ),
        ),
      ],
    );
  }
}