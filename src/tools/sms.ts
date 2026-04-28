import axios from "axios";
import iconv from "iconv-lite";
import type { AuthContext } from "../auth.js";

const BASE_URL = "https://rest.surem.com/api/v1";

const SMS_MAX_BYTES = 90;
const LMS_MAX_BYTES = 2000;
const INTL_MAX_CHARS = 500;
const TTS_MAX_CHARS = 90;

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

function isAsciiOnly(text: string): boolean {
  for (let i = 0; i < text.length; i++) {
    if (text.charCodeAt(i) > 0x7f) return false;
  }
  return true;
}

function codepointLength(text: string): number {
  let n = 0;
  for (const _ of text) n++;
  return n;
}

export async function sendMessage(
  auth: AuthContext,
  to: string,
  text: string,
  reqPhone: string,
  subject?: string,
  reservedTime?: string,
  imageKey?: string
) {
  validateMessageLength(text);

  const headers = await auth.getAuthHeaders();
  const scheduled = Boolean(reservedTime);
  const bytes = getEucKrByteLength(text);

  // imageKey 가 있으면 MMS 발송 (이미지 첨부), 없으면 길이로 SMS/LMS 자동
  if (imageKey) {
    const body: Record<string, unknown> = {
      to,
      subject: subject ?? "메시지",
      text,
      reqPhone,
      imageKey,
      ...(reservedTime ? { reservedTime } : {})
    };
    const res = await axios.post(`${BASE_URL}/send/mms`, body, { headers });
    return {
      ...res.data,
      _meta: {
        type: "MMS",
        bytes,
        scheduled,
        reservedTime,
        imageKey
      }
    };
  }

  const type = detectMessageType(text);

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

export async function sendTtsMessage(
  auth: AuthContext,
  to: string,
  text: string,
  reqPhone: string
) {
  const charLen = codepointLength(text);
  if (charLen === 0) {
    throw new Error("메시지 내용이 비어 있습니다.");
  }
  if (charLen > TTS_MAX_CHARS) {
    throw new Error(
      `TTS 메시지는 최대 ${TTS_MAX_CHARS} 글자까지 가능합니다. (현재: ${charLen}자)`
    );
  }

  const headers = await auth.getAuthHeaders();
  const res = await axios.post(
    `${BASE_URL}/send/tts`,
    { to, text, reqPhone },
    { headers }
  );
  return {
    ...res.data,
    _meta: {
      type: "TTS",
      charLength: charLen
    }
  };
}

export async function sendInternationalMessage(
  auth: AuthContext,
  country: string,
  to: string,
  text: string,
  reqPhone: string
) {
  // 한국(82) 은 send_message 로 처리해야 함 — 국제 엔드포인트로 보내지 않음
  if (country === "82") {
    throw new Error(
      "한국(국가코드 82) 은 send_international_message 가 아닌 send_message 도구로 발송하세요."
    );
  }
  const charLen = codepointLength(text);
  if (charLen === 0) {
    throw new Error("메시지 내용이 비어 있습니다.");
  }
  if (charLen > INTL_MAX_CHARS) {
    throw new Error(
      `국제 메시지는 최대 ${INTL_MAX_CHARS} 글자까지 가능합니다. (현재: ${charLen}자)`
    );
  }
  // 중국(86) 은 SureM 정책상 항상 unicode 모드로 처리됨 — 클라이언트는 단순 패스스루
  const ascii = isAsciiOnly(text);

  const headers = await auth.getAuthHeaders();
  const res = await axios.post(
    `${BASE_URL}/send/intl`,
    { country, to, text, reqPhone },
    { headers }
  );
  return {
    ...res.data,
    _meta: {
      type: "INTL",
      country,
      ascii,
      charLength: charLen
    }
  };
}
