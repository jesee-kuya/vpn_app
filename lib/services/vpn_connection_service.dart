import 'package:flutter/material.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'package:wireguard_flutter/wireguard_flutter_platform_interface.dart';

class VPNConnectionService {
final WireGuardFlutterInterface _wireGuard = WireGuardFlutter.instance;  
  String? _currentTunnelName;

  /// Connect to VPN
  Future<bool> connectToVPN(String config, String tunnelName) async {
    try {
      debugPrint('🔌 Starting VPN connection...');
      debugPrint('📋 Tunnel name: $tunnelName');
      
      // 1️⃣ Validate config
      if (!_isValidConfig(config)) {
        throw Exception('Invalid WireGuard configuration');
      }
      debugPrint('✓ Config validated');

      // 2️⃣ Extract endpoint from config
      final endpoint = _extractEndpoint(config);
      debugPrint('✓ Endpoint: $endpoint');

      // 3️⃣ Initialize tunnel
      debugPrint('🔧 Initializing tunnel: $tunnelName');
      await _wireGuard.initialize(interfaceName: tunnelName);
      _currentTunnelName = tunnelName;
      debugPrint('✓ Tunnel initialized');

      // 4️⃣ Start VPN (permission will be requested automatically on Android)
      debugPrint('🚀 Starting VPN...');
      await _wireGuard.startVpn(
        serverAddress: endpoint,
        wgQuickConfig: config,
        providerBundleIdentifier: 'cloud.p2nova', // Must match your package name!
      );
      debugPrint('✓ VPN start command sent');

      // 5️⃣ Wait and verify connection
      debugPrint('⏳ Waiting for connection to establish...');
      await Future.delayed(const Duration(seconds: 3));
      
      final stage = await _wireGuard.stage();
      debugPrint('📊 VPN Stage after 3s: $stage');
      
      if (stage == VpnStage.connected) {
        debugPrint('✅ VPN Connected Successfully!');
        return true;
      } else if (stage == VpnStage.connecting) {
        debugPrint('⏳ VPN Still Connecting... waiting longer');
        await Future.delayed(const Duration(seconds: 3));
        final finalStage = await _wireGuard.stage();
        debugPrint('📊 Final VPN Stage: $finalStage');
        return finalStage == VpnStage.connected;
      } else {
        debugPrint('❌ VPN Connection Failed - Stage: $stage');
        return false;
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ VPN connection error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // If permission was denied, the error will be in the exception
      if (e.toString().contains('permission') || 
          e.toString().contains('denied') ||
          e.toString().contains('cancelled') ||
          e.toString().contains('SecurityException')) {
        debugPrint('⚠️ User denied VPN permission or permission issue');
        throw Exception('VPN permission denied. Please allow VPN access.');
      }
      
      return false;
    }
  }

  /// Disconnect VPN
  Future<void> disconnect() async {
    try {
      debugPrint('🔌 Disconnecting VPN...');
      await _wireGuard.stopVpn();
      _currentTunnelName = null;
      debugPrint('✓ VPN disconnected successfully');
    } catch (e) {
      debugPrint('❌ VPN disconnect error: $e');
      // Don't rethrow - just log it
    }
  }

  /// Get VPN stage
  Future<VpnStage> getStage() async {
    try {
      final stage = await _wireGuard.stage();
      return stage;
    } catch (e) {
      debugPrint('Error getting VPN stage: $e');
      return VpnStage.disconnected;
    }
  }

  /// Get current tunnel name
  String? get currentTunnelName => _currentTunnelName;

  /// Validate WireGuard config
  bool _isValidConfig(String config) {
    debugPrint('🔍 Validating config...');
    debugPrint('Config length: ${config.length} characters');
    
    final privateKeyOk = RegExp(r'PrivateKey\s*=\s*[A-Za-z0-9+/=]{40,}')
        .hasMatch(config);

    final publicKeyOk = RegExp(r'PublicKey\s*=\s*[A-Za-z0-9+/=]{40,}')
        .hasMatch(config);

    final endpointOk = RegExp(r'Endpoint\s*=\s*[\w\.\-]+:\d+')
        .hasMatch(config);

    final addressOk = config.contains('Address');

    debugPrint('  PrivateKey: ${privateKeyOk ? "✓" : "✗"}');
    debugPrint('  PublicKey: ${publicKeyOk ? "✓" : "✗"}');
    debugPrint('  Endpoint: ${endpointOk ? "✓" : "✗"}');
    debugPrint('  Address: ${addressOk ? "✓" : "✗"}');

    if (!privateKeyOk) debugPrint('❌ Invalid PrivateKey');
    if (!publicKeyOk) debugPrint('❌ Invalid PublicKey');
    if (!endpointOk) debugPrint('❌ Invalid Endpoint');
    if (!addressOk) debugPrint('❌ Missing Address');

    return privateKeyOk && publicKeyOk && endpointOk && addressOk;
  }

  /// Extract endpoint from WireGuard config
  String _extractEndpoint(String config) {
    final match = RegExp(r'Endpoint\s*=\s*([\w\.\-]+:\d+)')
        .firstMatch(config);
    
    if (match != null && match.groupCount >= 1) {
      final endpoint = match.group(1)!;
      debugPrint('✓ Extracted endpoint: $endpoint');
      return endpoint;
    }
    
    debugPrint('❌ No valid endpoint found in config');
    throw Exception('No valid endpoint found in config');
  }
}