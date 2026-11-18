require('dotenv').config();

const express = require('express');
const pool = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// Health check
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        application: 'TaskFlow API'
    });
});

// Database health check
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

function getValidId(value) {
    const id = Number(value);
    return Number.isInteger(id) && id > 0 ? id : null;
}

// GET all tasks
app.get('/api/tasks', async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT id, title, description, status, created_at, updated_at
             FROM tasks ORDER BY created_at DESC`
        );

        res.status(200).json({ tasks: result.rows });
    } catch (error) {
        console.error('Fetch tasks failed:', error.message);
        res.status(500).json({ message: 'Failed to fetch tasks' });
    }
});

// CREATE task
app.post('/api/tasks', async (req, res) => {
    try {
        const { title, description = '', status = 'todo' } = req.body;

        if (
            typeof title !== 'string' ||
            !title.trim() ||
            title.trim().length > 255
        ) {
            return res.status(400).json({
                message: 'Title is required and must not exceed 255 characters'
            });
        }

        if (typeof description !== 'string') {
            return res.status(400).json({
                message: 'Description must be a string'
            });
        }

        if (!['todo', 'in_progress', 'done'].includes(status)) {
            return res.status(400).json({
                message: 'Invalid task status'
            });
        }

        const result = await pool.query(
            `INSERT INTO tasks (title, description, status)
             VALUES ($1, $2, $3)
             RETURNING id, title, description, status, created_at, updated_at`,
            [title.trim(), description, status]
        );

        res.status(201).json({ task: result.rows[0] });
    } catch (error) {
        console.error('Create task failed:', error.message);
        res.status(500).json({ message: 'Failed to create task' });
    }
});

// UPDATE task
app.put('/api/tasks/:id', async (req, res) => {
    try {
        const id = getValidId(req.params.id);

        if (!id) {
            return res.status(400).json({ message: 'Invalid task ID' });
        }

        const { title, description = '', status = 'todo' } = req.body;

        if (
            typeof title !== 'string' ||
            !title.trim() ||
            title.trim().length > 255
        ) {
            return res.status(400).json({
                message: 'Title is required and must not exceed 255 characters'
            });
        }

        if (typeof description !== 'string') {
            return res.status(400).json({
                message: 'Description must be a string'
            });
        }

        if (!['todo', 'in_progress', 'done'].includes(status)) {
            return res.status(400).json({
                message: 'Invalid task status'
            });
        }

        const result = await pool.query(
            `UPDATE tasks
             SET title = $1,
                 description = $2,
                 status = $3,
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $4
             RETURNING id, title, description, status, created_at, updated_at`,
            [title.trim(), description, status, id]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'Task not found' });
        }

        res.status(200).json({ task: result.rows[0] });
    } catch (error) {
        console.error('Update task failed:', error.message);
        res.status(500).json({ message: 'Failed to update task' });
    }
});

// DELETE task
app.delete('/api/tasks/:id', async (req, res) => {
    try {
        const id = getValidId(req.params.id);

        if (!id) {
            return res.status(400).json({ message: 'Invalid task ID' });
        }

        const result = await pool.query(
            'DELETE FROM tasks WHERE id = $1 RETURNING id',
            [id]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'Task not found' });
        }

        res.status(204).send();
    } catch (error) {
        console.error('Delete task failed:', error.message);
        res.status(500).json({ message: 'Failed to delete task' });
    }
});

// Unknown routes
app.use((req, res) => {
    res.status(404).json({ message: 'Route not found' });
});

if (require.main === module) {
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`TaskFlow API running on port ${PORT}`);
    });
}

module.exports = app;
