import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ServerConfigDialog extends StatefulWidget {
  final ApiService apiService;

  const ServerConfigDialog({super.key, required this.apiService});

  static Future<void> show(BuildContext context, ApiService apiService) async {
    await showDialog(
      context: context,
      builder: (context) => ServerConfigDialog(apiService: apiService),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late TextEditingController _urlController;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.apiService.currentBaseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final targetUrl = _urlController.text.trim();
    final isOk = await widget.apiService.testConnection(targetUrl);

    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _testSuccess = isOk;
      _testResult = isOk
          ? '✓ Server reachable & healthy!'
          : '✕ Unable to reach server at $targetUrl';
    });
  }

  void _applyUrl(String url) {
    _urlController.text = url;
    _testConnection();
  }

  void _saveAndClose() {
    final newUrl = _urlController.text.trim();
    if (newUrl.isNotEmpty) {
      widget.apiService.updateBaseUrl(newUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server connected to: ${widget.apiService.currentBaseUrl}'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.settings_remote_rounded, color: AppTheme.primaryBlue),
          SizedBox(width: 10),
          Text(
            'Server Host Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a server host or enter your local computer IP:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),

            // Server Presets
            const Text(
              'PRESETS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),

            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_done_outlined, color: AppTheme.primaryBlue),
              title: const Text('Render Production Cloud', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text(ApiService.renderBaseUrl, style: TextStyle(fontSize: 11)),
              onTap: () => _applyUrl(ApiService.renderBaseUrl),
            ),
            const Divider(height: 1),

            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.wifi_rounded, color: AppTheme.success),
              title: const Text('Local Wi-Fi Computer (10.49.50.105)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text(ApiService.localWifiUrl, style: TextStyle(fontSize: 11)),
              onTap: () => _applyUrl(ApiService.localWifiUrl),
            ),
            const Divider(height: 1),

            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_android_rounded, color: AppTheme.warning),
              title: const Text('Android Emulator (10.0.2.2)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text(ApiService.emulatorUrl, style: TextStyle(fontSize: 11)),
              onTap: () => _applyUrl(ApiService.emulatorUrl),
            ),
            const Divider(height: 16),

            // Custom URL Field
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Target API Base URL',
                hintText: 'http://192.168.x.x:8000/api/v1',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Test Connection Button & Indicator
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt_rounded, size: 16),
                  label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _testSuccess ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _testSuccess ? AppTheme.success : AppTheme.danger,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveAndClose,
          child: const Text('Save & Connect'),
        ),
      ],
    );
  }
}
