import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/household_invite.dart';
import '../services/invite_service.dart';
import '../utils/app_theme.dart';
import '../viewmodels/household_viewmodel.dart';

class HouseholdInviteScreen extends StatefulWidget {
  const HouseholdInviteScreen({super.key});

  @override
  State<HouseholdInviteScreen> createState() => _HouseholdInviteScreenState();
}

class _HouseholdInviteScreenState extends State<HouseholdInviteScreen> {
  final _joinController = TextEditingController();
  HouseholdInvite? _invite;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _joinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdViewModel>();
    final current = household.current;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('Household sharing')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        children: [
          if (current != null && household.isOwner) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Invite someone',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    const Text(
                      'Create a shareable code. It expires after 7 days and can be revoked at any time.',
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    if (_invite == null)
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _createInvite,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Create Invite Code'),
                      )
                    else ...[
                      SelectableText(
                        _invite!.code,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'Expires ${_formatDateTime(_invite!.expiresAt)}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _copyInvite,
                              icon: const Icon(Icons.copy_outlined),
                              label: const Text('Copy'),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingM),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _revokeInvite,
                              icon: const Icon(Icons.block_outlined),
                              label: const Text('Revoke'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Join another household',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  const Text(
                    'Enter the invite code shared by that household owner.',
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  TextField(
                    controller: _joinController,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: '12-character invite code',
                      prefixIcon: Icon(Icons.group_add_outlined),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  ElevatedButton(
                    onPressed: _busy ? null : _joinHousehold,
                    child: const Text('Join Household'),
                  ),
                ],
              ),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: AppTheme.spacingM),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppTheme.spacingM),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.errorRed),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createInvite() async {
    final household = context.read<HouseholdViewModel>();
    final current = household.current;
    if (current == null || !household.isOwner) return;
    await _run(() async {
      final invite = await InviteService.instance.createInvite(current.id);
      if (mounted) setState(() => _invite = invite);
    });
  }

  Future<void> _revokeInvite() async {
    final invite = _invite;
    if (invite == null) return;
    await _run(() async {
      await InviteService.instance.revokeInvite(invite);
      if (mounted) setState(() => _invite = null);
    });
  }

  Future<void> _copyInvite() async {
    final invite = _invite;
    if (invite == null) return;
    await Clipboard.setData(ClipboardData(text: invite.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied.')),
    );
  }

  Future<void> _joinHousehold() async {
    final code = HouseholdInvite.normalizeCode(_joinController.text);
    if (code.length != 12) {
      setState(() => _error = 'Enter a valid 12-character invite code.');
      return;
    }
    await _run(() async {
      final joined = await context.read<HouseholdViewModel>().joinHousehold(code);
      if (!mounted) return;
      _joinController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${joined.name}.')),
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}
