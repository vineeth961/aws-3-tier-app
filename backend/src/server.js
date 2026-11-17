require('dotenv').config();

const express = require('express');
const pool = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        application: 'TaskFlow API'
    });
});

app.get('/health/db', async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT current_database() AS database, current_user AS username'
        );

        res.status(200).json({
            status: 'connected',
            database: result.rows[0].database,
            username: result.rows[0].username
        });
    } catch (error) {
        console.error('Database connection failed:', error.message);

        res.status(503).json({
            status: 'unavailable',
            message: 'Database connection failed'
        });
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`TaskFlow API running on port ${PORT}`);
});
