import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grocery_item.dart';
import '../utils/app_theme.dart';
import '../viewmodels/grocery_viewmodel.dart';

/// Adds one inventory item through the authoritative Firestore-backed ViewModel.
class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key, this.initialBarcode});

  final String? initialBarcode;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  DateTime? _expiryDate;
  String _category = 'Other';

  static const _categories = <String>[
    'Fruits',
    'Vegetables',
    'Dairy',
    'Meat',
    'Bakery',
    'Beverages',
    'Snacks',
    'Frozen',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<GroceryViewModel>();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('Add Item')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.initialBarcode != null) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.qr_code),
                      title: const Text('Scanned barcode'),
                      subtitle: SelectableText(widget.initialBarcode!),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                ],
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Item name',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Enter an item name'
                      : null,
                ),
                const SizedBox(height: AppTheme.spacingM),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: AppTheme.spacingM),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  validator: (value) {
                    final quantity = int.tryParse(value ?? '');
                    if (quantity == null || quantity <= 0) {
                      return 'Enter a quantity greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingM),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Expiry date'),
                    subtitle: Text(
                      _expiryDate == null
                          ? 'Choose a date'
                          : GroceryItem.formatDateOnly(_expiryDate!),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickExpiryDate,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                if (inventory.error != null) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    inventory.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.errorRed),
                  ),
                ],
                const SizedBox(height: AppTheme.spacingXL),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: inventory.isUploading ? null : _save,
                    child: inventory.isUploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Item'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an expiry date.')),
      );
      return;
    }

    final item = GroceryItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      quantity: int.parse(_quantityController.text),
      category: _category,
      barcode: widget.initialBarcode,
      addedDate: DateTime.now(),
      expiryDate: _expiryDate!,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    try {
      await context.read<GroceryViewModel>().addItem(item);
      if (!mounted) return;
      Navigator.of(context).pop(item);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save item.')),
      );
    }
  }
}
