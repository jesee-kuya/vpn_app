import 'package:flutter/material.dart';

/// VPN Configuration Diagnostic Tool
/// Use this to debug configuration issues
class VpnConfigDiagnostics {
  
  /// Print detailed analysis of a WireGuard config
  static void analyzeConfig(String config) {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔍 VPN CONFIG DIAGNOSTICS');
    debugPrint('═══════════════════════════════════════');
    
    if (config.isEmpty) {
      debugPrint('❌ FATAL: Config is empty!');
      debugPrint('═══════════════════════════════════════');
      return;
    }
    
    debugPrint('✅ Config length: ${config.length} characters');
    debugPrint('\n📋 Full Config:\n$config');
    debugPrint('\n🔍 Detailed Analysis:');
    
    // Check for [Interface] section
    final hasInterface = config.contains('[Interface]');
    debugPrint('${hasInterface ? "✅" : "❌"} [Interface] section: $hasInterface');
    
    // Check for [Peer] section
    final hasPeer = config.contains('[Peer]');
    debugPrint('${hasPeer ? "✅" : "❌"} [Peer] section: $hasPeer');
    
    // Check PrivateKey
    final privateKeyMatch = RegExp(r'PrivateKey\s*=\s*([A-Za-z0-9+/=]+)')
        .firstMatch(config);
    if (privateKeyMatch != null) {
      final key = privateKeyMatch.group(1)!;
      debugPrint('✅ PrivateKey found: ${key.substring(0, 10)}... (length: ${key.length})');
      if (key.length < 40) {
        debugPrint('   ⚠️  WARNING: PrivateKey seems too short (${key.length} chars)');
      }
    } else {
      debugPrint('❌ PrivateKey: NOT FOUND or INVALID FORMAT');
      debugPrint('   Expected format: PrivateKey = <base64-string>');
    }
    
    // Check PublicKey
    final publicKeyMatch = RegExp(r'PublicKey\s*=\s*([A-Za-z0-9+/=]+)')
        .firstMatch(config);
    if (publicKeyMatch != null) {
      final key = publicKeyMatch.group(1)!;
      debugPrint('✅ PublicKey found: ${key.substring(0, 10)}... (length: ${key.length})');
      if (key.length < 40) {
        debugPrint('   ⚠️  WARNING: PublicKey seems too short (${key.length} chars)');
      }
    } else {
      debugPrint('❌ PublicKey: NOT FOUND or INVALID FORMAT');
      debugPrint('   Expected format: PublicKey = <base64-string>');
    }
    
    // Check Endpoint
    final endpointMatch = RegExp(r'Endpoint\s*=\s*([\w\.\-]+):(\d+)')
        .firstMatch(config);
    if (endpointMatch != null) {
      final host = endpointMatch.group(1)!;
      final port = endpointMatch.group(2)!;
      debugPrint('✅ Endpoint found: $host:$port');
      
      // Validate port
      final portNum = int.tryParse(port);
      if (portNum == null || portNum < 1 || portNum > 65535) {
        debugPrint('   ❌ ERROR: Invalid port number: $port');
      } else {
        debugPrint('   ✅ Port is valid: $port');
      }
    } else {
      debugPrint('❌ Endpoint: NOT FOUND or INVALID FORMAT');
      debugPrint('   Expected format: Endpoint = server.com:51820');
    }
    
    // Check Address
    final addressMatch = RegExp(r'Address\s*=\s*([^\n]+)')
        .firstMatch(config);
    if (addressMatch != null) {
      final address = addressMatch.group(1)!.trim();
      debugPrint('✅ Address found: $address');
      
      // Validate IP format
      if (!address.contains('/')) {
        debugPrint('   ⚠️  WARNING: Address missing CIDR notation (e.g., /32 or /24)');
      }
    } else {
      debugPrint('❌ Address: NOT FOUND');
      debugPrint('   Expected format: Address = 10.0.0.2/32');
    }
    
    // Check DNS (optional but recommended)
    final dnsMatch = RegExp(r'DNS\s*=\s*([^\n]+)')
        .firstMatch(config);
    if (dnsMatch != null) {
      final dns = dnsMatch.group(1)!.trim();
      debugPrint('✅ DNS found: $dns');
    } else {
      debugPrint('⚠️  DNS: Not specified (optional but recommended)');
      debugPrint('   Recommended: DNS = 1.1.1.1, 8.8.8.8');
    }
    
    // Check AllowedIPs
    final allowedIPsMatch = RegExp(r'AllowedIPs\s*=\s*([^\n]+)')
        .firstMatch(config);
    if (allowedIPsMatch != null) {
      final ips = allowedIPsMatch.group(1)!.trim();
      debugPrint('✅ AllowedIPs found: $ips');
      if (ips == '0.0.0.0/0' || ips.contains('0.0.0.0/0')) {
        debugPrint('   ✅ Routes all traffic through VPN');
      }
    } else {
      debugPrint('⚠️  AllowedIPs: Not specified');
      debugPrint('   For full VPN: AllowedIPs = 0.0.0.0/0');
    }
    
    // Check PersistentKeepalive
    final keepaliveMatch = RegExp(r'PersistentKeepalive\s*=\s*(\d+)')
        .firstMatch(config);
    if (keepaliveMatch != null) {
      final keepalive = keepaliveMatch.group(1)!;
      debugPrint('✅ PersistentKeepalive: $keepalive seconds');
    } else {
      debugPrint('⚠️  PersistentKeepalive: Not specified (recommended: 25)');
    }
    
    // Summary
    debugPrint('\n📊 VALIDATION SUMMARY:');
    final requiredFields = [
      privateKeyMatch != null,
      publicKeyMatch != null,
      endpointMatch != null,
      addressMatch != null,
    ];
    
    final passedCount = requiredFields.where((e) => e).length;
    final totalRequired = requiredFields.length;
    
    if (passedCount == totalRequired) {
      debugPrint('✅ All required fields present ($passedCount/$totalRequired)');
      debugPrint('✅ Configuration should be VALID');
    } else {
      debugPrint('❌ Missing required fields ($passedCount/$totalRequired)');
      debugPrint('❌ Configuration is INVALID');
      
      if (privateKeyMatch == null) debugPrint('   • Missing: PrivateKey');
      if (publicKeyMatch == null) debugPrint('   • Missing: PublicKey');
      if (endpointMatch == null) debugPrint('   • Missing: Endpoint');
      if (addressMatch == null) debugPrint('   • Missing: Address');
    }
    
    debugPrint('═══════════════════════════════════════');
  }
  
  /// Test if config matches expected WireGuard format
  static bool quickValidate(String config) {
    if (config.isEmpty) return false;
    
    final checks = [
      config.contains('[Interface]'),
      config.contains('[Peer]'),
      RegExp(r'PrivateKey\s*=\s*[A-Za-z0-9+/=]{40,}').hasMatch(config),
      RegExp(r'PublicKey\s*=\s*[A-Za-z0-9+/=]{40,}').hasMatch(config),
      RegExp(r'Endpoint\s*=\s*[\w\.\-]+:\d+').hasMatch(config),
      config.contains('Address'),
    ];
    
    return checks.every((check) => check);
  }
  
  /// Generate a sample valid config for testing
  static String getSampleConfig() {
    return '''[Interface]
PrivateKey = YourPrivateKeyBase64EncodedString12345678901234567890
Address = 10.0.0.2/32
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ServerPublicKeyBase64EncodedString12345678901234567890
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25''';
  }
  
  /// Extract specific field from config
  static String? extractField(String config, String fieldName) {
    final match = RegExp('$fieldName\\s*=\\s*([^\\n]+)')
        .firstMatch(config);
    return match?.group(1)?.trim();
  }
  
  /// Show diagnostic dialog in UI
  static void showDiagnosticDialog(BuildContext context, String config) {
    final hasInterface = config.contains('[Interface]');
    final hasPeer = config.contains('[Peer]');
    final hasPrivateKey = RegExp(r'PrivateKey\s*=\s*[A-Za-z0-9+/=]{40,}').hasMatch(config);
    final hasPublicKey = RegExp(r'PublicKey\s*=\s*[A-Za-z0-9+/=]{40,}').hasMatch(config);
    final hasEndpoint = RegExp(r'Endpoint\s*=\s*[\w\.\-]+:\d+').hasMatch(config);
    final hasAddress = config.contains('Address');
    
    final allValid = hasInterface && hasPeer && hasPrivateKey && 
                     hasPublicKey && hasEndpoint && hasAddress;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              allValid ? Icons.check_circle : Icons.error,
              color: allValid ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            const Text('Config Diagnostics'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCheckItem('[Interface] section', hasInterface),
              _buildCheckItem('[Peer] section', hasPeer),
              _buildCheckItem('PrivateKey', hasPrivateKey),
              _buildCheckItem('PublicKey', hasPublicKey),
              _buildCheckItem('Endpoint', hasEndpoint),
              _buildCheckItem('Address', hasAddress),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: allValid ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: allValid ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Text(
                  allValid 
                      ? '✅ Configuration appears valid'
                      : '❌ Configuration has missing or invalid fields',
                  style: TextStyle(
                    color: allValid ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!allValid) ...[
                const SizedBox(height: 12),
                const Text(
                  'Check your backend server configuration and ensure it returns a valid WireGuard config.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!allValid)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Copy diagnostics to clipboard would be here
                analyzeConfig(config);
              },
              child: const Text('Print to Console'),
            ),
        ],
      ),
    );
  }
  
  static Widget _buildCheckItem(String label, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            color: isValid ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}