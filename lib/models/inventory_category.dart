import 'grocery_item.dart';

class InventoryCategories {
  InventoryCategories._();

  static const allLabel = 'All';
  static const otherLabel = 'Other';

  static const defaults = <String>[
    'Fruits',
    'Vegetables',
    'Dairy',
    'Meat',
    'Bakery',
    'Beverages',
    'Snacks',
    'Frozen',
    otherLabel,
  ];

  static List<String> forItems(
    Iterable<GroceryItem> items, {
    Iterable<String> savedCategories = const [],
    bool includeAll = false,
  }) {
    final customCategories = <String>{};
    for (final saved in savedCategories) {
      final category = clean(saved);
      if (category != null && !defaults.contains(category)) {
        customCategories.add(category);
      }
    }
    for (final item in items) {
      final category = clean(item.category);
      if (category != null && !defaults.contains(category)) {
        customCategories.add(category);
      }
    }
    final sortedCustom = customCategories.toList()
      ..sort((a, b) {
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return [if (includeAll) allLabel, ...defaults, ...sortedCustom];
  }

  static String? clean(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return null;
    return normalized;
  }
}
