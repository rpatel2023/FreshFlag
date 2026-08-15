import 'package:flutter/material.dart';

import '../config/app_brand.dart';
import '../services/discord_reminder_service.dart';
import '../utils/app_theme.dart';

class DiscordRemindersScreen extends StatefulWidget {
  const DiscordRemindersScreen({super.key});

  @override
  State<DiscordRemindersScreen> createState() => _DiscordRemindersScreenState();
}

class _DiscordRemindersScreenState extends State<DiscordRemindersScreen> {
  final TextEditingController _webhookController = TextEditingController();
  DiscordIntegrationStatus? _status;
  bool _loading = false;
  bool _saving = false;
  bool _testing = false;
  bool _showWebhook = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _webhookController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final enabled = status?.enabled ?? false;
    final configured = status?.configured ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Discord reminders')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.discord),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              configured
                                  ? 'Your Discord is connected'
                                  : 'Discord not configured',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              enabled
                                  ? 'Your expiry reminders are also sent to your Discord destination.'
                                  : configured
                                      ? 'Your webhook is saved but Discord reminders are disabled.'
                                      : 'Add your own Discord channel webhook to receive reminders without relying on iPhone push notifications.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_loading) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    configured ? 'Replace your webhook' : 'Connect Discord',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'In Discord, create an incoming webhook for the private channel you want ${AppBrand.name} to notify, then paste its URL here. This setting belongs only to your ${AppBrand.name} account, and ${AppBrand.name} never displays the saved URL again.',
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  TextField(
                    controller: _webhookController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    obscureText: !_showWebhook,
                    decoration: InputDecoration(
                      labelText: 'Discord webhook URL',
                      hintText: 'https://discord.com/api/webhooks/…',
                      suffixIcon: IconButton(
                        tooltip: _showWebhook ? 'Hide webhook' : 'Show webhook',
                        onPressed: () =>
                            setState(() => _showWebhook = !_showWebhook),
                        icon: Icon(
                          _showWebhook
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveWebhook,
                    icon: const Icon(Icons.link),
                    label: Text(
                      configured ? 'Save replacement & enable' : 'Save & enable',
                    ),
                  ),
                  if (configured) ...[
                    const SizedBox(height: AppTheme.spacingS),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Discord reminders'),
                      subtitle: const Text(
                        'Send each reminder that applies to you to your Discord channel',
                      ),
                      value: enabled,
                      onChanged: _saving ? null : _setEnabled,
                    ),
                    OutlinedButton.icon(
                      onPressed: _testing ? null : _sendTest,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(_testing ? 'Sending…' : 'Send test message'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final status = await DiscordReminderService.instance.getStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } catch (_) {
      if (!mounted) return;
      _showError('Could not load your Discord reminder status.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveWebhook() async {
    final webhook = _webhookController.text.trim();
    if (webhook.isEmpty) {
      _showError('Paste a Discord webhook URL first.');
      return;
    }

    setState(() => _saving = true);
    try {
      final status = await DiscordReminderService.instance.save(
        enabled: true,
        webhookUrl: webhook,
      );
      _webhookController.clear();
      if (!mounted) return;
      setState(() {
        _status = status;
        _showWebhook = false;
      });
      _showMessage('Your Discord reminders are connected.');
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Could not save the Discord webhook. Check the URL and try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _saving = true);
    try {
      final status = await DiscordReminderService.instance.save(
        enabled: enabled,
      );
      if (!mounted) return;
      setState(() => _status = status);
    } catch (_) {
      if (!mounted) return;
      _showError('Could not update your Discord reminders.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendTest() async {
    setState(() => _testing = true);
    try {
      await DiscordReminderService.instance.sendTest();
      if (!mounted) return;
      _showMessage('Test message sent to your Discord channel.');
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Discord did not accept the test message. Check the webhook and try again.',
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
