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
      
      // 1️⃣ Validate config
      if (!_isValidConfig(config)) {
        throw Exception('Invalid WireGuard configuration');
      }
      debugPrint('✓ Config validated');

      // 2️⃣ Extract endpoint from config
      final endpoint = _extractEndpoint(config);
      debugPrint('✓ Endpoint: $endpoint');

      // 3️⃣ Initialize tunnel
      await _wireGuard.initialize(interfaceName: tunnelName);
      _currentTunnelName = tunnelName;
      debugPrint('✓ Tunnel initialized: $tunnelName');

      // 4️⃣ Start VPN (permission will be requested automatically on Android)
      await _wireGuard.startVpn(
        serverAddress: endpoint,
        wgQuickConfig: config,
        providerBundleIdentifier: 'com.p2nova.vpn', // Replace with your app ID
      );
      debugPrint('✓ VPN start command sent');

      // 5️⃣ Wait and verify connection
      await Future.delayed(const Duration(seconds: 3));
      final stage = await _wireGuard.stage();

      debugPrint('📊 VPN Stage: $stage');
      
      if (stage == VpnStage.connected) {
        debugPrint('✅ VPN Connected Successfully!');
        return true;
      } else if (stage == VpnStage.connecting) {
        debugPrint('⏳ VPN Still Connecting... waiting longer');
        await Future.delayed(const Duration(seconds: 2));
        final finalStage = await _wireGuard.stage();
        debugPrint('📊 Final VPN Stage: $finalStage');
        return finalStage == VpnStage.connected;
      } else {
        debugPrint('❌ VPN Connection Failed - Stage: $stage');
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ VPN connection error: $e');
      
      // If permission was denied, the error will be in the exception
      if (e.toString().contains('permission') || 
          e.toString().contains('denied') ||
          e.toString().contains('cancelled')) {
        debugPrint('⚠️ User denied VPN permission');
      }
      
      return false;
    }
  }

  /// Disconnect VPN
  Future<void> disconnect() async {
    try {
      await _wireGuard.stopVpn();
      _currentTunnelName = null;
      debugPrint('✓ VPN disconnected successfully');
    } catch (e) {
      debugPrint('❌ VPN disconnect error: $e');
      rethrow;
    }
  }

  /// Get VPN stage
  Future<VpnStage> getStage() async {
    try {
      return await _wireGuard.stage();
    } catch (e) {
      debugPrint('Error getting VPN stage: $e');
      return VpnStage.disconnected;
    }
  }

  /// Get current tunnel name
  String? get currentTunnelName => _currentTunnelName;

  /// Validate WireGuard config
  bool _isValidConfig(String config) {
    final privateKeyOk = RegExp(r'PrivateKey\s*=\s*[A-Za-z0-9+/=]{40,}')
        .hasMatch(config);

    final publicKeyOk = RegExp(r'PublicKey\s*=\s*[A-Za-z0-9+/=]{40,}')
        .hasMatch(config);

    final endpointOk = RegExp(r'Endpoint\s*=\s*[\w\.\-]+:\d+')
        .hasMatch(config);

    final addressOk = config.contains('Address =');

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
      debugPrint('Extracted endpoint: $endpoint');
      return endpoint;
    }
    
    throw Exception('No valid endpoint found in config');
  }
}