import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendMessage } from "./tools/sms.js";

export function createServer() {
  const server = new McpServer({
    name: "surem-sms-mcp",
    version: "1.0.2"
  });

  server.registerTool(
    "send_message",
    {
      description:
        "슈어엠 API로 문자를 발송합니다. 메시지 길이에 따라 SMS(90바이트 이하) / LMS(91~2000바이트)가 자동 선택됩니다. reservedTime을 지정하면 예약 발송됩니다. ⚠️ 사용자가 발신번호(reqPhone)를 명시하지 않았다면 절대 추측하거나 수신번호와 동일한 값을 넣지 말고, 반드시 사용자에게 '슈어비즈에 사전 등록된 발신번호'를 직접 물어본 뒤 호출하세요.",
      inputSchema: {
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
          .describe("예약 발송 시각 (yyyyMMddhhmmss, 미입력 시 즉시 발송). 예약 취소는 슈어비즈 → 예약,결과 → 예약조회 메뉴에서 수동으로 진행")
      }
    },
    async ({ to, text, reqPhone, subject, reservedTime }) => {
      try {
        const result = await sendMessage(to, text, reqPhone, subject, reservedTime);
        const { type, bytes, scheduled, reservedTime: rTime } = result._meta;
        const body = { ...result };
        delete body._meta;

        const header = scheduled
          ? `[${type} 예약발송 / ${bytes}바이트 / 예약시각 ${rTime}]`
          : `[${type} 발송 / ${bytes}바이트]`;

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

  return server;
}
