import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { randomUUID } from "node:crypto";

const s3 = new S3Client({ region: process.env.AWS_REGION || "eu-west-2" });

export const handler = async (event) => {
  try {
    const body = event.body && typeof event.body === "string" ? JSON.parse(event.body) : (event.body || {});
    const { contentType = "image/jpeg", companyId = "demo", jobRef = "unassigned" } = body;

    const key = `uploads/${companyId}/${jobRef}/${new Date().getFullYear()}/${randomUUID()}`;

    const cmd = new PutObjectCommand({
      Bucket: process.env.BUCKET,
      Key: key,
      ContentType: contentType,
      ServerSideEncryption: "aws:kms",
      SSEKMSKeyId: process.env.KMS_KEY
    });

    const url = await getSignedUrl(s3, cmd, { expiresIn: 60 }); // 60s validity

    return {
      statusCode: 200,
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ url, key, bucket: process.env.BUCKET })
    };
  } catch (err) {
    return { statusCode: 400, body: JSON.stringify({ error: err.message }) };
  }
};
