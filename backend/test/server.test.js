const { before, after, test } = require('node:test');
const assert = require('node:assert/strict');
const app = require('../src/server');
const pool = require('../src/db');

let server;
let baseUrl;
let createdTaskId;

before(async () => {
    await pool.query(`
        CREATE TABLE IF NOT EXISTS tasks (
            id SERIAL PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            description TEXT DEFAULT '',
            status VARCHAR(30) NOT NULL DEFAULT 'todo',
            created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    `);
    await pool.query('TRUNCATE TABLE tasks RESTART IDENTITY');
    server = app.listen(0, '127.0.0.1');
    await new Promise((resolve, reject) => {
        server.once('listening', resolve);
        server.once('error', reject);
    });
    baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
    if (createdTaskId) {
        await pool.query('DELETE FROM tasks WHERE id = $1', [createdTaskId]);
    }
    if (server) {
        await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    }
    await pool.end();
});

test('GET /health returns healthy status', async () => {
    const response = await fetch(`${baseUrl}/health`);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
        status: 'healthy',
        application: 'TaskFlow API'
    });
});

test('GET /api/tasks returns a tasks array', async () => {
    const response = await fetch(`${baseUrl}/api/tasks`);
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.ok(Array.isArray(body.tasks));
});

test('POST /api/tasks rejects an empty title', async () => {
    const response = await fetch(`${baseUrl}/api/tasks`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: '   ' })
    });
    assert.equal(response.status, 400);
});

test('POST /api/tasks creates a task in PostgreSQL', async () => {
    const response = await fetch(`${baseUrl}/api/tasks`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            title: 'CI integration test task',
            description: 'Created by automated test',
            status: 'todo'
        })
    });
    assert.equal(response.status, 201);
    const body = await response.json();
    assert.equal(body.task.title, 'CI integration test task');
    assert.equal(body.task.status, 'todo');
    assert.ok(Number.isInteger(body.task.id));
    createdTaskId = body.task.id;
});

test('PUT /api/tasks/:id updates the persisted task', async () => {
    assert.ok(createdTaskId, 'create test must run first');
    const response = await fetch(`${baseUrl}/api/tasks/${createdTaskId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            title: 'CI integration test task updated',
            description: 'Updated by automated test',
            status: 'in_progress'
        })
    });
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.task.title, 'CI integration test task updated');
    assert.equal(body.task.status, 'in_progress');
});

test('PUT /api/tasks/:id rejects an invalid ID', async () => {
    const response = await fetch(`${baseUrl}/api/tasks/not-a-number`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: 'Invalid ID' })
    });
    assert.equal(response.status, 400);
});

test('DELETE /api/tasks/:id removes the persisted task', async () => {
    assert.ok(createdTaskId, 'create test must run first');
    const response = await fetch(`${baseUrl}/api/tasks/${createdTaskId}`, {
        method: 'DELETE'
    });
    assert.equal(response.status, 204);
    const check = await pool.query('SELECT id FROM tasks WHERE id = $1', [createdTaskId]);
    assert.equal(check.rowCount, 0);
    createdTaskId = undefined;
});
