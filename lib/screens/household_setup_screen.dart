import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/app_theme.dart';
import '../viewmodels/household_viewmodel.dart';

class HouseholdSetupScreen extends StatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  State<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends State<HouseholdSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'My Household');
  final _timezoneController = TextEditingController(text: 'America/Toronto');

  @override
  void dispose() {
    _nameController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdViewModel>();
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('Create your household')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.home_outlined, size: 72, color: AppTheme.primaryGreen),
                const SizedBox(height: AppTheme.spacingL),
                const Text(
                  'FreshFlag inventory belongs to a household so everyone you invite sees the same items.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingXL),
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
                    helperText: 'Use an IANA timezone, for example America/Toronto',
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
                if (household.error != null) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    household.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.errorRed),
                  ),
                ],
                const SizedBox(height: AppTheme.spacingXL),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: household.isLoading ? null : _create,
                    child: household.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Household'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<HouseholdViewModel>().createHousehold(
          name: _nameController.text,
          timezone: _timezoneController.text,
        );
  }
}
