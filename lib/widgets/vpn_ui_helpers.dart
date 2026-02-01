import 'package:flutter/material.dart';
import 'package:wireguard_flutter/wireguard_flutter_platform_interface.dart';

/// Helper class for VPN-related UI dialogs and messages
class VpnDialogs {
  /// Show VPN permission explanation dialog before connecting
  static Future<bool> showPermissionExplanation(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.vpn_key, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            const Text('VPN Permission Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This app needs VPN permission to secure your internet connection.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'What happens next:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Android will show a system dialog'),
                  const SizedBox(height: 4),
                  const Text('2. Tap "OK" to allow VPN connection'),
                  const SizedBox(height: 4),
                  const Text('3. Your connection will be secured'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Note: You only need to grant permission once.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show permission denied dialog with retry option
  static Future<bool> showPermissionDeniedDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Text('Permission Denied'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'VPN permission was denied. This app needs VPN access to function.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline, size: 20, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'To use this app:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• Tap "Try Again" below'),
                  const SizedBox(height: 4),
                  const Text('• When Android asks, tap "OK"'),
                  const SizedBox(height: 4),
                  const Text('• Your VPN will connect'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Try Again'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show connection error dialog
  static void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            const Text('Connection Failed'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show error snackbar
  static void showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show connecting dialog with loading indicator
  static void showConnectingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to VPN...'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget to display VPN connection status
class VpnStatusWidget extends StatelessWidget {
  final VpnStage stage;
  final String? tunnelName;

  const VpnStatusWidget({
    Key? key,
    required this.stage,
    this.tunnelName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBorderColor()),
      ),
      child: Row(
        children: [
          _buildStatusIcon(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getTextColor(),
                  ),
                ),
                if (tunnelName != null && stage == VpnStage.connected) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Connected to: $tunnelName',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (stage == VpnStage.connecting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    switch (stage) {
      case VpnStage.connected:
        icon = Icons.shield_outlined;
        color = Colors.green.shade600;
        break;
      case VpnStage.connecting:
        icon = Icons.sync;
        color = Colors.orange.shade600;
        break;
      case VpnStage.disconnected:
        icon = Icons.shield_outlined;
        color = Colors.grey.shade600;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey.shade600;
    }

    return Icon(icon, color: color, size: 32);
  }

  String _getStatusText() {
    switch (stage) {
      case VpnStage.connected:
        return 'Connected';
      case VpnStage.connecting:
        return 'Connecting...';
      case VpnStage.disconnected:
        return 'Disconnected';
      default:
        return 'Unknown';
    }
  }

  Color _getBackgroundColor() {
    switch (stage) {
      case VpnStage.connected:
        return Colors.green.shade50;
      case VpnStage.connecting:
        return Colors.orange.shade50;
      case VpnStage.disconnected:
        return Colors.grey.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getBorderColor() {
    switch (stage) {
      case VpnStage.connected:
        return Colors.green.shade200;
      case VpnStage.connecting:
        return Colors.orange.shade200;
      case VpnStage.disconnected:
        return Colors.grey.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  Color _getTextColor() {
    switch (stage) {
      case VpnStage.connected:
        return Colors.green.shade700;
      case VpnStage.connecting:
        return Colors.orange.shade700;
      case VpnStage.disconnected:
        return Colors.grey.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}