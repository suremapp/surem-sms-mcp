#!/usr/bin/env node
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createServer } from "./server.js";

async function main() {
  const userCode = process.env.SUREM_USER_CODE;
  const secretKey = process.env.SUREM_SECRET_KEY;

  if (!userCode || !secretKey) {
    console.error("SUREM_USER_CODE, SUREM_SECRET_KEY 환경변수가 필요합니다");
    process.exit(1);
  }

  // stdio 모드: 서버가 사용자 PC 에서 실행되므로 이미지 도구(upload_mms_image, send_message 의 imageKey) 활성화 가능
  const server = createServer({ userCode, secretKey, includeImageTools: true });
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Surem MCP Server 시작됨");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
