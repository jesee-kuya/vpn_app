import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'package:wireguard_flutter/wireguard_flutter_platform_interface.dart';
import '../models/vpn_status.dart'; // Import the model

class VPNConnectionService {
  final WireGuardFlutterInterface _wireGuard = WireGuardFlutter.instance;
 
  Future<bool> connectToVPN(String config, String tunnelName) async {
    try {
      await _wireGuard.initialize(interfaceName: tunnelName);
      
      final endpoint = _extractEndpoint(config);
      if (endpoint.isEmpty) {
        throw Exception('Invalid VPN configuration: no endpoint found');
      }
      
      await _wireGuard.startVpn(
        serverAddress: endpoint,
        wgQuickConfig: config,
        providerBundleIdentifier: 'com.p2nova.vpn', 
      );
      
      // Return true indicating success
      return true; 
    } catch (e) {
      print('VPN connection error: $e');
      // Return false indicating failure
      return false; 
    }
  }
  Future<void> disconnect() async {
    try {
      await _wireGuard.stopVpn();
    } catch (e) {
      // ignore: avoid_print
      print('VPN disconnection error: $e');
      rethrow;
    }
  }
  
  String _extractEndpoint(String config) {
    final regex = RegExp(r'Endpoint\s*=\s*(.+)');
    final match = regex.firstMatch(config);
    return match?.group(1)?.trim() ?? '';
  }
  
  Future<VpnStage> getStage() async {
    try {
      return await _wireGuard.stage();
    } catch (e) {
      // ignore: avoid_print
      print('Error getting VPN stage: $e');
      return VpnStage.disconnected;
    }
  }
  
  Future<VPNStatus> getStatus() async {
    try {
      final stage = await _wireGuard.stage();
      
      final isConnected = stage == VpnStage.connected;
      VPNConnectionStatus status;
      
      switch (stage) {
        case VpnStage.connected:
          status = VPNConnectionStatus.connected;
          break;
        case VpnStage.connecting:
          status = VPNConnectionStatus.connecting;
          break;
        case VpnStage.disconnecting:
          status = VPNConnectionStatus.disconnecting;
          break;
        case VpnStage.disconnected:
          status = VPNConnectionStatus.disconnected;
          break;
        default:
          status = VPNConnectionStatus.error;
      }
      
      return VPNStatus(
        isConnected: isConnected,
        status: status,
        duration: 0,
      );
    } catch (e) {
      return VPNStatus(
        isConnected: false,
        status: VPNConnectionStatus.error,
        error: e.toString(),
        duration: 0,
      );
    }
  }
}