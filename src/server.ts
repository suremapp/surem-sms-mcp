import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendMessage, sendInternationalMessage, sendTtsMessage } from "./tools/sms.js";
import { uploadImages } from "./tools/image.js";
import { createAuthContext } from "./auth.js";

export interface ServerContext {
  userCode: string;
  secretKey: string;
  /**
   * 이미지 관련 도구 (upload_mms_image + send_message 의 imageKey 파라미터) 활성화 여부.
   * stdio 모드에서는 true (서버가 사용자 PC 의 파일을 직접 read 하므로 안전).
   * 원격 모드에서는 false — Claude Desktop 이 이미지를 transcoding 해서 깨진 이미지가 발송될 수 있음.
   */
  includeImageTools?: boolean;
}

export function createServer(ctx: ServerContext) {
  const auth = createAuthContext({ userCode: ctx.userCode, secretKey: ctx.secretKey });
  const includeImage = ctx.includeImageTools === true;

  const server = new McpServer({
    name: "surem-sms-mcp",
    version: "1.0.3"
  });

  // ===== send_message =====
  // 이미지 도구가 활성화된 경우(stdio 모드)에만 imageKey 파라미터 노출.
  const sendMessageSchema = {
    to:           z.string().describe("수신자 전화번호 (예: 01012345678)"),
    text:         z.string().describe("발송할 메시지 내용"),
    reqPhone:     z
      .string()
      .describe("발신번호 (예: 15884640). 반드시 사용자가 직접 제공한 값을 사용. 사용자가 발신번호를 지정하지 않았다면 추측하거나 수신번호로 대체하지 말고 먼저 사용자에게 확인할 것 (사용자가 명시적으로 요청한 경우는 그 값을 그대로 사용)."),
    subject:      z.string().optional().describe("LMS 제목 (메시지가 길 경우 사용, 기본값: '메시지')"),
    reservedTime: z
      .string()
      .regex(/^\d{14}$/, "yyyyMMddhhmmss 형식이어야 합니다 (예: 20260420150000)")
      .optional()
      .describe("예약 발송 시각 (yyyyMMddhhmmss, 미입력 시 즉시 발송). 예약 취소는 슈어비즈 → 예약,결과 → 예약조회 메뉴에서 수동으로 진행"),
    ...(includeImage
      ? {
          imageKey: z
            .string()
            .optional()
            .describe("MMS 첨부 이미지 키. upload_mms_image 도구로 1~3장 업로드 후 받은 단일 imageKey 값. 지정 시 MMS 모드로 발송됨.")
        }
      : {})
  };

  const sendMessageDescription = includeImage
    ? "슈어엠 API로 국내(한국) 문자를 발송합니다. 텍스트 길이에 따라 SMS(90바이트 이하) / LMS(91~2000바이트) 가 자동 선택됩니다. imageKey 를 함께 전달하면 MMS 로 발송됩니다 (먼저 upload_mms_image 도구로 imageKey 를 발급받아야 함). reservedTime 을 지정하면 예약 발송. 한국이 아닌 국가는 send_international_message 사용. ⚠️ 사용자가 발신번호(reqPhone)를 명시하지 않았다면 절대 추측하거나 수신번호와 동일한 값을 넣지 말고, 반드시 사용자에게 '슈어비즈에 사전 등록된 발신번호'를 직접 물어본 뒤 호출하세요."
    : "슈어엠 API로 국내(한국) 문자를 발송합니다. 텍스트 길이에 따라 SMS(90바이트 이하) / LMS(91~2000바이트) 가 자동 선택됩니다. reservedTime 을 지정하면 예약 발송. 한국이 아닌 국가는 send_international_message 사용. ⚠️ 사용자가 발신번호(reqPhone)를 명시하지 않았다면 절대 추측하거나 수신번호와 동일한 값을 넣지 말고, 반드시 사용자에게 '슈어비즈에 사전 등록된 발신번호'를 직접 물어본 뒤 호출하세요.";

  server.registerTool(
    "send_message",
    {
      description: sendMessageDescription,
      inputSchema: sendMessageSchema
    },
    async (args: Record<string, unknown>) => {
      try {
        const to = args.to as string;
        const text = args.text as string;
        const reqPhone = args.reqPhone as string;
        const subject = args.subject as string | undefined;
        const reservedTime = args.reservedTime as string | undefined;
        const imageKey = includeImage ? (args.imageKey as string | undefined) : undefined;

        const result = await sendMessage(auth, to, text, reqPhone, subject, reservedTime, imageKey);
        const meta = result._meta;
        const body = { ...result };
        delete body._meta;

        const isScheduled = Boolean(meta?.scheduled);
        const imgPart = meta?.imageKey ? ` / imageKey=${meta.imageKey}` : "";
        const header = isScheduled
          ? `[${meta.type} 예약발송 / ${meta.bytes}바이트${imgPart} / 예약시각 ${meta.reservedTime}]`
          : `[${meta.type} 발송 / ${meta.bytes}바이트${imgPart}]`;

        return {
          content: [{
            type: "text",
            text: `${header}\n${JSON.stringify(body, null, 2)}`
          }]
        };
      } catch (error: any) {
        return {
          content: [{ type: "text", text: `발송 실패: ${error.message}` }],
          isError: true
        };
      }
    }
  );

  // ===== upload_mms_image (이미지 도구 활성 시에만) =====
  if (includeImage) {
  server.registerTool(
    "upload_mms_image",
    {
      description:
        "MMS 발송에 사용할 이미지 1~3장을 슈어엠 서버에 업로드하고 단일 imageKey 를 반환합니다. 받은 imageKey 를 send_message 의 imageKey 파라미터에 전달해 MMS 로 발송. ⚠️ 이미지 규격: 확장자 jpg, 한 장 500KB 이하, 가로/세로 1000px 이하, 합산 1MB 미만. 입력은 서버 프로세스가 접근 가능한 로컬 jpg 파일 경로(path).",
      inputSchema: {
        images: z
          .array(
            z.object({
              path:     z.string().describe("로컬 jpg 파일 경로 (예: 'F:/test/image.jpg'). 서버 프로세스가 접근 가능해야 함."),
              filename: z.string().optional().describe("파일명 override (선택, 기본은 path 의 basename)")
            })
          )
          .min(1)
          .max(3)
          .describe("업로드할 이미지 배열 (1~3장). 각 이미지는 jpg, 500KB 이하, 합산 1MB 미만.")
      }
    },
    async ({ images }) => {
      try {
        const uploaded = await uploadImages(auth, images);
        return {
          content: [
            {
              type: "text",
              text:
                `[이미지 ${images.length}장 업로드 완료]\n` +
                `  imageKey  = ${uploaded.imageKey}\n` +
                `  expiresAt = ${uploaded.expiryDate || "-"}\n\n` +
                `다음 단계: send_message 호출 시 imageKey="${uploaded.imageKey}" 전달.`
            }
          ]
        };
      } catch (error: any) {
        return {
          content: [{ type: "text", text: `이미지 업로드 실패: ${error.message}` }],
          isError: true
        };
      }
    }
  );
  }

  // ===== send_tts =====
  server.registerTool(
    "send_tts",
    {
      description:
        "텍스트를 음성으로 변환해 전화 통화로 발송하는 TTS(Text-to-Speech) 도구입니다. 수신자의 휴대폰으로 전화가 걸리며 입력된 텍스트가 음성 안내로 재생됩니다. 메시지는 최대 90 글자. ⚠️ 발신번호(reqPhone)를 사용자가 명시하지 않았다면 절대 추측하지 말고 반드시 사용자에게 '슈어비즈에 사전 등록된 발신번호'를 직접 물어본 뒤 호출하세요.",
      inputSchema: {
        to:       z.string().describe("수신자 전화번호 (예: 01012345678)"),
        text:     z.string().describe("음성으로 변환할 메시지 내용 (최대 90자)"),
        reqPhone: z
          .string()
          .describe("발신번호 (예: 15884640). 반드시 사용자가 직접 제공한 값을 사용. 사용자가 발신번호를 지정하지 않았다면 추측하거나 수신번호로 대체하지 말고 먼저 사용자에게 확인할 것 (사용자가 명시적으로 요청한 경우는 그 값을 그대로 사용).")
      }
    },
    async ({ to, text, reqPhone }) => {
      try {
        const result = await sendTtsMessage(auth, to, text, reqPhone);
        const meta = result._meta;
        const body = { ...result };
        delete body._meta;

        const header = `[TTS 발송 / ${meta.charLength}자]`;

        return {
          content: [{
            type: "text",
            text: `${header}\n${JSON.stringify(body, null, 2)}`
          }]
        };
      } catch (error: any) {
        return {
          content: [{ type: "text", text: `TTS 발송 실패: ${error.message}` }],
          isError: true
        };
      }
    }
  );

  // ===== send_international_message =====
  server.registerTool(
    "send_international_message",
    {
      description:
        "한국이 아닌 국가로 국제 SMS 메시지를 발송합니다. 국가 코드(country)와 함께 호출. ⚠️ 한국(82) 은 이 도구를 사용하지 말고 send_message 로 발송하세요. 텍스트 길이는 최대 500 글자. ASCII 만 포함된 경우 160 byte / SMS, 유니코드 포함 시 70자 / SMS 기준으로 초과 시 서버에서 자동 concat(LMS) 처리. 중국(86) 은 슈어엠 정책상 항상 유니코드 모드로 계산됨. 국제 발송의 발신번호는 슈어비즈 사전 등록 여부와 무관하게 사용 가능 (국내 send_message 와 다름).",
      inputSchema: {
        country:  z
          .string()
          .regex(/^\d+$/, "숫자만 입력 (+ / 00 / 하이픈 등 제외)")
          .describe("국가 코드 (예: '81' 일본, '86' 중국, '1' 미국, '44' 영국). 한국(82) 은 send_message 사용. + 또는 00 prefix 없이 숫자만."),
        to:       z.string().describe("수신자 전화번호 — 국가코드 제외. 예: 일본 '9012345678'"),
        text:     z.string().describe("발송할 메시지 내용 (최대 500글자)"),
        reqPhone: z
          .string()
          .describe("발신번호 (예: 15884640). 사용자가 지정하는 번호 그대로 사용. ⚠️ 국내 send_message 와 달리 슈어비즈 사전 등록이 강제되지 않으나, 사용자가 발신번호를 명시하지 않았다면 추측하지 말고 사용자에게 직접 확인할 것.")
      }
    },
    async ({ country, to, text, reqPhone }) => {
      try {
        const result = await sendInternationalMessage(auth, country, to, text, reqPhone);
        const meta = result._meta;
        const body = { ...result };
        delete body._meta;

        const mode = meta?.ascii ? "ASCII" : "Unicode";
        const header = `[INTL 발송 / 국가 +${meta.country} / ${meta.charLength}자 / ${mode} 모드]`;

        return {
          content: [{
            type: "text",
            text: `${header}\n${JSON.stringify(body, null, 2)}`
          }]
        };
      } catch (error: any) {
        return {
          content: [{ type: "text", text: `국제 메시지 발송 실패: ${error.message}` }],
          isError: true
        };
      }
    }
  );

  return server;
}
