import axios from "axios";
import iconv from "iconv-lite";
import { getAuthHeaders } from "../auth.js";

const BASE_URL = "https://rest.surem.com/api/v1";

const SMS_MAX_BYTES = 90;
const LMS_MAX_BYTES = 2000;

function getEucKrByteLength(text: string): number {
  return iconv.encode(text, "euc-kr").length;
}

function detectMessageType(text: string): "sms" | "lms" {
  const bytes = getEucKrByteLength(text);
  return bytes <= SMS_MAX_BYTES ? "sms" : "lms";
}

function validateMessageLength(text: string): void {
  const bytes = getEucKrByteLength(text);
  if (bytes > LMS_MAX_BYTES) {
    throw new Error(`메시지가 너무 깁니다. (${bytes}바이트 / 최대 ${LMS_MAX_BYTES}바이트)`);
  }
}

export async function sendMessage(
  to: string,
  text: string,
  reqPhone: string,
  subject?: string,
  reservedTime?: string
) {
  validateMessageLength(text);

  const type = detectMessageType(text);
  const bytes = getEucKrByteLength(text);
  const headers = await getAuthHeaders();
  const scheduled = Boolean(reservedTime);

  if (type === "sms") {
    const res = await axios.post(
      `${BASE_URL}/send/sms`,
      { to, text, reqPhone, ...(reservedTime ? { reservedTime } : {}) },
      { headers }
    );
    return { ...res.data, _meta: { type: "SMS", bytes, scheduled, reservedTime } };
  } else {
    const res = await axios.post(
      `${BASE_URL}/send/mms`,
      {
        to,
        subject: subject ?? "메시지",
        text,
        reqPhone,
        ...(reservedTime ? { reservedTime } : {})
      },
      { headers }
    );
    return { ...res.data, _meta: { type: "LMS", bytes, scheduled, reservedTime } };
  }
}
