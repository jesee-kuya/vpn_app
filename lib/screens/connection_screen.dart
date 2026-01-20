// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
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
  SpeedMetrics? _speedMetrics;

  Timer? _statusTimer;
  Timer? _speedTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedSession();
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
    if (mounted) {
      setState(() => _sessionId = saved);
    }
  }

  void _startPolling() {
    // VPN status polling every X seconds (from ApiConfig)
    _statusTimer = Timer.periodic(ApiConfig.statusPollInterval, (_) async {
      try {
        final status = await ApiService.getStatus();
        if (mounted) {
          setState(() {
            _isConnected = status.connected;
          });
        }
      } catch (_) {}
    });

    // Speed polling every X seconds
    _speedTimer = Timer.periodic(ApiConfig.speedPollInterval, (_) async {
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
      final session = await ApiService.connect(widget.server.code);
      await StorageService.saveSessionId(session.sessionId);

      if (mounted) {
        setState(() {
          _sessionId = session.sessionId;
          _isConnected = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect() async {
    if (!_isConnected || _sessionId == null) return;

    try {
      await ApiService.disconnect(_sessionId!);
      await StorageService.clearSession();

      if (mounted) {
        setState(() {
          _isConnected = false;
          _sessionId = null;
          _speedMetrics = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            Text(
              _isConnected ? 'Connected' : 'Not Connected',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _isConnected ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              server.name,
              style: TextStyle(
                fontSize: 18,
                color: txtColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 60),

            // CONNECT / DISCONNECT BUTTON
            ElevatedButton(
              onPressed: _isConnected ? _disconnect : _connect,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isConnected ? Colors.red : const Color(0xFFFF6B35),
                minimumSize: const Size(200, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              child: _isConnecting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _isConnected ? 'Disconnect' : 'Connect',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),

            const Spacer(),

            // SPEED METRICS BOTTOM
            if (_speedMetrics != null && _isConnected)
              Column(
                children: [
                  Text(
                    'Download: ${_speedMetrics!.download.toStringAsFixed(2)} Mbps',
                    style: TextStyle(color: txtColor),
                  ),
                  Text(
                    'Upload: ${_speedMetrics!.upload.toStringAsFixed(2)} Mbps',
                    style: TextStyle(color: txtColor),
                  ),
                  Text(
                    'Ping: ${_speedMetrics!.latency.toStringAsFixed(0)} ms',
                    style: TextStyle(color: txtColor),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
