class ProductLookupResult {
  const ProductLookupResult({
    required this.barcode,
    required this.name,
    this.quantityLabel,
  });

  final String barcode;
  final String name;
  final String? quantityLabel;

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

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is! String) continue;
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
