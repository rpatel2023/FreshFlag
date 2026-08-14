import assert from 'node:assert/strict';
import test from 'node:test';

import {normalizeOpenFoodFactsProduct} from './product_lookup.js';

test('normalizes the FreshFlag product metadata subset', () => {
  const product = normalizeOpenFoodFactsProduct(
    '3017620422003',
    {
      product_name: 'Hazelnut Spread',
      brands: 'Ferrero',
      quantity: '400 g',
      image_front_small_url: 'https://example.test/front.jpg',
    },
    '2026-08-14T12:00:00.000Z',
  );

  assert.deepEqual(product, {
    barcode: '3017620422003',
    name: 'Hazelnut Spread',
    brand: 'Ferrero',
    imageUrl: 'https://example.test/front.jpg',
    quantityLabel: '400 g',
    source: 'openfoodfacts',
    cachedAt: '2026-08-14T12:00:00.000Z',
  });
});

test('falls back to generic name and tolerates optional metadata', () => {
  const product = normalizeOpenFoodFactsProduct('12345678', {
    product_name: ' ',
    generic_name: 'Tomato sauce',
  });

  assert.equal(product?.name, 'Tomato sauce');
  assert.equal(product?.brand, null);
  assert.equal(product?.imageUrl, null);
  assert.equal(product?.quantityLabel, null);
});

test('rejects products with no usable display name', () => {
  assert.equal(
    normalizeOpenFoodFactsProduct('12345678', {quantity: '500 g'}),
    null,
  );
});
