'use strict';

const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const { MongoClient } = require('mongodb');
const fs = require('fs');

const region       = process.env.REGION || 'us-east-1';
const secretsClient = new SecretsManagerClient({ region });
const s3Client      = new S3Client({ region });

const CERT_PATH = '/tmp/docdb-ca.pem';

async function ensureCert() {
  if (fs.existsSync(CERT_PATH)) return;
  const resp = await s3Client.send(new GetObjectCommand({
    Bucket: process.env.S3_BUCKET,
    Key:    process.env.DOCUMENTDB_CERT_OBJECT_KEY,
  }));
  fs.writeFileSync(CERT_PATH, await resp.Body.transformToString());
}

exports.handler = async (event) => {
  const timestamp  = new Date().toISOString();
  const reportDate = timestamp.slice(0, 10);

  try {
    await ensureCert();

    // Obtém credenciais do DocumentDB
    const secretResp = await secretsClient.send(
      new GetSecretValueCommand({ SecretId: process.env.DOCDB_SECRET_ARN })
    );
    const { username, password } = JSON.parse(secretResp.SecretString);

    // Conecta ao DocumentDB com TLS (CA do S3)
    const mongoClient = new MongoClient(
      `mongodb://${encodeURIComponent(username)}:${encodeURIComponent(password)}@${process.env.DOCDB_ENDPOINT}:27017/devopsproject`,
      {
        tls: true,
        tlsCAFile: CERT_PATH,
        retryWrites: false,
        serverSelectionTimeoutMS: 5000,
      }
    );
    await mongoClient.connect();

    const report = {
      timestamp,
      reportDate,
      generatedBy: 'report-job-lambda',
      schedulerTick: true,
    };

    // Persiste metadados no DocumentDB
    await mongoClient.db('devopsproject').collection('reports').insertOne(report);
    await mongoClient.close();

    // Salva relatório no S3
    const s3Key = `reports/${reportDate}/report-${Date.now()}.json`;
    await s3Client.send(new PutObjectCommand({
      Bucket:      process.env.S3_BUCKET,
      Key:         s3Key,
      Body:        JSON.stringify(report, null, 2),
      ContentType: 'application/json',
    }));

    console.log(`Report saved: s3://${process.env.S3_BUCKET}/${s3Key}`);
    return { statusCode: 200, s3Key, timestamp };

  } catch (err) {
    // Non-fatal: o scheduler vai reinvocar no próximo minuto
    console.error('report-job error:', err.message);
    return { statusCode: 200, error: err.message, timestamp };
  }
};
