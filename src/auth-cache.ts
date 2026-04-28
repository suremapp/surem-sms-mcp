import { createHash } from "crypto";
import axios from "axios";

const BASE_URL = "https://rest.surem.com/api/v1";
const TOKEN_TTL_MS = 50 * 60 * 1000;

interface CacheEntry {
  token: string;
  expiry: number;
}

const cache = new Map<string, CacheEntry>();
const inflight = new Map<string, Promise<string>>();

function keyOf(userCode: string, secretKey: string): string {
  return createHash("sha256").update(`${userCode}:${secretKey}`).digest("hex");
}

async function fetchToken(userCode: string, secretKey: string): Promise<string> {
  const res = await axios.post(`${BASE_URL}/auth/token`, {
    userCode,
    secretKey
  });
  return res.data.data.accessToken as string;
}

export async function getAccessTokenFor(userCode: string, secretKey: string): Promise<string> {
  const key = keyOf(userCode, secretKey);
  const hit = cache.get(key);
  if (hit && Date.now() < hit.expiry) {
    return hit.token;
  }

  const existing = inflight.get(key);
  if (existing) return existing;

  const p = (async () => {
    try {
      const token = await fetchToken(userCode, secretKey);
      cache.set(key, { token, expiry: Date.now() + TOKEN_TTL_MS });
      return token;
    } finally {
      inflight.delete(key);
    }
  })();

  inflight.set(key, p);
  return p;
}

export function invalidateAuthCache(userCode: string, secretKey: string): void {
  cache.delete(keyOf(userCode, secretKey));
}
