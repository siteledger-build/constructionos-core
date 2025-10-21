import { TextractClient, AnalyzeExpenseCommand } from "@aws-sdk/client-textract";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

const region = process.env.AWS_REGION || "eu-west-2";
const textract = new TextractClient({ region });
const s3 = new S3Client({ region });

function pickField(blocks, type) {
  const field = blocks?.find(f => f?.Type === "EXPENSE_FIELD" && f?.Type?.toUpperCase() === "EXPENSE_FIELD" && f?.LabelDetection?.Text?.toLowerCase().includes(type));
  return field?.ValueDetection?.Text?.trim();
}

function extractFields(expenseDocs) {
  // Fallbacks + heuristics: AnalyzeExpense returns a rich structure; we’ll attempt common fields.
  let merchant = "";
  let total = "";
  let tax = "";
  let date = "";

  for (const doc of expenseDocs || []) {
    for (const group of doc?.SummaryFields || []) {
      const label = (group?.LabelDetection?.Text || "").toLowerCase();
      const val = (group?.ValueDetection?.Text || "").trim();

      if (!merchant && (label.includes("vendor") || label.includes("merchant") || label.includes("supplier"))) merchant = val;
      if (!total && (label.includes("total") || label.includes("amount due") || label === "total")) total = val;
      if (!tax && (label.includes("vat") || label.includes("tax"))) tax = val;
      if (!date && (label.includes("date") || label.includes("issue date"))) date = val;
    }
  }

  // basic cleanup
  const cleaned = {
    merchant: merchant || null,
    total: total?.replace(/[^\d.,-]/g, "") || null,
    vat: tax?.replace(/[^\d.,-]/g, "") || null,
    date: date || null
  };
  return cleaned;
}

export const handler = async (event) => {
  // S3 event sends Records[].s3.bucket.name + .object.key
  for (const record of event.Records || []) {
    const bucket = record.s3.bucket.name;
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, " "));

    // Only process uploads/ prefix
    if (!key.startsWith("uploads/")) continue;

    // Run Textract AnalyzeExpense directly on S3 object (no need to download)
    const res = await textract.send(new AnalyzeExpenseCommand({
      Document: { S3Object: { Bucket: bucket, Name: key } }
    }));

    const parsed = extractFields(res.ExpenseDocuments);
    const output = {
      sourceBucket: bucket,
      sourceKey: key,
      parsed,
      ocrMeta: {
        pages: res.ExpenseDocuments?.length || 1,
        ts: new Date().toISOString()
      }
    };

    // Write parsed JSON next to the file in a 'parsed/' prefix
    const parsedKey = key.replace(/^uploads\//, "parsed/") + ".json";
    await s3.send(new PutObjectCommand({
      Bucket: bucket,
      Key: parsedKey,
      Body: Buffer.from(JSON.stringify(output, null, 2)),
      ContentType: "application/json",
      ServerSideEncryption: "aws:kms",
      SSEKMSKeyId: process.env.KMS_KEY
    }));
  }

  return { statusCode: 200, body: JSON.stringify({ ok: true }) };
};
