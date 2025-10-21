import { S3Client, ListObjectsV2Command, HeadObjectCommand } from "@aws-sdk/client-s3";

const s3 = new S3Client({ region: process.env.AWS_REGION || "eu-west-2" });

function buildPrefix(companyId, jobRef) {
  const parts = ["uploads"];
  if (companyId) parts.push(companyId);
  if (jobRef) parts.push(jobRef);
  return parts.join("/") + "/";
}

export const handler = async (event) => {
  const qs = event.queryStringParameters || {};
  const companyId = qs.companyId || "demo";
  const jobRef    = qs.jobRef || "";
  const prefix    = buildPrefix(companyId, jobRef);
  const bucket    = process.env.BUCKET;

  // List uploads under the prefix
  let keys = [];
  let token;
  do {
    const res = await s3.send(new ListObjectsV2Command({
      Bucket: bucket,
      Prefix: prefix,
      ContinuationToken: token
    }));
    (res.Contents || []).forEach(o => !o.Key.endsWith("/") && keys.push(o.Key));
    token = res.IsTruncated ? res.NextContinuationToken : undefined;
  } while (token);

  // For each upload, see if parsed JSON exists
  const items = await Promise.all(keys.map(async (key) => {
    const parsedKey = key.replace(/^uploads\//, "parsed/") + ".json";
    let parsed = false;
    let parsedETag = null;

    try {
      const head = await s3.send(new HeadObjectCommand({ Bucket: bucket, Key: parsedKey }));
      parsed = true;
      parsedETag = head.ETag?.replaceAll('"', "");
    } catch (_) { /* no parsed file yet */ }

    return {
      key,
      parsedKey,
      parsed,
      // simple metadata you can expand later
      companyId,
      jobRef: jobRef || null
    };
  }));

  return {
    statusCode: 200,
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ bucket, prefix, count: items.length, items })
  };
};
