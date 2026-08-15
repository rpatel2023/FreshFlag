import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grocery_item.dart';
import '../utils/app_theme.dart';
import '../viewmodels/grocery_viewmodel.dart';

/// Adds or edits one inventory item through the authoritative Firestore-backed ViewModel.
class AddItemScreen extends StatefulWidget {
  const AddItemScreen({
    super.key,
    this.initialBarcode,
    this.initialName,
    this.initialQuantity,
    this.initialCategory,
    this.initialLocation,
    this.editItem,
  });

  final String? initialBarcode;
  final String? initialName;
  final int? initialQuantity;
  final String? initialCategory;
  final String? initialLocation;
  final GroceryItem? editItem;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _locationController = TextEditingController();
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

  bool get _isEditing => widget.editItem != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.editItem;
    if (existing != null) {
      _nameController.text = existing.name;
      _quantityController.text = existing.quantity.toString();
      _locationController.text = existing.location ?? '';
      _notesController.text = existing.notes ?? '';
      _expiryDate = existing.expiryDate;
      _category = _categories.contains(existing.category) ? existing.category : 'Other';
      return;
    }

    final initialName = widget.initialName?.trim();
    if (initialName != null && initialName.isNotEmpty) {
      _nameController.text = initialName;
    }
    if (widget.initialQuantity != null && widget.initialQuantity! > 0) {
      _quantityController.text = widget.initialQuantity.toString();
    }
    final initialCategory = widget.initialCategory;
    if (initialCategory != null && _categories.contains(initialCategory)) {
      _category = initialCategory;
    }
    _locationController.text = widget.initialLocation?.trim() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<GroceryViewModel>();
    final barcode = widget.editItem?.barcode ?? widget.initialBarcode;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit item' : 'Add item')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isEditing && barcode != null) ...[
                  Card(
                    child: ListTile(
                      leading: Icon(
                        widget.initialName == null
                            ? Icons.qr_code
                            : Icons.check_circle_outline,
                        color: widget.initialName == null
                            ? null
                            : Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        widget.initialName == null
                            ? 'Scanned barcode'
                            : 'Product recognized',
                      ),
                      subtitle: Text(
                        widget.initialName == null
                            ? barcode
                            : '${widget.initialName}\n$barcode',
                      ),
                      isThreeLine: widget.initialName != null,
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
                TextFormField(
                  controller: _locationController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Storage location (optional)',
                    hintText: 'Fridge, freezer, pantry…',
                    prefixIcon: Icon(Icons.kitchen_outlined),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  'Expiry date',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Wrap(
                  spacing: AppTheme.spacingS,
                  runSpacing: AppTheme.spacingS,
                  children: [
                    _ExpiryShortcut(label: 'Today', onTap: () => _setExpiryOffset(0)),
                    _ExpiryShortcut(label: '+3 days', onTap: () => _setExpiryOffset(3)),
                    _ExpiryShortcut(label: '+7 days', onTap: () => _setExpiryOffset(7)),
                    _ExpiryShortcut(label: '+14 days', onTap: () => _setExpiryOffset(14)),
                    _ExpiryShortcut(label: '+30 days', onTap: () => _setExpiryOffset(30)),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(
                      _expiryDate == null
                          ? 'Choose a date'
                          : GroceryItem.formatDateOnly(_expiryDate!),
                    ),
                    subtitle: _expiryDate == null ? const Text('Required') : null,
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
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                        : Text(_isEditing ? 'Save changes' : 'Save item'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setExpiryOffset(int days) {
    final now = DateTime.now();
    setState(() {
      _expiryDate = GroceryItem.normalizeDateOnly(
        now.add(Duration(days: days)),
      );
    });
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final today = GroceryItem.normalizeDateOnly(now);
    final initial = _expiryDate ?? today.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _isEditing ? DateTime(now.year - 5, 1, 1) : today,
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

    final location = _clean(_locationController.text);
    final notes = _clean(_notesController.text);
    final quantity = int.parse(_quantityController.text);
    final existing = widget.editItem;
    final item = existing == null
        ? GroceryItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: _nameController.text.trim(),
            quantity: quantity,
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
            quantity: quantity,
            category: _category,
            barcode: existing.barcode,
            addedDate: existing.addedDate,
            expiryDate: _expiryDate!,
            imageUrl: existing.imageUrl,
            location: location,
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
          content: Text(_isEditing ? 'Could not update item.' : 'Could not save item.'),
        ),
      );
    }
  }

  static String? _clean(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }
}

class _ExpiryShortcut extends StatelessWidget {
  const _ExpiryShortcut({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.add_alarm_outlined, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
