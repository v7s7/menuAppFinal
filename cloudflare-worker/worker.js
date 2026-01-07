/**
 * Cloudflare Worker for SweetWeb WhatsApp Order Notifications
 *
 * Features:
 * - Cron-triggered WhatsApp notifications (runs every 1 minute)
 * - Firestore REST API integration (no Cloud Functions needed)
 * - Idempotent message delivery with persistent tracking
 * - OAuth token caching to reduce auth overhead
 *
 * Deployment:
 * 1. Deploy to Cloudflare Workers
 * 2. Add Cron Trigger: "* * * * *" (every minute)
 * 3. Add required secrets (see below)
 *
 * Required Secrets:
 * - FIREBASE_PROJECT_ID: Your Firebase project ID
 * - FIREBASE_CLIENT_EMAIL: Service account email
 * - FIREBASE_PRIVATE_KEY: Service account private key (full PEM format)
 * - TWILIO_ACCOUNT_SID: Twilio Account SID
 * - TWILIO_AUTH_TOKEN: Twilio Auth Token
 * - TWILIO_WHATSAPP_FROM: Twilio WhatsApp number (e.g., whatsapp:+14155238886)
 */

// Global OAuth token cache (persists across requests in same isolate)
let cachedToken = null;
let tokenExpiry = null;

// CORS headers for Flutter web app (keep for backward compatibility with email endpoints)
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

// ============================================================================
// MAIN WORKER EXPORTS
// ============================================================================

export default {
  // HTTP fetch handler (existing email endpoints)
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405, headers: corsHeaders });
    }

    try {
      const body = await request.json();
      const action = body?.action;
      const data = body?.data;

      if (!action || typeof action !== 'string') {
        return jsonResponse({ success: false, error: 'Missing action' }, 400);
      }

      // Legacy email endpoints (kept for backward compatibility)
      if (action === 'order-notification' || action === 'order-cancellation' ||
          action === 'customer-confirmation' || action === 'report') {
        return jsonResponse({
          success: false,
          error: 'Email notifications are deprecated. WhatsApp-only mode active.'
        }, 400);
      }

      return jsonResponse({ success: false, error: 'Invalid action' }, 400);
    } catch (error) {
      return jsonResponse({ success: false, error: error?.message || 'Unknown error' }, 500);
    }
  },

  // Cron trigger handler - runs every minute
  async scheduled(event, env, ctx) {
    console.log('[CRON] Starting WhatsApp notification check');

    try {
      // Get OAuth token (cached if still valid)
      const token = await getFirebaseOAuthToken(env);

      // Process pending orders (status=pending, waNewSent=false)
      await processPendingOrders(env, token);

      // Process cancelled orders (status=cancelled, waCancelSent=false)
      await processCancelledOrders(env, token);

      console.log('[CRON] Completed successfully');
    } catch (error) {
      console.error('[CRON] Error:', error.message);
    }
  },
};

// ============================================================================
// FIREBASE OAUTH TOKEN GENERATION
// ============================================================================

/**
 * Get Firebase OAuth token for Firestore REST API access
 * Uses cached token if still valid, otherwise generates new one
 */
async function getFirebaseOAuthToken(env) {
  // Return cached token if still valid (with 5 minute buffer)
  if (cachedToken && tokenExpiry && Date.now() < tokenExpiry - 300000) {
    console.log('[AUTH] Using cached OAuth token');
    return cachedToken;
  }

  console.log('[AUTH] Generating new OAuth token');

  const { FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY } = env;

  if (!FIREBASE_CLIENT_EMAIL || !FIREBASE_PRIVATE_KEY) {
    throw new Error('Missing Firebase credentials');
  }

  // Create JWT for OAuth token exchange
  const jwt = await createFirebaseJWT(FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY);

  // Exchange JWT for OAuth token
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OAuth token exchange failed: ${error}`);
  }

  const data = await response.json();

  // Cache token and expiry time
  cachedToken = data.access_token;
  tokenExpiry = Date.now() + (data.expires_in * 1000);

  console.log('[AUTH] New OAuth token cached');
  return cachedToken;
}

/**
 * Create signed JWT for Firebase service account authentication
 * Uses WebCrypto API (RS256 algorithm)
 */
async function createFirebaseJWT(clientEmail, privateKeyPem) {
  const now = Math.floor(Date.now() / 1000);
  const expiry = now + 3600; // 1 hour

  // JWT header
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };

  // JWT payload
  const payload = {
    iss: clientEmail,
    sub: clientEmail,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: expiry,
    scope: 'https://www.googleapis.com/auth/datastore',
  };

  // Encode header and payload
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  // Import private key for signing
  const privateKey = await importPrivateKey(privateKeyPem);

  // Sign the token
  const signature = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    privateKey,
    new TextEncoder().encode(unsignedToken)
  );

  // Create final JWT
  const encodedSignature = base64UrlEncode(signature);
  return `${unsignedToken}.${encodedSignature}`;
}

/**
 * Import RSA private key from PEM format for WebCrypto
 */
async function importPrivateKey(pemKey) {
  // Remove PEM headers/footers and whitespace
  const pemContents = pemKey
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\\n/g, '')
    .replace(/\s+/g, '');

  // Decode base64 to binary
  const binaryKey = base64Decode(pemContents);

  // Import key for signing
  return await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );
}

/**
 * Base64 URL encode (for JWT)
 */
function base64UrlEncode(data) {
  const bytes = typeof data === 'string'
    ? new TextEncoder().encode(data)
    : new Uint8Array(data);

  let binary = '';
  bytes.forEach(b => binary += String.fromCharCode(b));

  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/**
 * Base64 decode (for PEM key)
 */
function base64Decode(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

// ============================================================================
// FIRESTORE REST API
// ============================================================================

/**
 * Run Firestore collectionGroup query
 */
async function firestoreRunQuery(projectId, token, query) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(query),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Firestore query failed: ${error}`);
  }

  const results = await response.json();

  // Filter out empty results and extract documents
  return results
    .filter(r => r.document)
    .map(r => ({
      name: r.document.name,
      fields: r.document.fields,
      updateTime: r.document.updateTime,
    }));
}

/**
 * Commit Firestore updates with preconditions (idempotent)
 */
async function firestoreCommit(projectId, token, writes) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ writes }),
  });

  if (!response.ok) {
    const error = await response.text();
    // Precondition failures are expected (already updated) - don't throw
    if (error.includes('FAILED_PRECONDITION')) {
      console.log('[FIRESTORE] Precondition failed (already updated)');
      return null;
    }
    throw new Error(`Firestore commit failed: ${error}`);
  }

  return await response.json();
}

/**
 * Convert Firestore value to JavaScript value
 */
function firestoreValue(field) {
  if (!field) return null;
  if (field.stringValue !== undefined) return field.stringValue;
  if (field.integerValue !== undefined) return parseInt(field.integerValue);
  if (field.doubleValue !== undefined) return field.doubleValue;
  if (field.booleanValue !== undefined) return field.booleanValue;
  if (field.timestampValue !== undefined) return new Date(field.timestampValue);
  if (field.arrayValue) return field.arrayValue.values?.map(firestoreValue) || [];
  if (field.mapValue) {
    const obj = {};
    for (const [key, val] of Object.entries(field.mapValue.fields || {})) {
      obj[key] = firestoreValue(val);
    }
    return obj;
  }
  return null;
}

// ============================================================================
// ORDER PROCESSING
// ============================================================================

/**
 * Process pending orders that need WhatsApp notifications
 * Query: status=pending AND notifications.waNewSent=false
 * Limit: 10 orders per cron run
 */
async function processPendingOrders(env, token) {
  console.log('[PENDING] Checking for pending orders needing notifications');

  const { FIREBASE_PROJECT_ID } = env;

  // CollectionGroup query for all branches
  const query = {
    structuredQuery: {
      from: [{ collectionId: 'orders', allDescendants: true }],
      where: {
        compositeFilter: {
          op: 'AND',
          filters: [
            {
              fieldFilter: {
                field: { fieldPath: 'status' },
                op: 'EQUAL',
                value: { stringValue: 'pending' },
              },
            },
            {
              fieldFilter: {
                field: { fieldPath: 'notifications.waNewSent' },
                op: 'EQUAL',
                value: { booleanValue: false },
              },
            },
          ],
        },
      },
      orderBy: [{ field: { fieldPath: 'createdAt' }, direction: 'ASCENDING' }],
      limit: 10,
    },
  };

  const docs = await firestoreRunQuery(FIREBASE_PROJECT_ID, token, query);

  console.log(`[PENDING] Found ${docs.length} pending orders`);

  for (const doc of docs) {
    await processNewOrder(env, token, doc);
  }
}

/**
 * Process cancelled orders that need WhatsApp notifications
 * Query: status=cancelled AND notifications.waCancelSent=false
 * Limit: 10 orders per cron run
 */
async function processCancelledOrders(env, token) {
  console.log('[CANCELLED] Checking for cancelled orders needing notifications');

  const { FIREBASE_PROJECT_ID } = env;

  // CollectionGroup query for all branches
  const query = {
    structuredQuery: {
      from: [{ collectionId: 'orders', allDescendants: true }],
      where: {
        compositeFilter: {
          op: 'AND',
          filters: [
            {
              fieldFilter: {
                field: { fieldPath: 'status' },
                op: 'EQUAL',
                value: { stringValue: 'cancelled' },
              },
            },
            {
              fieldFilter: {
                field: { fieldPath: 'notifications.waCancelSent' },
                op: 'EQUAL',
                value: { booleanValue: false },
              },
            },
          ],
        },
      },
      orderBy: [
        { field: { fieldPath: 'status' } },
        { field: { fieldPath: 'cancelledAt' }, direction: 'ASCENDING' },
      ],
      limit: 10,
    },
  };

  const docs = await firestoreRunQuery(FIREBASE_PROJECT_ID, token, query);

  console.log(`[CANCELLED] Found ${docs.length} cancelled orders`);

  for (const doc of docs) {
    await processCancelledOrder(env, token, doc);
  }
}

/**
 * Process a single new order notification
 */
async function processNewOrder(env, token, doc) {
  try {
    const { FIREBASE_PROJECT_ID } = env;
    const fields = doc.fields;

    // Extract order data
    const orderNo = firestoreValue(fields.orderNo) || 'N/A';
    const merchantId = firestoreValue(fields.merchantId);
    const branchId = firestoreValue(fields.branchId);
    const table = firestoreValue(fields.table);
    const subtotal = firestoreValue(fields.subtotal) || 0;
    const items = firestoreValue(fields.items) || [];

    console.log(`[NEW ORDER] Processing ${orderNo} (merchant: ${merchantId}, branch: ${branchId})`);

    // Get WhatsApp config for this branch
    const configPath = `merchants/${merchantId}/branches/${branchId}/config/notifications`;
    const config = await getNotificationConfig(FIREBASE_PROJECT_ID, token, configPath);

    if (!config || !config.whatsappEnabled || !config.whatsappNumber) {
      console.log(`[NEW ORDER] WhatsApp not configured for branch ${branchId}, skipping`);
      return;
    }

    // Send WhatsApp message
    const message = formatNewOrderMessage(orderNo, table, items, subtotal);
    const twilioSid = await sendWhatsAppMessage(env, config.whatsappNumber, message);

    if (!twilioSid) {
      console.log(`[NEW ORDER] Failed to send WhatsApp for ${orderNo}`);
      return;
    }

    // Update order with notification flags (idempotent with precondition)
    const documentName = doc.name;
    await firestoreCommit(FIREBASE_PROJECT_ID, token, [
      {
        update: {
          name: documentName,
          fields: {
            'notifications.waNewSent': { booleanValue: true },
            'notifications.waNewSentAt': { timestampValue: new Date().toISOString() },
            'notifications.waNewSid': { stringValue: twilioSid },
          },
        },
        updateMask: {
          fieldPaths: [
            'notifications.waNewSent',
            'notifications.waNewSentAt',
            'notifications.waNewSid',
          ],
        },
        currentDocument: {
          exists: true,
          updateTime: doc.updateTime,
        },
      },
    ]);

    console.log(`[NEW ORDER] ✅ WhatsApp sent for ${orderNo} to ${config.whatsappNumber} (SID: ${twilioSid})`);
  } catch (error) {
    console.error(`[NEW ORDER] Error:`, error.message);
  }
}

/**
 * Process a single cancelled order notification
 */
async function processCancelledOrder(env, token, doc) {
  try {
    const { FIREBASE_PROJECT_ID } = env;
    const fields = doc.fields;

    // Extract order data
    const orderNo = firestoreValue(fields.orderNo) || 'N/A';
    const merchantId = firestoreValue(fields.merchantId);
    const branchId = firestoreValue(fields.branchId);
    const table = firestoreValue(fields.table);
    const subtotal = firestoreValue(fields.subtotal) || 0;
    const items = firestoreValue(fields.items) || [];
    const cancellationReason = firestoreValue(fields.cancellationReason);

    console.log(`[CANCELLED] Processing ${orderNo} (merchant: ${merchantId}, branch: ${branchId})`);

    // Get WhatsApp config for this branch
    const configPath = `merchants/${merchantId}/branches/${branchId}/config/notifications`;
    const config = await getNotificationConfig(FIREBASE_PROJECT_ID, token, configPath);

    if (!config || !config.whatsappEnabled || !config.whatsappNumber) {
      console.log(`[CANCELLED] WhatsApp not configured for branch ${branchId}, skipping`);
      return;
    }

    // Send WhatsApp message
    const message = formatCancelledOrderMessage(orderNo, table, items, subtotal, cancellationReason);
    const twilioSid = await sendWhatsAppMessage(env, config.whatsappNumber, message);

    if (!twilioSid) {
      console.log(`[CANCELLED] Failed to send WhatsApp for ${orderNo}`);
      return;
    }

    // Update order with notification flags (idempotent with precondition)
    const documentName = doc.name;
    await firestoreCommit(FIREBASE_PROJECT_ID, token, [
      {
        update: {
          name: documentName,
          fields: {
            'notifications.waCancelSent': { booleanValue: true },
            'notifications.waCancelSentAt': { timestampValue: new Date().toISOString() },
            'notifications.waCancelSid': { stringValue: twilioSid },
          },
        },
        updateMask: {
          fieldPaths: [
            'notifications.waCancelSent',
            'notifications.waCancelSentAt',
            'notifications.waCancelSid',
          ],
        },
        currentDocument: {
          exists: true,
          updateTime: doc.updateTime,
        },
      },
    ]);

    console.log(`[CANCELLED] ✅ WhatsApp sent for ${orderNo} to ${config.whatsappNumber} (SID: ${twilioSid})`);
  } catch (error) {
    console.error(`[CANCELLED] Error:`, error.message);
  }
}

/**
 * Get notification config for a branch
 */
async function getNotificationConfig(projectId, token, configPath) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${configPath}`;

  const response = await fetch(url, {
    headers: { 'Authorization': `Bearer ${token}` },
  });

  if (!response.ok) {
    return null;
  }

  const doc = await response.json();

  return {
    whatsappEnabled: firestoreValue(doc.fields?.whatsappEnabled) || false,
    whatsappNumber: firestoreValue(doc.fields?.whatsappNumber) || null,
  };
}

// ============================================================================
// TWILIO WHATSAPP
// ============================================================================

/**
 * Send WhatsApp message via Twilio
 * Returns Twilio message SID on success, null on failure
 */
async function sendWhatsAppMessage(env, toNumber, message) {
  const { TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_WHATSAPP_FROM } = env;

  if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_WHATSAPP_FROM) {
    console.error('[TWILIO] Missing Twilio credentials');
    return null;
  }

  // Ensure E.164 format with whatsapp: prefix
  const to = toNumber.startsWith('whatsapp:') ? toNumber : `whatsapp:${toNumber}`;

  const url = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;

  const auth = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${auth}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      From: TWILIO_WHATSAPP_FROM,
      To: to,
      Body: message,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    console.error('[TWILIO] Failed to send WhatsApp:', error);
    return null;
  }

  const result = await response.json();
  return result.sid;
}

/**
 * Format new order WhatsApp message
 */
function formatNewOrderMessage(orderNo, table, items, subtotal) {
  let message = `🔔 *New Order: ${orderNo}*\n\n`;

  if (table) {
    message += `📍 Table: ${table}\n\n`;
  }

  message += `*Items:*\n`;
  items.forEach(item => {
    const name = item.name || 'Unknown';
    const qty = item.qty || 1;
    const price = (item.price || 0).toFixed(3);
    message += `• ${name} (x${qty}) - ${price} BHD\n`;
    if (item.note) {
      message += `  _Note: ${item.note}_\n`;
    }
  });

  message += `\n*Total: ${subtotal.toFixed(3)} BHD*\n\n`;
  message += `⏰ Status: PENDING`;

  return message;
}

/**
 * Format cancelled order WhatsApp message
 */
function formatCancelledOrderMessage(orderNo, table, items, subtotal, reason) {
  let message = `❌ *Order Cancelled: ${orderNo}*\n\n`;

  if (table) {
    message += `📍 Table: ${table}\n\n`;
  }

  if (reason) {
    message += `*Reason:* ${reason}\n\n`;
  }

  message += `*Items:*\n`;
  items.forEach(item => {
    const name = item.name || 'Unknown';
    const qty = item.qty || 1;
    const price = (item.price || 0).toFixed(3);
    message += `• ${name} (x${qty}) - ${price} BHD\n`;
  });

  message += `\n*Total: ${subtotal.toFixed(3)} BHD*`;

  return message;
}

// ============================================================================
// UTILITIES
// ============================================================================

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
