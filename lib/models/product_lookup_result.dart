class ProductLookupResult {
  const ProductLookupResult({
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    this.quantityLabel,
  });

  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String? quantityLabel;

  factory ProductLookupResult.fromOpenFoodFactsProduct(
    String barcode,
    Map<String, dynamic> product,
  ) {
    final productName = _firstNonEmptyString([
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
      brand: _firstNonEmptyString([product['brands']]),
      imageUrl: _firstNonEmptyString([
        product['image_front_small_url'],
        product['image_front_url'],
        product['image_url'],
      ]),
      quantityLabel: _firstNonEmptyString([product['quantity']]),
    );
  }

  factory ProductLookupResult.fromFreshFlagProduct(
    Map<String, dynamic> product,
  ) {
    final barcode = _firstNonEmptyString([product['barcode']]);
    final name = _firstNonEmptyString([product['name']]);
    if (barcode == null || name == null) {
      throw const FormatException('Cached product is missing required fields.');
    }

    return ProductLookupResult(
      barcode: barcode,
      name: name,
      brand: _firstNonEmptyString([product['brand']]),
      imageUrl: _firstNonEmptyString([product['imageUrl']]),
      quantityLabel: _firstNonEmptyString([product['quantityLabel']]),
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
