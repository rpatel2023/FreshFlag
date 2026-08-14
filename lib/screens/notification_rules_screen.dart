import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notification_rule.dart';
import '../services/notification_rule_service.dart';
import '../utils/app_theme.dart';
import '../viewmodels/household_viewmodel.dart';

class NotificationRulesScreen extends StatelessWidget {
  const NotificationRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdViewModel>();
    final current = household.current;
    if (current == null) {
      return const Scaffold(body: Center(child: Text('Select a household first.')));
    }

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('Expiry reminders')),
      floatingActionButton: household.isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showRuleEditor(context, current.id),
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Add rule'),
            )
          : null,
      body: StreamBuilder<List<NotificationRule>>(
        stream: NotificationRuleService.instance.watchRules(current.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load reminder rules: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rules = snapshot.data!;
          if (rules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_none, size: 64),
                    const SizedBox(height: AppTheme.spacingM),
                    const Text(
                      'No expiry reminder rules yet.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      household.isOwner
                          ? 'Add a rule to choose when and what household members are notified.'
                          : 'The household owner manages reminder rules.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            itemCount: rules.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingM),
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: rule.enabled,
                      onChanged: household.isOwner
                          ? (value) => NotificationRuleService.instance.updateRule(
                                current.id,
                                rule.copyWith(enabled: value),
                              )
                          : null,
                      title: Text(_daysLabel(rule.daysBefore)),
                      subtitle: Text('${rule.sendTime} • ${rule.titleTemplate}'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingM,
                        0,
                        AppTheme.spacingM,
                        AppTheme.spacingM,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          rule.bodyTemplate,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    if (household.isOwner)
                      ButtonBar(
                        children: [
                          TextButton.icon(
                            onPressed: () => _showRuleEditor(
                              context,
                              current.id,
                              existing: rule,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          TextButton.icon(
                            onPressed: () => _deleteRule(context, current.id, rule),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _daysLabel(int days) {
    if (days == 0) return 'On expiry day';
    if (days == 1) return '1 day before expiry';
    return '$days days before expiry';
  }

  static Future<void> _deleteRule(
    BuildContext context,
    String householdId,
    NotificationRule rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete reminder rule?'),
        content: Text(_daysLabel(rule.daysBefore)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await NotificationRuleService.instance.deleteRule(householdId, rule.id);
    }
  }

  static Future<void> _showRuleEditor(
    BuildContext context,
    String householdId, {
    NotificationRule? existing,
  }) async {
    final daysController = TextEditingController(
      text: (existing?.daysBefore ?? 3).toString(),
    );
    final titleController = TextEditingController(
      text: existing?.titleTemplate ?? '{item} expires soon',
    );
    final bodyController = TextEditingController(
      text: existing?.bodyTemplate ?? '{item} expires in {days} days on {expiry_date}.',
    );
    final timeController = TextEditingController(
      text: existing?.sendTime ?? '09:00',
    );
    final formKey = GlobalKey<FormState>();
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !saving,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(existing == null ? 'Add reminder rule' : 'Edit reminder rule'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: daysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Days before expiry'),
                      validator: (value) {
                        final days = int.tryParse(value ?? '');
                        if (days == null || days < 0 || days > 365) {
                          return 'Enter 0–365 days';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    TextFormField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Send time',
                        helperText: 'Household local time, HH:mm',
                      ),
                      validator: (value) {
                        try {
                          NotificationRule.normalizeSendTime(value ?? '');
                          return null;
                        } catch (_) {
                          return 'Use a valid 24-hour time such as 09:00';
                        }
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Notification title'),
                      validator: (value) => (value?.trim().isEmpty ?? true) ? 'Enter a title' : null,
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    TextFormField(
                      controller: bodyController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notification message',
                        helperText: 'Variables: {item}, {days}, {expiry_date}, {quantity}, {location}',
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true) ? 'Enter a message' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() => saving = true);
                        try {
                          final days = int.parse(daysController.text);
                          final time = NotificationRule.normalizeSendTime(timeController.text);
                          if (existing == null) {
                            await NotificationRuleService.instance.createRule(
                              householdId: householdId,
                              daysBefore: days,
                              titleTemplate: titleController.text,
                              bodyTemplate: bodyController.text,
                              sendTime: time,
                            );
                          } else {
                            await NotificationRuleService.instance.updateRule(
                              householdId,
                              existing.copyWith(
                                daysBefore: days,
                                titleTemplate: titleController.text.trim(),
                                bodyTemplate: bodyController.text.trim(),
                                sendTime: time,
                              ),
                            );
                          }
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                        } finally {
                          if (dialogContext.mounted) setState(() => saving = false);
                        }
                      },
                child: Text(existing == null ? 'Add' : 'Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      daysController.dispose();
      titleController.dispose();
      bodyController.dispose();
      timeController.dispose();
    }
  }
}
