import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/household.dart';
import '../services/firebase_auth_service.dart';
import '../services/household_service.dart';
import '../utils/app_theme.dart';
import '../viewmodels/household_viewmodel.dart';

class HouseholdMembersScreen extends StatelessWidget {
  const HouseholdMembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdViewModel>();
    final current = household.current;
    final currentUid = context.read<FirebaseAuthService>().currentUserId;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('Household members')),
      body: current == null
          ? const Center(child: Text('No household selected.'))
          : StreamBuilder<List<HouseholdMember>>(
              stream: HouseholdService.instance.watchMembers(current.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load household members.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final members = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  children: [
                    Card(
                      child: Column(
                        children: [
                          for (var index = 0; index < members.length; index++) ...[
                            _MemberTile(
                              member: members[index],
                              isCurrentUser: members[index].uid == currentUid,
                              canRemove: household.isOwner &&
                                  members[index].uid != current.ownerUid,
                              onRemove: () => _removeMember(
                                context,
                                members[index],
                              ),
                            ),
                            if (index != members.length - 1)
                              const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    if (household.isOwner)
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.admin_panel_settings_outlined),
                          title: Text('You own this household'),
                          subtitle: Text(
                            'Ownership transfer is not part of the MVP, so the owner cannot leave yet.',
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: household.isLoading
                            ? null
                            : () => _leaveHousehold(context, current.name),
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Leave household'),
                      ),
                  ],
                );
              },
            ),
    );
  }

  static Future<void> _removeMember(
    BuildContext context,
    HouseholdMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
          '${member.displayLabel} will lose access to this household and its inventory.',
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
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<HouseholdViewModel>().removeMember(member.uid);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove household member.')),
      );
    }
  }

  static Future<void> _leaveHousehold(
    BuildContext context,
    String householdName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave household?'),
        content: Text(
          'You will lose access to $householdName and its shared inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<HouseholdViewModel>().leaveCurrentHousehold();
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not leave household.')),
      );
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isCurrentUser,
    required this.canRemove,
    required this.onRemove,
  });

  final HouseholdMember member;
  final bool isCurrentUser;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final owner = member.role == HouseholdRole.owner;
    return ListTile(
      leading: CircleAvatar(
        child: Icon(owner ? Icons.workspace_premium : Icons.person_outline),
      ),
      title: Text('${member.displayLabel}${isCurrentUser ? ' (You)' : ''}'),
      subtitle: Text(owner ? 'Owner' : 'Member'),
      trailing: canRemove
          ? IconButton(
              tooltip: 'Remove member',
              onPressed: onRemove,
              icon: const Icon(Icons.person_remove_outlined),
            )
          : null,
    );
  }
}
