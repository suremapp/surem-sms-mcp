import axios from "axios";
import FormData from "form-data";
import * as fs from "fs";
import * as path from "path";
import type { AuthContext } from "../auth.js";

const BASE_URL = "https://rest.surem.com/api/v1";

const MAX_IMAGE_BYTES = 500 * 1024;        // 한 장 500KB
const MAX_TOTAL_BYTES = 1 * 1024 * 1024;   // 합산 1MB
const MAX_IMAGES = 3;

export interface ImageInput {
  /** 로컬 jpg 파일 경로 (서버 프로세스가 접근 가능해야 함) */
  path: string;
  /** 파일명 override (선택, 기본: path 의 basename) */
  filename?: string;
}

export interface UploadedImageResult {
  imageKey: string;
  expiryDate: string;
}

/**
 * 1~3 장의 jpg 이미지를 SureM API 에 업로드하고 단일 imageKey 를 반환.
 * (몇 장을 올리든 응답의 imageKey 는 항상 1개. 발송 시도 imageKey 파라미터 1개로 사용.)
 *
 * 입력은 파일 경로만 받음 — fs.createReadStream 으로 바이너리 stream 을 그대로 multipart 로 전송
 * (base64 transcoding 단계가 끼면 일부 환경에서 jpeg 가 손상되는 사례가 있어서 제거).
 */
export async function uploadImages(
  auth: AuthContext,
  images: ImageInput[]
): Promise<UploadedImageResult> {
  if (images.length === 0) {
    throw new Error("이미지가 없습니다. 최소 1장 필요.");
  }
  if (images.length > MAX_IMAGES) {
    throw new Error(
      `이미지는 최대 ${MAX_IMAGES} 장까지 업로드 가능합니다. (요청: ${images.length}장)`
    );
  }

  // 파일 존재 + 사이즈 검증
  let totalBytes = 0;
  for (const [idx, img] of images.entries()) {
    if (!fs.existsSync(img.path)) {
      throw new Error(
        `이미지 ${idx + 1}: 파일을 찾을 수 없음 — ${img.path}`
      );
    }
    const stat = fs.statSync(img.path);
    if (!stat.isFile()) {
      throw new Error(`이미지 ${idx + 1}: 파일이 아닙니다 — ${img.path}`);
    }
    if (stat.size === 0) {
      throw new Error(`이미지 ${idx + 1}: 빈 파일 — ${img.path}`);
    }
    if (stat.size > MAX_IMAGE_BYTES) {
      throw new Error(
        `이미지 ${idx + 1} 크기 초과: ${stat.size}B (최대 ${MAX_IMAGE_BYTES}B = 500KB)`
      );
    }
    totalBytes += stat.size;
  }
  if (totalBytes > MAX_TOTAL_BYTES) {
    throw new Error(
      `이미지 합산 크기 초과: ${totalBytes}B (최대 ${MAX_TOTAL_BYTES}B = 1MB)`
    );
  }

  // multipart/form-data 구성 — fs.createReadStream 사용 (사용자 레퍼런스 동일)
  const form = new FormData();
  images.forEach((img, idx) => {
    const filename = img.filename ?? path.basename(img.path);
    form.append(`image${idx + 1}`, fs.createReadStream(img.path), {
      filename,
      contentType: "image/jpeg"
    });
  });

  // Auth 헤더에서 Content-Type 제거 — form-data 가 boundary 포함된 multipart Content-Type 을 직접 설정해야 함
  const baseHeaders = await auth.getAuthHeaders();
  const headersNoCT: Record<string, string> = {};
  for (const [k, v] of Object.entries(baseHeaders)) {
    if (k.toLowerCase() !== "content-type") headersNoCT[k] = v as string;
  }

  const res = await axios.post(`${BASE_URL}/image`, form, {
    headers: {
      ...headersNoCT,
      ...form.getHeaders()
    },
    maxBodyLength: Infinity,
    maxContentLength: Infinity
  });

  // API 응답: data.imageKey 1개
  const data = res.data?.data;
  if (!data?.imageKey) {
    throw new Error(
      `이미지 업로드 응답에 imageKey 가 없습니다: ${JSON.stringify(res.data).slice(0, 300)}`
    );
  }
  return {
    imageKey: data.imageKey,
    expiryDate: data.expiryDate ?? ""
  };
}
