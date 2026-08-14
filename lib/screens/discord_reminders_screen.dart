import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/discord_reminder_service.dart';
import '../utils/app_theme.dart';
import '../viewmodels/household_viewmodel.dart';

class DiscordRemindersScreen extends StatefulWidget {
  const DiscordRemindersScreen({super.key});

  @override
  State<DiscordRemindersScreen> createState() => _DiscordRemindersScreenState();
}

class _DiscordRemindersScreenState extends State<DiscordRemindersScreen> {
  final TextEditingController _webhookController = TextEditingController();
  DiscordIntegrationStatus? _status;
  String? _loadedHouseholdId;
  bool _loading = false;
  bool _saving = false;
  bool _testing = false;
  bool _showWebhook = false;

  @override
  void dispose() {
    _webhookController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdViewModel>();
    final current = household.current;

    if (current == null) {
      return const Scaffold(body: Center(child: Text('Select a household first.')));
    }

    if (_loadedHouseholdId != current.id && !_loading) {
      _loadedHouseholdId = current.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(current.id));
    }

    final status = _status;
    final enabled = status?.enabled ?? false;
    final configured = status?.configured ?? false;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
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
                              configured ? 'Discord connected' : 'Discord not configured',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              enabled
                                  ? 'Expiry reminders are also sent to the household Discord channel.'
                                  : configured
                                      ? 'The webhook is saved but Discord reminders are disabled.'
                                      : 'Add a Discord channel webhook to receive reminders without relying on iPhone push notifications.',
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
          if (household.isOwner)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      configured ? 'Replace webhook' : 'Connect Discord',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    const Text(
                      'In Discord, create an incoming webhook for the channel you want FreshFlag to notify, then paste its URL here. FreshFlag never displays the saved URL again.',
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
                          onPressed: () => setState(() => _showWebhook = !_showWebhook),
                          icon: Icon(
                            _showWebhook ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _saveWebhook(current.id),
                      icon: const Icon(Icons.link),
                      label: Text(configured ? 'Save replacement & enable' : 'Save & enable'),
                    ),
                    if (configured) ...[
                      const SizedBox(height: AppTheme.spacingS),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Discord reminders'),
                        subtitle: const Text('Send each due household reminder once to Discord'),
                        value: enabled,
                        onChanged: _saving ? null : (value) => _setEnabled(current.id, value),
                      ),
                      OutlinedButton.icon(
                        onPressed: _testing ? null : () => _sendTest(current.id),
                        icon: const Icon(Icons.send_outlined),
                        label: Text(_testing ? 'Sending…' : 'Send test message'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Managed by the household owner'),
                subtitle: Text('Only the owner can add, replace, enable, or test the Discord webhook.'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _load(String householdId) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final status = await DiscordReminderService.instance.getStatus(householdId);
      if (!mounted || _loadedHouseholdId != householdId) return;
      setState(() => _status = status);
    } catch (e) {
      if (!mounted || _loadedHouseholdId != householdId) return;
      _showError('Could not load Discord reminder status.');
    } finally {
      if (mounted && _loadedHouseholdId == householdId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveWebhook(String householdId) async {
    final webhook = _webhookController.text.trim();
    if (webhook.isEmpty) {
      _showError('Paste a Discord webhook URL first.');
      return;
    }

    setState(() => _saving = true);
    try {
      final status = await DiscordReminderService.instance.save(
        householdId: householdId,
        enabled: true,
        webhookUrl: webhook,
      );
      _webhookController.clear();
      if (!mounted) return;
      setState(() {
        _status = status;
        _showWebhook = false;
      });
      _showMessage('Discord reminders connected.');
    } catch (e) {
      if (!mounted) return;
      _showError('Could not save the Discord webhook. Check the URL and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setEnabled(String householdId, bool enabled) async {
    setState(() => _saving = true);
    try {
      final status = await DiscordReminderService.instance.save(
        householdId: householdId,
        enabled: enabled,
      );
      if (!mounted) return;
      setState(() => _status = status);
    } catch (e) {
      if (!mounted) return;
      _showError('Could not update Discord reminders.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendTest(String householdId) async {
    setState(() => _testing = true);
    try {
      await DiscordReminderService.instance.sendTest(householdId);
      if (!mounted) return;
      _showMessage('Test message sent to Discord.');
    } catch (e) {
      if (!mounted) return;
      _showError('Discord did not accept the test message. Check the webhook and try again.');
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
