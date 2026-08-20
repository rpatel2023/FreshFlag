class ProductLookupResult {
  const ProductLookupResult({
    required this.barcode,
    required this.name,
    this.quantityLabel,
    this.category,
  });

  final String barcode;
  final String name;
  final String? quantityLabel;
  final String? category;

  factory ProductLookupResult.fromOpenFoodFactsProduct(
    String barcode,
    Map<String, dynamic> product,
  ) {
    final productName = _firstNonEmptyString([
      product['product_name_en'],
      product['generic_name_en'],
      product['abbreviated_product_name_en'],
      product['product_name'],
      product['generic_name'],
      product['abbreviated_product_name'],
    ]);

    if (productName == null) {
      throw const FormatException('Product does not contain a usable name.');
    }

    return ProductLookupResult(
      barcode: barcode,
      name: productName,
      quantityLabel: _firstNonEmptyString([product['quantity']]),
    );
  }

  factory ProductLookupResult.fromHouseholdCache(
    String barcode,
    Map<String, dynamic> data,
  ) {
    final name = _firstNonEmptyString([data['name']]);
    if (name == null) {
      throw const FormatException(
        'Cached product does not contain a usable name.',
      );
    }
    return ProductLookupResult(
      barcode: barcode,
      name: name,
      category: _firstNonEmptyString([data['category']]),
    );
  }

  Map<String, dynamic> toHouseholdCacheMap({
    required String updatedByUid,
    required String updatedAt,
  }) => {
    'barcode': barcode,
    'name': name.trim(),
    if (category?.trim().isNotEmpty == true) 'category': category!.trim(),
    'updatedByUid': updatedByUid,
    'updatedAt': updatedAt,
  };

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is! String) continue;
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
