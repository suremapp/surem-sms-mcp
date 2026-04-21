import axios from "axios";

const BASE_URL = "https://rest.surem.com/api/v1";

let cachedToken: string | null = null;
let tokenExpiry: number = 0;

export async function getAccessToken(): Promise<string> {
  if (cachedToken && Date.now() < tokenExpiry) {
    return cachedToken;
  }

  const userCode = process.env.SUREM_USER_CODE;
  const secretKey = process.env.SUREM_SECRET_KEY;

  if (!userCode || !secretKey) {
    throw new Error("SUREM_USER_CODE, SUREM_SECRET_KEY 환경변수가 필요합니다");
  }

  const res = await axios.post(`${BASE_URL}/auth/token`, {
    userCode,
    secretKey
  });

  cachedToken = res.data.data.accessToken;
  tokenExpiry = Date.now() + 50 * 60 * 1000; // 50분 캐싱

  return cachedToken!;
}

export async function getAuthHeaders() {
  const token = await getAccessToken();
  return {
    "Content-Type": "application/json",
    Authorization: `Bearer ${token}`
  };
}
