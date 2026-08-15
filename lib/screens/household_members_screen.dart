import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/household.dart';
import '../services/household_member_service.dart';
import '../utils/app_theme.dart';
import '../viewmodels/household_viewmodel.dart';

class HouseholdMembersScreen extends StatefulWidget {
  const HouseholdMembersScreen({
    super.key,
    required this.householdId,
    required this.householdName,
  });

  final String householdId;
  final String householdName;

  @override
  State<HouseholdMembersScreen> createState() => _HouseholdMembersScreenState();
}

class _HouseholdMembersScreenState extends State<HouseholdMembersScreen> {
  List<HouseholdMember> _members = const [];
  bool _loading = true;
  String? _error;
  String? _busyUid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdViewModel>();
    final callerRole = household.role;

    return Scaffold(
      appBar: AppBar(title: const Text('Members & access')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          children: [
            Text(
              widget.householdName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Owner and Admin can manage the household. Members can change inventory. Guests are read-only.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingL),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppTheme.spacingXL),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else
              ..._members.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                  child: _MemberCard(
                    member: member,
                    busy: _busyUid == member.uid,
                    actions: _actionsFor(callerRole, member),
                    onAction: (action) => _handleAction(member, action),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _actionsFor(HouseholdRole? callerRole, HouseholdMember target) {
    if (callerRole == null || target.role == HouseholdRole.owner) return const [];

    final actions = <String>[];
    if (callerRole == HouseholdRole.owner) {
      for (final role in const [
        HouseholdRole.admin,
        HouseholdRole.member,
        HouseholdRole.guest,
      ]) {
        if (role != target.role) actions.add('role:${role.name}');
      }
      actions.add('remove');
      return actions;
    }

    if (callerRole == HouseholdRole.admin &&
        (target.role == HouseholdRole.member || target.role == HouseholdRole.guest)) {
      final next = target.role == HouseholdRole.member
          ? HouseholdRole.guest
          : HouseholdRole.member;
      return ['role:${next.name}', 'remove'];
    }

    return const [];
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final members = await HouseholdMemberService.instance.listMembers(widget.householdId);
      members.sort((a, b) {
        final roleOrder = _roleOrder(a.role).compareTo(_roleOrder(b.role));
        if (roleOrder != 0) return roleOrder;
        return a.effectiveDisplayName.toLowerCase().compareTo(
              b.effectiveDisplayName.toLowerCase(),
            );
      });
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load household members: $e';
        _loading = false;
      });
    }
  }

  Future<void> _handleAction(HouseholdMember member, String action) async {
    if (_busyUid != null) return;

    if (action == 'remove') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remove household member?'),
          content: Text(
            '${member.effectiveDisplayName} will lose access to ${widget.householdName}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _runMemberAction(member.uid, () {
        return HouseholdMemberService.instance.removeMember(
          householdId: widget.householdId,
          uid: member.uid,
        );
      });
      return;
    }

    if (!action.startsWith('role:')) return;
    final roleName = action.substring('role:'.length);
    final role = HouseholdRole.values.where((value) => value.name == roleName).firstOrNull;
    if (role == null || role == HouseholdRole.owner) return;

    await _runMemberAction(member.uid, () {
      return HouseholdMemberService.instance.setRole(
        householdId: widget.householdId,
        uid: member.uid,
        role: role,
      );
    });
  }

  Future<void> _runMemberAction(String uid, Future<void> Function() action) async {
    setState(() => _busyUid = uid);
    try {
      await action();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update household access: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  static int _roleOrder(HouseholdRole role) => switch (role) {
        HouseholdRole.owner => 0,
        HouseholdRole.admin => 1,
        HouseholdRole.member => 2,
        HouseholdRole.guest => 3,
      };
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.busy,
    required this.actions,
    required this.onAction,
  });

  final HouseholdMember member;
  final bool busy;
  final List<String> actions;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            member.effectiveDisplayName.characters.first.toUpperCase(),
          ),
        ),
        title: Text(member.effectiveDisplayName),
        subtitle: Text(member.role.label),
        trailing: busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : actions.isEmpty
                ? null
                : PopupMenuButton<String>(
                    tooltip: 'Manage access',
                    onSelected: onAction,
                    itemBuilder: (context) => actions.map((action) {
                      if (action == 'remove') {
                        return const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove from household'),
                        );
                      }
                      final roleName = action.substring('role:'.length);
                      final role = HouseholdRole.values
                          .where((value) => value.name == roleName)
                          .first;
                      return PopupMenuItem(
                        value: action,
                        child: Text('Make ${role.label}'),
                      );
                    }).toList(),
                  ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spacingM),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final value in this) {
      return value;
    }
    return null;
  }
}
