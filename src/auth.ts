import { getAccessTokenFor } from "./auth-cache.js";

export interface AuthContext {
  getAccessToken(): Promise<string>;
  getAuthHeaders(): Promise<{ "Content-Type": string; Authorization: string }>;
}

export function createAuthContext(params: {
  userCode: string;
  secretKey: string;
}): AuthContext {
  const { userCode, secretKey } = params;

  if (!userCode || !secretKey) {
    throw new Error("SUREM_USER_CODE, SUREM_SECRET_KEY 값이 필요합니다");
  }

  return {
    getAccessToken() {
      return getAccessTokenFor(userCode, secretKey);
    },
    async getAuthHeaders() {
      const token = await getAccessTokenFor(userCode, secretKey);
      return {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`
      };
    }
  };
}
