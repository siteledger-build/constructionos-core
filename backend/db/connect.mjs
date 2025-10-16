// backend/db/connect.mjs
import { RDS } from "@aws-sdk/client-rds"; // optional future use
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";
import pkg from "pg";
const { Pool } = pkg;

// Cached across invocations in Lambda
let pool;

export async function getPool() {
  if (pool) return pool;

  const sm = new SecretsManagerClient({ region: process.env.AWS_REGION || "eu-west-2" });
  const secretArn = process.env.DB_SECRET_ARN;
  const secret = await sm.send(new GetSecretValueCommand({ SecretId: secretArn }));
  const { username, password } = JSON.parse(secret.SecretString);

  pool = new Pool({
    host: process.env.DB_PROXY_ENDPOINT,
    port: parseInt(process.env.DB_PORT || "5432", 10),
    user: username,
    password,
    database: process.env.DB_NAME,
    ssl: { rejectUnauthorized: true } // Proxy requires TLS
  });

  return pool;
}
