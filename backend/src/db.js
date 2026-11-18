const { Pool } = require('pg');

const sslEnabled = process.env.DB_SSL !== 'false';

const pool = new Pool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT),
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    ...(sslEnabled ? { ssl: { rejectUnauthorized: false } } : {})
});

pool.on('error', (err) => {
    console.error('Unexpected PostgreSQL pool error:', err.message);
});

module.exports = pool;
