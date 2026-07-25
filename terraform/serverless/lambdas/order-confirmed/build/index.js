'use strict';

const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');
const { Pool } = require('pg');

const region        = process.env.REGION || 'us-east-1';
const secretsClient = new SecretsManagerClient({ region });
const snsClient     = new SNSClient({ region });

let pool = null;

async function getPool() {
  if (pool) return pool;
  const resp = await secretsClient.send(
    new GetSecretValueCommand({ SecretId: process.env.SECRET_ARN })
  );
  const { username, password } = JSON.parse(resp.SecretString);
  pool = new Pool({
    host:              process.env.RDS_PROXY_ENDPOINT,
    port:              5432,
    database:          'devopsprojectEcommerce',
    user:              username,
    password,
    ssl:               { rejectUnauthorized: false },
    max:               1,
    idleTimeoutMillis: 10000,
  });
  return pool;
}

exports.handler = async (event) => {
  let body;
  try {
    body = typeof event.body === 'string' ? JSON.parse(event.body) : (event.body || event || {});
  } catch {
    body = event || {};
  }

  const orderId       = body.orderId       || null;
  const customerId    = body.customerId    || 'CUST-DEMO';
  const totalAmount   = body.totalAmount   || 0;
  const customerEmail = body.customerEmail || null;
  const invoiceNumber = `INV-${Date.now()}`;

  if (!orderId) {
    console.error('order-confirmed: orderId is required');
    return { statusCode: 400, body: JSON.stringify({ error: 'orderId is required' }) };
  }

  const orderIdInt = parseInt(orderId, 10);

  try {
    const db = await getPool();

    // 1. Cria tabela de auditoria de eventos se não existir
    await db.query(`
      CREATE TABLE IF NOT EXISTS order_events (
        id             SERIAL PRIMARY KEY,
        order_id       INT         NOT NULL,
        customer_id    TEXT        NOT NULL,
        event_type     TEXT        NOT NULL,
        total_amount   NUMERIC     DEFAULT 0,
        invoice_number TEXT,
        created_at     TIMESTAMPTZ DEFAULT NOW()
      )
    `);

    // 2. Confirma o pedido no banco de dados (Pendente → Confirmado)
    await db.query(
      `UPDATE "Order" SET "StatusId" = 1 WHERE "Id" = $1`,
      [orderIdInt]
    );

    // 3. Registra o evento de confirmação para auditoria
    await db.query(
      `INSERT INTO order_events (order_id, customer_id, event_type, total_amount, invoice_number)
       VALUES ($1, $2, 'ORDER_CONFIRMED', $3, $4)`,
      [orderIdInt, customerId, totalAmount, invoiceNumber]
    );

    // 4. Publica no SNS → fan-out: ProductStockQueue + InvoiceQueue
    //    Formato { Id: int } corresponde ao OrderConfirmedEvent esperado pelos workers .NET
    await snsClient.send(new PublishCommand({
      TopicArn: process.env.SNS_TOPIC_ARN,
      Message:  JSON.stringify({ Id: orderIdInt }),
      Subject:  'OrderConfirmed',
      MessageAttributes: {
        eventType: { DataType: 'String', StringValue: 'ORDER_CONFIRMED' },
      },
    }));

    console.log(`Order confirmed: orderId=${orderIdInt} invoice=${invoiceNumber}`);
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ orderId: orderIdInt, invoiceNumber, message: 'Order confirmed successfully' }),
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
