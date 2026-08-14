import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/household_invite.dart';
import '../utils/app_theme.dart';
import '../viewmodels/household_viewmodel.dart';

class HouseholdSetupScreen extends StatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  State<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends State<HouseholdSetupScreen> {
  final _createFormKey = GlobalKey<FormState>();
  final _joinFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'My Household');
  final _timezoneController = TextEditingController(text: 'America/Toronto');
  final _inviteController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _timezoneController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdViewModel>();
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('Set up FreshFlag')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.home_outlined,
                size: 72,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(height: AppTheme.spacingL),
              const Text(
                'Create a household or join one with an invite code. Everyone in a household sees the same inventory.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingXL),
              Form(
                key: _joinFormKey,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Join a household',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        TextFormField(
                          controller: _inviteController,
                          autocorrect: false,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: '12-character invite code',
                            prefixIcon: Icon(Icons.group_add_outlined),
                          ),
                          validator: (value) {
                            final code = HouseholdInvite.normalizeCode(value ?? '');
                            return code.length == 12
                                ? null
                                : 'Enter the 12-character invite code';
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        ElevatedButton(
                          onPressed: household.isLoading ? null : _join,
                          child: const Text('Join Household'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingL),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                    child: Text('or create a new household'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppTheme.spacingL),
              Form(
                key: _createFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Household name',
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter a household name'
                          : null,
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    TextFormField(
                      controller: _timezoneController,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Timezone',
                        helperText:
                            'Use an IANA timezone, for example America/Toronto',
                        prefixIcon: Icon(Icons.schedule_outlined),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty || !text.contains('/')) {
                          return 'Enter an IANA timezone such as America/Toronto';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    ElevatedButton(
                      onPressed: household.isLoading ? null : _create,
                      child: const Text('Create Household'),
                    ),
                  ],
                ),
              ),
              if (household.error != null) ...[
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  household.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.errorRed),
                ),
              ],
              if (household.isLoading) ...[
                const SizedBox(height: AppTheme.spacingM),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _join() async {
    if (!_joinFormKey.currentState!.validate()) return;
    await context.read<HouseholdViewModel>().joinHousehold(
          HouseholdInvite.normalizeCode(_inviteController.text),
        );
  }

  Future<void> _create() async {
    if (!_createFormKey.currentState!.validate()) return;
    await context.read<HouseholdViewModel>().createHousehold(
          name: _nameController.text,
          timezone: _timezoneController.text,
        );
  }
}
