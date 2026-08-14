import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product_lookup_result.dart';

class ProductLookupException implements Exception {
  const ProductLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductLookupService {
  ProductLookupService({http.Client? client}) : _client = client ?? http.Client();

  static const _host = 'world.openfoodfacts.org';
  static const _userAgent =
      'FreshFlag/1.0 (https://github.com/rpatel2023/FreshFlag)';

  final http.Client _client;

  Future<ProductLookupResult?> lookupBarcode(String rawBarcode) async {
    final barcode = rawBarcode.trim();
    if (!RegExp(r'^\d{4,24}$').hasMatch(barcode)) {
      return null;
    }

    final uri = Uri.https(
      _host,
      '/api/v3/product/$barcode',
      const {
        'fields': 'code,product_name,generic_name,abbreviated_product_name,quantity',
      },
    );

    late http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': _userAgent,
        },
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      throw const ProductLookupException(
        'Could not reach Open Food Facts. You can still add the item manually.',
      );
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProductLookupException(
        'Open Food Facts returned HTTP ${response.statusCode}.',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final product = decoded['product'];
      if (product is! Map<String, dynamic>) return null;

      return ProductLookupResult.fromOpenFoodFactsProduct(barcode, product);
    } on FormatException {
      return null;
    } catch (_) {
      throw const ProductLookupException(
        'Open Food Facts returned an unreadable response.',
      );
    }
  }

  void close() => _client.close();
}
