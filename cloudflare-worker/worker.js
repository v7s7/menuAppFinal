/**
 * Cloudflare Worker - WhatsApp Order Notifications (merchant-only)
 *
 * Required secrets:
 * - FIREBASE_SERVICE_ACCOUNT_BASE64 (base64 of service-account json)
 * - TWILIO_ACCOUNT_SID
 * - TWILIO_AUTH_TOKEN
 * Optional secret:
 * - ENABLED_BRANCHES  e.g. [{"merchantId":"aziz-burgers","branchId":"main"}]
 *
 * Required vars (recommended, but now optional because we fallback):
 * - FIREBASE_PROJECT_ID (fallbacks to service account project_id if missing)
 * - TWILIO_WHATSAPP_NUMBER (From number; can be +... or whatsapp:+...)
 */

// OAuth token cache
let cachedToken = null;
let tokenExpiryMs = 0;

// Service account cache
let cachedServiceAccount = null;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
    return new Response("Cron-only worker", { status: 200, headers: corsHeaders });
  },

  async scheduled(event, env, ctx) {
    console.log("[CRON] Starting WhatsApp notification check");

    try {
      const projectId = await getFirebaseProjectId(env);
      console.log(`[CONFIG] Using FIREBASE_PROJECT_ID=${projectId}`);

      const token = await getFirebaseOAuthToken(env);

      const enabledBranches = parseEnabledBranches(env);
      if (enabledBranches.length > 0) {
        for (const b of enabledBranches) {
          await processBranch(env, token, projectId, b.merchantId, b.branchId);
        }
      } else {
        console.log("[SCAN] ENABLED_BRANCHES not set → running collectionGroup scan");
        await processAllBranchesByCollectionGroup(env, token, projectId);
      }

      console.log("[CRON] Completed successfully");
    } catch (error) {
      console.error("[CRON] Error:", error?.message || error);
    }
  },
};

// ============================================================================
// CONFIG
// ============================================================================

function parseEnabledBranches(env) {
  const raw = env.ENABLED_BRANCHES;
  if (!raw) return [];

  let s = String(raw).trim();

  // If user saved it with wrapping quotes, strip them
  if (
    (s.startsWith("'") && s.endsWith("'")) ||
    (s.startsWith('"') && s.endsWith('"'))
  ) {
    s = s.slice(1, -1).trim();
  }

  try {
    const arr = JSON.parse(s);
    if (!Array.isArray(arr)) return [];
    return arr
      .filter((x) => x && typeof x.merchantId === "string" && typeof x.branchId === "string")
      .map((x) => ({ merchantId: x.merchantId, branchId: x.branchId }));
  } catch {
    console.warn("[CONFIG] ENABLED_BRANCHES is not valid JSON. Ignoring.");
    return [];
  }
}

// ============================================================================
// SERVICE ACCOUNT + PROJECT ID
// ============================================================================

async function getServiceAccount(env) {
  if (cachedServiceAccount) return cachedServiceAccount;

  const saB64 = env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (!saB64) {
    throw new Error("Missing FIREBASE_SERVICE_ACCOUNT_BASE64 secret");
  }

  try {
    cachedServiceAccount = JSON.parse(atob(saB64));
    return cachedServiceAccount;
  } catch {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_BASE64 is not valid base64 JSON");
  }
}

async function getFirebaseProjectId(env) {
  if (env.FIREBASE_PROJECT_ID && String(env.FIREBASE_PROJECT_ID).trim()) {
    return String(env.FIREBASE_PROJECT_ID).trim();
  }

  const sa = await getServiceAccount(env);
  if (sa?.project_id) return sa.project_id;

  throw new Error("Missing FIREBASE_PROJECT_ID and service account has no project_id");
}

// ============================================================================
// FIREBASE OAUTH
// ============================================================================

async function getFirebaseOAuthToken(env) {
  const now = Date.now();
  if (cachedToken && now < tokenExpiryMs - 5 * 60 * 1000) {
    console.log("[AUTH] Using cached OAuth token");
    return cachedToken;
  }

  console.log("[AUTH] Generating new OAuth token");

  const sa = await getServiceAccount(env);
  const jwt = await createFirebaseJWT(sa.client_email, sa.private_key);

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!resp.ok) {
    const t = await resp.text();
    throw new Error(`OAuth token exchange failed: ${t}`);
  }

  const data = await resp.json();
  cachedToken = data.access_token;
  tokenExpiryMs = Date.now() + (data.expires_in * 1000);

  console.log("[AUTH] New OAuth token cached");
  return cachedToken;
}

async function createFirebaseJWT(clientEmail, privateKeyPem) {
  const now = Math.floor(Date.now() / 1000);
  const exp = now + 3600;

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: clientEmail,
    sub: clientEmail,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp,
    scope: "https://www.googleapis.com/auth/datastore",
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  const key = await importPrivateKey(privateKeyPem);

  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    key,
    new TextEncoder().encode(unsignedToken)
  );

  return `${unsignedToken}.${base64UrlEncode(signature)}`;
}

async function importPrivateKey(pem) {
  const clean = String(pem)
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\r?\n/g, "")
    .replace(/\s+/g, "");

  const binaryDer = base64DecodeToArrayBuffer(clean);

  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
}

function base64UrlEncode(data) {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64DecodeToArrayBuffer(b64) {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes.buffer;
}

// ============================================================================
// PROCESSING
// ============================================================================

async function processBranch(env, token, projectId, merchantId, branchId) {
  console.log(`[BRANCH] Processing ${merchantId}/${branchId}`);

  const config = await getNotificationConfig(env, token, projectId, merchantId, branchId);
  if (!config?.whatsappEnabled || !config?.whatsappNumber) {
    console.log(`[BRANCH] WhatsApp disabled/not set for ${merchantId}/${branchId}`);
    return;
  }

  const newDocs = await runQueryUnderBranch(env, token, projectId, merchantId, branchId, {
    status: "pending",
    flagField: "waNewSent",
  });

  console.log(`[BRANCH] Found ${newDocs.length} pending orders`);
  for (const d of newDocs) {
    await processNewOrder(env, token, projectId, d, merchantId, branchId, config);
    await sleep(1100);
  }

  const cancelDocs = await runQueryUnderBranch(env, token, projectId, merchantId, branchId, {
    status: "cancelled",
    flagField: "waCancelSent",
  });

  console.log(`[BRANCH] Found ${cancelDocs.length} cancelled orders`);
  for (const d of cancelDocs) {
    await processCancelledOrder(env, token, projectId, d, merchantId, branchId, config);
    await sleep(1100);
  }
}

async function processAllBranchesByCollectionGroup(env, token, projectId) {
  const pendingDocs = await runCollectionGroupQuery(env, token, projectId, {
    status: "pending",
    flagPath: "notifications.waNewSent",
  });

  console.log(`[SCAN] Found ${pendingDocs.length} pending orders`);
  for (const d of pendingDocs) {
    const info = parseOrderPath(d.name);
    if (!info) continue;
    const config = await getNotificationConfig(env, token, projectId, info.merchantId, info.branchId);
    if (!config?.whatsappEnabled || !config?.whatsappNumber) continue;
    await processNewOrder(env, token, projectId, d, info.merchantId, info.branchId, config);
    await sleep(1100);
  }

  const cancelledDocs = await runCollectionGroupQuery(env, token, projectId, {
    status: "cancelled",
    flagPath: "notifications.waCancelSent",
  });

  console.log(`[SCAN] Found ${cancelledDocs.length} cancelled orders`);
  for (const d of cancelledDocs) {
    const info = parseOrderPath(d.name);
    if (!info) continue;
    const config = await getNotificationConfig(env, token, projectId, info.merchantId, info.branchId);
    if (!config?.whatsappEnabled || !config?.whatsappNumber) continue;
    await processCancelledOrder(env, token, projectId, d, info.merchantId, info.branchId, config);
    await sleep(1100);
  }
}

// ============================================================================
// FIRESTORE QUERIES
// ============================================================================

async function runQueryUnderBranch(env, token, projectId, merchantId, branchId, { status, flagField }) {
  const parent = `merchants/${merchantId}/branches/${branchId}`;

  const query = {
    structuredQuery: {
      from: [{ collectionId: "orders" }],
      where: {
        compositeFilter: {
          op: "AND",
          filters: [
            {
              fieldFilter: {
                field: { fieldPath: "status" },
                op: "EQUAL",
                value: { stringValue: status },
              },
            },
            {
              fieldFilter: {
                field: { fieldPath: `notifications.${flagField}` },
                op: "EQUAL",
                value: { booleanValue: false },
              },
            },
          ],
        },
      },
      orderBy: [{ field: { fieldPath: "createdAt" }, direction: "ASCENDING" }],
      limit: 10,
    },
  };

  return firestoreRunQuery(projectId, token, query, parent);
}

async function runCollectionGroupQuery(env, token, projectId, { status, flagPath }) {
  const query = {
    structuredQuery: {
      from: [{ collectionId: "orders", allDescendants: true }],
      where: {
        compositeFilter: {
          op: "AND",
          filters: [
            {
              fieldFilter: {
                field: { fieldPath: "status" },
                op: "EQUAL",
                value: { stringValue: status },
              },
            },
            {
              fieldFilter: {
                field: { fieldPath: flagPath },
                op: "EQUAL",
                value: { booleanValue: false },
              },
            },
          ],
        },
      },
      orderBy: [{ field: { fieldPath: "createdAt" }, direction: "ASCENDING" }],
      limit: 10,
    },
  };

  return firestoreRunQuery(projectId, token, query, null);
}

async function firestoreRunQuery(projectId, token, query, parentPathOrNull) {
  const base = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  const url = parentPathOrNull ? `${base}/${parentPathOrNull}:runQuery` : `${base}:runQuery`;

  const resp = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(query),
  });

  if (!resp.ok) {
    const t = await resp.text();
    throw new Error(`Firestore runQuery failed: ${t}`);
  }

  const results = await resp.json();
  return (results || [])
    .filter((r) => r.document)
    .map((r) => ({
      name: r.document.name,
      fields: r.document.fields || {},
      updateTime: r.document.updateTime,
    }));
}

async function firestoreCommit(projectId, token, writes) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;

  const resp = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ writes }),
  });

  if (!resp.ok) {
    const t = await resp.text();
    if (t.includes("FAILED_PRECONDITION")) {
      console.log("[FIRESTORE] Precondition failed (already updated)");
      return null;
    }
    throw new Error(`Firestore commit failed: ${t}`);
  }

  return resp.json();
}

function parseOrderPath(documentName) {
  const parts = documentName.split("/documents/")[1]?.split("/") || [];
  const mi = parts.indexOf("merchants");
  const bi = parts.indexOf("branches");
  const oi = parts.indexOf("orders");
  if (mi === -1 || bi === -1 || oi === -1) return null;
  return { merchantId: parts[mi + 1], branchId: parts[bi + 1], orderId: parts[oi + 1] };
}

async function getNotificationConfig(env, token, projectId, merchantId, branchId) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/merchants/${merchantId}/branches/${branchId}/config/notifications`;

  const resp = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (resp.status === 404) return null;
  if (!resp.ok) return null;

  const doc = await resp.json();
  return {
    whatsappEnabled: firestoreValue(doc.fields?.whatsappEnabled) || false,
    whatsappNumber: firestoreValue(doc.fields?.whatsappNumber) || null,
  };
}

function firestoreValue(field) {
  if (!field) return null;
  if (field.stringValue !== undefined) return field.stringValue;
  if (field.integerValue !== undefined) return parseInt(field.integerValue, 10);
  if (field.doubleValue !== undefined) return field.doubleValue;
  if (field.booleanValue !== undefined) return field.booleanValue;
  if (field.timestampValue !== undefined) return new Date(field.timestampValue);
  if (field.arrayValue) return (field.arrayValue.values || []).map(firestoreValue);
  if (field.mapValue) {
    const obj = {};
    const fs = field.mapValue.fields || {};
    for (const [k, v] of Object.entries(fs)) obj[k] = firestoreValue(v);
    return obj;
  }
  return null;
}

// ============================================================================
// ORDER HANDLERS
// ============================================================================

async function processNewOrder(env, token, projectId, doc, merchantId, branchId, config) {
  try {
    const fields = doc.fields || {};
    const orderNo = firestoreValue(fields.orderNo) || "N/A";
    const table = firestoreValue(fields.table);
    const subtotal = Number(firestoreValue(fields.subtotal) || 0);
    const items = firestoreValue(fields.items) || [];

    console.log(`[NEW] Processing ${orderNo} (${merchantId}/${branchId})`);

    const message = formatNewOrderMessage(orderNo, table, items, subtotal);
    const sid = await sendWhatsAppMessage(env, config.whatsappNumber, message);
    if (!sid) return;

    const writes = [
      buildNotificationsUpdateWrite(doc.name, doc.updateTime, {
        waNewSent: true,
        waNewSentAt: new Date().toISOString(),
        waNewSid: sid,
      }),
    ];

    await firestoreCommit(projectId, token, writes);
    console.log(`[NEW] ✅ Sent ${orderNo} to ${config.whatsappNumber} (SID: ${sid})`);
  } catch (e) {
    console.error("[NEW] Error:", e?.message || e);
  }
}

async function processCancelledOrder(env, token, projectId, doc, merchantId, branchId, config) {
  try {
    const fields = doc.fields || {};
    const orderNo = firestoreValue(fields.orderNo) || "N/A";
    const table = firestoreValue(fields.table);
    const subtotal = Number(firestoreValue(fields.subtotal) || 0);
    const items = firestoreValue(fields.items) || [];
    const reason = firestoreValue(fields.cancellationReason);

    console.log(`[CANCEL] Processing ${orderNo} (${merchantId}/${branchId})`);

    const message = formatCancelledOrderMessage(orderNo, table, items, subtotal, reason);
    const sid = await sendWhatsAppMessage(env, config.whatsappNumber, message);
    if (!sid) return;

    const writes = [
      buildNotificationsUpdateWrite(doc.name, doc.updateTime, {
        waCancelSent: true,
        waCancelSentAt: new Date().toISOString(),
        waCancelSid: sid,
      }),
    ];

    await firestoreCommit(projectId, token, writes);
    console.log(`[CANCEL] ✅ Sent ${orderNo} to ${config.whatsappNumber} (SID: ${sid})`);
  } catch (e) {
    console.error("[CANCEL] Error:", e?.message || e);
  }
}

function buildNotificationsUpdateWrite(documentName, updateTime, notifFields) {
  const notifMap = {};
  const mask = [];

  for (const [k, v] of Object.entries(notifFields)) {
    mask.push(`notifications.${k}`);
    if (typeof v === "boolean") notifMap[k] = { booleanValue: v };
    else if (typeof v === "string") {
      if (k.endsWith("At")) notifMap[k] = { timestampValue: v };
      else notifMap[k] = { stringValue: v };
    } else if (typeof v === "number") notifMap[k] = { doubleValue: v };
  }

  // FIX: currentDocument is a oneof (exists OR updateTime). Never set both.
  const currentDocument = updateTime ? { updateTime } : { exists: true };

  const write = {
    update: {
      name: documentName,
      fields: {
        notifications: {
          mapValue: { fields: notifMap },
        },
      },
    },
    updateMask: { fieldPaths: mask },
    currentDocument,
  };

  return write;
}

// ============================================================================
// TWILIO
// ============================================================================

async function sendWhatsAppMessage(env, toNumber, message) {
  const sid = env.TWILIO_ACCOUNT_SID;
  const token = env.TWILIO_AUTH_TOKEN;

  const fromRaw = env.TWILIO_WHATSAPP_FROM || env.TWILIO_WHATSAPP_NUMBER;
  if (!sid || !token || !fromRaw) {
    console.error("[TWILIO] Missing Twilio credentials (SID/TOKEN/FROM)");
    return null;
  }

  const from = asWhatsAppAddress(fromRaw);
  const to = asWhatsAppAddress(toNumber);

  const url = `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`;
  const auth = btoa(`${sid}:${token}`);

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      From: from,
      To: to,
      Body: message,
    }),
  });

  if (!resp.ok) {
    const t = await resp.text();
    console.error("[TWILIO] Failed:", t);
    return null;
  }

  const data = await resp.json();
  return data.sid;
}

function asWhatsAppAddress(n) {
  if (!n) return n;
  return n.startsWith("whatsapp:") ? n : `whatsapp:${n}`;
}

// ============================================================================
// MESSAGES
// ============================================================================

function formatNewOrderMessage(orderNo, table, items, subtotal) {
  let msg = `🔔 *New Order: ${orderNo}*\n\n`;
  if (table) msg += `📍 Table: ${table}\n\n`;

  msg += `*Items:*\n`;
  for (const it of items) {
    const name = it?.name || "Unknown";
    const qty = Number(it?.qty || 1);
    const price = Number(it?.price || 0);
    const lineTotal = (price * qty).toFixed(3);
    msg += `• ${name} (x${qty}) - ${lineTotal} BHD\n`;
    if (it?.note) msg += `  _Note: ${it.note}_\n`;
  }

  msg += `\n*Total: ${Number(subtotal).toFixed(3)} BHD*\n\n`;
  msg += `⏰ Status: PENDING`;
  return msg;
}

function formatCancelledOrderMessage(orderNo, table, items, subtotal, reason) {
  let msg = `❌ *Order Cancelled: ${orderNo}*\n\n`;
  if (table) msg += `📍 Table: ${table}\n\n`;
  if (reason) msg += `*Reason:* ${reason}\n\n`;

  msg += `*Items:*\n`;
  for (const it of items) {
    const name = it?.name || "Unknown";
    const qty = Number(it?.qty || 1);
    const price = Number(it?.price || 0);
    const lineTotal = (price * qty).toFixed(3);
    msg += `• ${name} (x${qty}) - ${lineTotal} BHD\n`;
  }

  msg += `\n*Total: ${Number(subtotal).toFixed(3)} BHD*`;
  return msg;
}

// ============================================================================
// UTILS
// ============================================================================

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}
