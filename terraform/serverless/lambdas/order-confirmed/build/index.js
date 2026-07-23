'use strict';

const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');
const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');
const { Pool } = require('pg');

const region = process.env.REGION || 'us-east-1';
const secretsClient = new SecretsManagerClient({ region });
const sqsClient    = new SQSClient({ region });
const snsClient    = new SNSClient({ region });

let pool = null;

async function getPool() {
  if (pool) return pool;
  const resp = await secretsClient.send(
    new GetSecretValueCommand({ SecretId: process.env.SECRET_ARN })
  );
  const { username, password } = JSON.parse(resp.SecretString);
  pool = new Pool({
    host: process.env.RDS_PROXY_ENDPOINT,
    port: 5432,
    database: 'devopsprojectEcommerce',
    user: username,
    password,
    ssl: { rejectUnauthorized: false },
    max: 1,
    idleTimeoutMillis: 10000,
  });
  return pool;
}

exports.handler = async (event) => {
  let body;
  try {
    body = typeof event.body === 'string' ? JSON.parse(event.body) : (event.body || {});
  } catch {
    body = {};
  }

  const orderId       = body.orderId       || `ORD-${Date.now()}`;
  const customerId    = body.customerId    || 'CUST-DEMO';
  const totalAmount   = body.totalAmount   || 0;
  const customerEmail = body.customerEmail || null;
  const items         = body.items         || [];
  const invoiceNumber = `INV-${Date.now()}`;

  try {
    // 1. Registra evento na Aurora via RDS Proxy
    const db = await getPool();
    await db.query(`
      CREATE TABLE IF NOT EXISTS order_events (
        id             SERIAL PRIMARY KEY,
        order_id       TEXT        NOT NULL,
        customer_id    TEXT        NOT NULL,
        event_type     TEXT        NOT NULL,
        total_amount   NUMERIC     DEFAULT 0,
        invoice_number TEXT,
        created_at     TIMESTAMPTZ DEFAULT NOW()
      )
    `);
    await db.query(
      `INSERT INTO order_events (order_id, customer_id, event_type, total_amount, invoice_number)
       VALUES ($1, $2, 'ORDER_CONFIRMED', $3, $4)`,
      [orderId, customerId, totalAmount, invoiceNumber]
    );

    // 2. Publica no SNS → fan-out para InvoiceQueue e ProductStockQueue
    await snsClient.send(new PublishCommand({
      TopicArn: process.env.SNS_TOPIC_ARN,
      Message: JSON.stringify({ orderId, customerId, totalAmount, items, invoiceNumber }),
      Subject: 'OrderConfirmed',
      MessageAttributes: {
        eventType: { DataType: 'String', StringValue: 'ORDER_CONFIRMED' },
      },
    }));

    // 3. Enfileira notificação de email (consumida pelo worker .NET Notificator)
    await sqsClient.send(new SendMessageCommand({
      QueueUrl: process.env.SQS_EMAIL_URL,
      MessageBody: JSON.stringify({
        to: customerEmail,
        templateName: 'order-confirmed-template',
        templateData: { OrderId: orderId, InvoiceNumber: invoiceNumber },
      }),
    }));

    console.log(`Order confirmed: orderId=${orderId} invoice=${invoiceNumber}`);
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ orderId, invoiceNumber, message: 'Order confirmed successfully' }),
    };
  } catch (err) {
    console.error('order-confirmed error:', err);
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: err.message }),
    };
  }
};
