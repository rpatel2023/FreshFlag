import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {onRequest} from 'firebase-functions/v2/https';

const OFF_HOST = 'https://world.openfoodfacts.org';
const OFF_USER_AGENT = 'FreshFlag/1.0 (https://github.com/rpatel2023/FreshFlag)';

export interface CachedProduct {
  barcode: string;
  name: string;
  brand: string | null;
  imageUrl: string | null;
  quantityLabel: string | null;
  source: 'openfoodfacts';
  cachedAt: string;
}

export function normalizeOpenFoodFactsProduct(
  barcode: string,
  product: Record<string, unknown>,
  cachedAt = new Date().toISOString(),
): CachedProduct | null {
  const name = firstString([
    product.product_name,
    product.generic_name,
    product.abbreviated_product_name,
  ]);
  if (name == null) return null;

  return {
    barcode,
    name,
    brand: firstString([product.brands]),
    imageUrl: firstString([
      product.image_front_small_url,
      product.image_front_url,
      product.image_url,
    ]),
    quantityLabel: firstString([product.quantity]),
    source: 'openfoodfacts',
    cachedAt,
  };
}

export const lookupProduct = onRequest(
  {
    region: 'us-central1',
    timeoutSeconds: 20,
    memory: '256MiB',
    cors: true,
  },
  async (request, response) => {
    if (request.method !== 'GET') {
      response.status(405).json({error: 'method_not_allowed'});
      return;
    }

    const authorization = request.header('authorization');
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      response.status(401).json({error: 'authentication_required'});
      return;
    }

    try {
      await getAuth().verifyIdToken(authorization.substring('Bearer '.length));
    } catch {
      response.status(401).json({error: 'invalid_authentication'});
      return;
    }

    const barcode = String(request.query.barcode ?? '').trim();
    if (!/^\d{4,24}$/.test(barcode)) {
      response.status(400).json({error: 'invalid_barcode'});
      return;
    }

    const cacheRef = getFirestore().collection('productCache').doc(barcode);
    const cached = await cacheRef.get();
    if (cached.exists) {
      response.status(200).json({product: cached.data(), cached: true});
      return;
    }

    const url = new URL(`/api/v3/product/${barcode}`, OFF_HOST);
    url.searchParams.set(
      'fields',
      'code,product_name,generic_name,abbreviated_product_name,quantity,brands,image_front_small_url,image_front_url,image_url',
    );

    let upstream: globalThis.Response;
    try {
      upstream = await fetch(url, {
        headers: {
          Accept: 'application/json',
          'User-Agent': OFF_USER_AGENT,
        },
        signal: AbortSignal.timeout(8000),
      });
    } catch {
      response.status(503).json({error: 'product_service_unavailable'});
      return;
    }

    if (upstream.status === 404) {
      response.status(404).json({error: 'product_not_found'});
      return;
    }
    if (!upstream.ok) {
      response.status(502).json({error: 'product_service_error'});
      return;
    }

    let decoded: unknown;
    try {
      decoded = await upstream.json();
    } catch {
      response.status(502).json({error: 'invalid_product_response'});
      return;
    }

    if (!isRecord(decoded) || !isRecord(decoded.product)) {
      response.status(404).json({error: 'product_not_found'});
      return;
    }

    const product = normalizeOpenFoodFactsProduct(barcode, decoded.product);
    if (product == null) {
      response.status(404).json({error: 'product_not_found'});
      return;
    }

    await cacheRef.set(product);
    response.status(200).json({product, cached: false});
  },
);

function firstString(values: unknown[]): string | null {
  for (const value of values) {
    if (typeof value !== 'string') continue;
    const trimmed = value.trim();
    if (trimmed.length > 0) return trimmed;
  }
  return null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}
