import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'package:wireguard_flutter/wireguard_flutter_platform_interface.dart';

/// Enhanced VPN Connection Service with better error handling and permission management
class VPNConnectionService {
  final WireGuardFlutterInterface _wireGuard = WireGuardFlutter.instance;  
  String? _currentTunnelName;
  
  // Connection state callback
  Function(VpnStage)? onStageChanged;

  /// Check if VPN is currently connected
  Future<bool> isConnected() async {
    final stage = await getStage();
    return stage == VpnStage.connected;
  }

  /// Connect to VPN with comprehensive error handling
  Future<VpnConnectionResult> connectToVPN(String config, String tunnelName) async {
    try {
      debugPrint('🔌 Starting VPN connection...');
      debugPrint('📋 Tunnel name: $tunnelName');
      
      // 1️⃣ Validate config
      final validationResult = _validateConfig(config);
      if (!validationResult.isValid) {
        debugPrint('❌ Config validation failed: ${validationResult.error}');
        return VpnConnectionResult.failure(
          'Invalid configuration: ${validationResult.error}'
        );
      }
      debugPrint('✓ Config validated');

      // 2️⃣ Extract endpoint from config
      final endpoint = _extractEndpoint(config);
      if (endpoint == null) {
        return VpnConnectionResult.failure('Could not extract endpoint from configuration');
      }
      debugPrint('✓ Endpoint: $endpoint');

      // 3️⃣ Initialize tunnel
      debugPrint('🔧 Initializing tunnel: $tunnelName');
      await _wireGuard.initialize(interfaceName: tunnelName);
      _currentTunnelName = tunnelName;
      debugPrint('✓ Tunnel initialized');

      // 4️⃣ Start VPN (this triggers Android's VPN permission dialog)
      debugPrint('🚀 Starting VPN...');
      debugPrint('ℹ️  If this is your first time, Android will ask for VPN permission');
      
      await _wireGuard.startVpn(
        serverAddress: endpoint,
        wgQuickConfig: config,
        providerBundleIdentifier: 'cloud.p2nova',
      );
      debugPrint('✓ VPN start command sent');

      // 5️⃣ Wait and verify connection with progressive checks
      return await _verifyConnection();
      
    } on PlatformException catch (e) {
      debugPrint('❌ Platform exception: ${e.code} - ${e.message}');
      
      // Handle specific VPN permission denial
      if (_isPermissionDenied(e)) {
        debugPrint('⚠️ User denied VPN permission');
        return VpnConnectionResult.permissionDenied();
      }
      
      // Handle other platform-specific errors
      return VpnConnectionResult.failure(
        'Connection failed: ${e.message ?? e.code}'
      );
      
    } catch (e, stackTrace) {
      debugPrint('❌ VPN connection error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Check for security exceptions
      if (e.toString().contains('SecurityException')) {
        return VpnConnectionResult.permissionDenied();
      }
      
      return VpnConnectionResult.failure(
        'Unexpected error: ${e.toString()}'
      );
    }
  }

  /// Verify VPN connection with progressive checks
  Future<VpnConnectionResult> _verifyConnection() async {
    debugPrint('⏳ Waiting for connection to establish...');
    
    // First check after 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    VpnStage stage = await _wireGuard.stage();
    debugPrint('📊 VPN Stage after 2s: $stage');
    onStageChanged?.call(stage);
    
    if (stage == VpnStage.connected) {
      debugPrint('✅ VPN Connected Successfully!');
      return VpnConnectionResult.success();
    }
    
    if (stage == VpnStage.connecting) {
      debugPrint('⏳ VPN Still Connecting... waiting longer');
      
      // Second check after 4 more seconds
      await Future.delayed(const Duration(seconds: 4));
      stage = await _wireGuard.stage();
      debugPrint('📊 Final VPN Stage: $stage');
      onStageChanged?.call(stage);
      
      if (stage == VpnStage.connected) {
        debugPrint('✅ VPN Connected Successfully!');
        return VpnConnectionResult.success();
      }
    }
    
    // Connection failed or timed out
    debugPrint('❌ VPN Connection Failed - Final Stage: $stage');
    
    if (stage == VpnStage.disconnected) {
      return VpnConnectionResult.failure(
        'Connection failed. Please check your configuration and try again.'
      );
    } else if (stage == VpnStage.connecting) {
      return VpnConnectionResult.failure(
        'Connection timeout. Please check your internet connection.'
      );
    } else {
      return VpnConnectionResult.failure(
        'Connection failed with status: $stage'
      );
    }
  }

  /// Disconnect VPN
  Future<bool> disconnect() async {
    try {
      debugPrint('🔌 Disconnecting VPN...');
      await _wireGuard.stopVpn();
      _currentTunnelName = null;
      debugPrint('✓ VPN disconnected successfully');
      onStageChanged?.call(VpnStage.disconnected);
      return true;
    } catch (e) {
      debugPrint('❌ VPN disconnect error: $e');
      return false;
    }
  }

  /// Get current VPN stage
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

  /// Check if error is permission denied
  bool _isPermissionDenied(PlatformException e) {
    return e.code == 'PERMISSION_DENIED' || 
           e.message?.toLowerCase().contains('permission') == true ||
           e.message?.toLowerCase().contains('denied') == true ||
           e.message?.toLowerCase().contains('cancelled') == true ||
           e.message?.toLowerCase().contains('user refused') == true;
  }

  /// Validate WireGuard config and return detailed result
  ConfigValidationResult _validateConfig(String config) {
    debugPrint('🔍 Validating config...');
    debugPrint('Config length: ${config.length} characters');
    
    if (config.isEmpty) {
      return ConfigValidationResult.invalid('Configuration is empty');
    }

    // Check for required fields
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

    // Return specific error message
    if (!privateKeyOk) {
      return ConfigValidationResult.invalid('Missing or invalid PrivateKey');
    }
    if (!publicKeyOk) {
      return ConfigValidationResult.invalid('Missing or invalid PublicKey');
    }
    if (!endpointOk) {
      return ConfigValidationResult.invalid('Missing or invalid Endpoint');
    }
    if (!addressOk) {
      return ConfigValidationResult.invalid('Missing Address field');
    }

    return ConfigValidationResult.valid();
  }

  /// Extract endpoint from WireGuard config
  String? _extractEndpoint(String config) {
    final match = RegExp(r'Endpoint\s*=\s*([\w\.\-]+:\d+)')
        .firstMatch(config);
    
    if (match != null && match.groupCount >= 1) {
      final endpoint = match.group(1)!;
      debugPrint('✓ Extracted endpoint: $endpoint');
      return endpoint;
    }
    
    debugPrint('❌ No valid endpoint found in config');
    return null;
  }

  /// Get connection statistics (if available)
  Future<String> getConnectionStats() async {
    try {
      final stage = await getStage();
      
      if (stage == VpnStage.connected) {
        return 'Connected to $_currentTunnelName';
      } else if (stage == VpnStage.connecting) {
        return 'Connecting...';
      } else {
        return 'Disconnected';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}

/// Result class for VPN connection attempts
class VpnConnectionResult {
  final bool success;
  final String? errorMessage;
  final VpnConnectionError? errorType;

  VpnConnectionResult._({
    required this.success,
    this.errorMessage,
    this.errorType,
  });

  factory VpnConnectionResult.success() {
    return VpnConnectionResult._(success: true);
  }

  factory VpnConnectionResult.failure(String message) {
    return VpnConnectionResult._(
      success: false,
      errorMessage: message,
      errorType: VpnConnectionError.connectionFailed,
    );
  }

  factory VpnConnectionResult.permissionDenied() {
    return VpnConnectionResult._(
      success: false,
      errorMessage: 'VPN permission was denied. Please allow VPN access to use this app.',
      errorType: VpnConnectionError.permissionDenied,
    );
  }

  bool get isPermissionDenied => errorType == VpnConnectionError.permissionDenied;
}

/// Error types for VPN connections
enum VpnConnectionError {
  permissionDenied,
  connectionFailed,
  invalidConfig,
}

/// Config validation result
class ConfigValidationResult {
  final bool isValid;
  final String? error;

  ConfigValidationResult._({required this.isValid, this.error});

  factory ConfigValidationResult.valid() {
    return ConfigValidationResult._(isValid: true);
  }

  factory ConfigValidationResult.invalid(String error) {
    return ConfigValidationResult._(isValid: false, error: error);
  }
}