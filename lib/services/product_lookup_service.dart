import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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

    // Prefer the authenticated FreshFlag backend so repeated household scans
    // share one server-owned product cache. Until production Functions are
    // deployed, any backend failure falls through to direct Open Food Facts so
    // barcode scanning remains usable during development/TestFlight setup.
    final cached = await _lookupViaFreshFlagBackend(barcode);
    if (cached != null) return cached;

    return _lookupDirectFromOpenFoodFacts(barcode);
  }

  Future<ProductLookupResult?> _lookupViaFreshFlagBackend(String barcode) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || Firebase.apps.isEmpty) return null;
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) return null;

      final projectId = Firebase.app().options.projectId.trim();
      if (projectId.isEmpty) return null;
      final uri = Uri.parse(
        'https://us-central1-$projectId.cloudfunctions.net/lookupProduct',
      ).replace(queryParameters: {'barcode': barcode});

      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final product = decoded['product'];
      if (product is! Map<String, dynamic>) return null;
      return ProductLookupResult.fromFreshFlagProduct(product);
    } catch (_) {
      return null;
    }
  }

  Future<ProductLookupResult?> _lookupDirectFromOpenFoodFacts(
    String barcode,
  ) async {
    final uri = Uri.https(
      _host,
      '/api/v3/product/$barcode',
      const {
        'fields':
            'code,product_name,generic_name,abbreviated_product_name,quantity,brands,image_front_small_url,image_front_url,image_url',
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
