import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grocery_item.dart';
import '../utils/app_theme.dart';
import '../viewmodels/grocery_viewmodel.dart';

/// Creates or edits one inventory item through the authoritative Firestore
/// ViewModel.
class AddItemScreen extends StatefulWidget {
  const AddItemScreen({
    super.key,
    this.initialBarcode,
    this.initialName,
    this.existingItem,
  });

  final String? initialBarcode;
  final String? initialName;
  final GroceryItem? existingItem;

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
  String _location = 'Unspecified';

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

  static const _locations = <String>[
    'Unspecified',
    'Pantry',
    'Fridge',
    'Freezer',
    'Other',
  ];

  bool get _isEditing => widget.existingItem != null;
  String? get _barcode =>
      widget.existingItem?.barcode ?? widget.initialBarcode;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;
    if (existing != null) {
      _nameController.text = existing.name;
      _quantityController.text = existing.quantity.toString();
      _notesController.text = existing.notes ?? '';
      _expiryDate = existing.expiryDate;
      _category = _categories.contains(existing.category)
          ? existing.category
          : 'Other';
      final existingLocation = existing.location;
      _location = existingLocation != null && _locations.contains(existingLocation)
          ? existingLocation
          : existingLocation == null
              ? 'Unspecified'
              : 'Other';
      return;
    }

    final initialName = widget.initialName?.trim();
    if (initialName != null && initialName.isNotEmpty) {
      _nameController.text = initialName;
    }
  }

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
      appBar: AppBar(title: Text(_isEditing ? 'Edit Item' : 'Add Item')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_barcode != null) ...[
                  Card(
                    child: ListTile(
                      leading: Icon(
                        widget.initialName == null && !_isEditing
                            ? Icons.qr_code
                            : Icons.check_circle_outline,
                        color: widget.initialName == null && !_isEditing
                            ? null
                            : AppTheme.primaryGreen,
                      ),
                      title: Text(
                        _isEditing
                            ? 'Product barcode'
                            : widget.initialName == null
                                ? 'Scanned barcode'
                                : 'Product recognized',
                      ),
                      subtitle: Text(_barcode!),
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
                DropdownButtonFormField<String>(
                  initialValue: _location,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    prefixIcon: Icon(Icons.kitchen_outlined),
                  ),
                  items: _locations
                      .map(
                        (location) => DropdownMenuItem(
                          value: location,
                          child: Text(location),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _location = value);
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
                        : Text(_isEditing ? 'Update Item' : 'Save Item'),
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
      firstDate: _isEditing
          ? DateTime(now.year - 5, 1, 1)
          : DateTime(now.year, now.month, now.day),
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

    final location = _location == 'Unspecified' ? null : _location;
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    final existing = widget.existingItem;

    final item = existing == null
        ? GroceryItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: _nameController.text.trim(),
            quantity: int.parse(_quantityController.text),
            category: _category,
            barcode: widget.initialBarcode,
            addedDate: DateTime.now(),
            expiryDate: _expiryDate!,
            location: location,
            notes: notes,
          )
        : GroceryItem(
            id: existing.id,
            name: _nameController.text.trim(),
            quantity: int.parse(_quantityController.text),
            category: _category,
            barcode: existing.barcode,
            addedDate: existing.addedDate,
            expiryDate: _expiryDate!,
            location: location,
            imageUrl: existing.imageUrl,
            notes: notes,
            isConsumed: existing.isConsumed,
            householdId: existing.householdId,
            createdByUid: existing.createdByUid,
            updatedByUid: existing.updatedByUid,
            updatedAt: existing.updatedAt,
          );

    try {
      if (existing == null) {
        await context.read<GroceryViewModel>().addItem(item);
      } else {
        await context.read<GroceryViewModel>().updateItem(item);
      }
      if (!mounted) return;
      Navigator.of(context).pop(item);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Could not update item.' : 'Could not save item.',
          ),
        ),
      );
    }
  }
}
