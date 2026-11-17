#!/usr/bin/env bash
set -e

mkdir -p src/components src/pages src/services

# API service
cat > src/services/api.js <<'EOF'
import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  headers: { 'Content-Type': 'application/json' },
  timeout: 10000,
})

export const getTasks = () => api.get('/tasks')
export const createTask = (data) => api.post('/tasks', data)
export const updateTask = (id, data) => api.put(`/tasks/${id}`, data)
export const deleteTask = (id) => api.delete(`/tasks/${id}`)

export default api
EOF

# Loading component
cat > src/components/Loading.jsx <<'EOF'
export default function Loading() {
  return <div className="loading"><span className="spinner" /> Loading tasks...</div>
}
EOF

# Error component
cat > src/components/ErrorMessage.jsx <<'EOF'
export default function ErrorMessage({ message, onRetry }) {
  if (!message) return null

  return (
    <div className="error-message">
      <span>{message}</span>
      {onRetry && <button className="retry-button" onClick={onRetry}>Retry</button>}
    </div>
  )
}
EOF

# Task form
cat > src/components/TaskForm.jsx <<'EOF'
import { useEffect, useState } from 'react'
import { createTask, updateTask } from '../services/api'

export default function TaskForm({ editingTask, onCreated, onCancel }) {
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    setTitle(editingTask?.title || '')
    setDescription(editingTask?.description || '')
    setError('')
  }, [editingTask])

  async function handleSubmit(event) {
    event.preventDefault()
    if (!title.trim()) return setError('Task title is required')

    setLoading(true)
    setError('')

    try {
      const data = { title: title.trim(), description: description.trim() }

      if (editingTask) {
        await updateTask(editingTask.id ?? editingTask.task_id, data)
      } else {
        await createTask({ ...data, status: 'todo' })
      }

      setTitle('')
      setDescription('')
      onCreated()
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to save task. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <form className="task-form" onSubmit={handleSubmit}>
      <h2>{editingTask ? 'Edit Task' : 'Add a New Task'}</h2>
      <input
        type="text"
        placeholder="Task title"
        value={title}
        onChange={e => setTitle(e.target.value)}
        maxLength={200}
        required
      />
      <textarea
        placeholder="Task description"
        value={description}
        onChange={e => setDescription(e.target.value)}
        rows={3}
      />
      {error && <p className="form-error">{error}</p>}
      <div className="form-actions">
        <button className="primary-button" disabled={loading}>
          {loading ? 'Saving...' : editingTask ? 'Save Changes' : 'Add Task'}
        </button>
        {editingTask && (
          <button type="button" className="secondary-button" onClick={onCancel}>
            Cancel
          </button>
        )}
      </div>
    </form>
  )
}
EOF

# Task list and actions
cat > src/components/TaskList.jsx <<'EOF'
import { deleteTask, updateTask } from '../services/api'

const statuses = ['todo', 'in_progress', 'done']

const labels = {
  todo: 'To Do',
  in_progress: 'In Progress',
  done: 'Done',
}

export default function TaskList({ tasks, onRefresh, onEdit }) {
  async function changeStatus(task, status) {
    try {
      await updateTask(task.id ?? task.task_id, { status })
      onRefresh()
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to update task status')
    }
  }

  async function removeTask(task) {
    if (!window.confirm(`Delete "${task.title}"?`)) return

    try {
      await deleteTask(task.id ?? task.task_id)
      onRefresh()
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to delete task')
    }
  }

  if (!tasks.length) {
    return <div className="empty-state">No tasks yet. Create your first task!</div>
  }

  return (
    <div className="task-list">
      {tasks.map(task => (
        <article className="task-card" key={task.id ?? task.task_id}>
          <div className="task-details">
            <h3>{task.title}</h3>
            <p>{task.description || 'No description'}</p>
            <span className={`status status-${task.status}`}>
              {labels[task.status] || task.status}
            </span>
          </div>

          <div className="task-actions">
            <select
              aria-label={`Status for ${task.title}`}
              value={task.status}
              onChange={e => changeStatus(task, e.target.value)}
            >
              {statuses.map(status => (
                <option key={status} value={status}>{labels[status]}</option>
              ))}
            </select>
            <button className="edit-button" onClick={() => onEdit(task)}>Edit</button>
            <button className="delete-button" onClick={() => removeTask(task)}>Delete</button>
          </div>
        </article>
      ))}
    </div>
  )
}
EOF

# Home page
cat > src/pages/Home.jsx <<'EOF'
import { useCallback, useEffect, useState } from 'react'
import TaskForm from '../components/TaskForm'
import TaskList from '../components/TaskList'
import Loading from '../components/Loading'
import ErrorMessage from '../components/ErrorMessage'
import { getTasks } from '../services/api'

export default function Home() {
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [editingTask, setEditingTask] = useState(null)

  const loadTasks = useCallback(async () => {
    setLoading(true)
    setError('')

    try {
      const response = await getTasks()
      const data = response.data
      setTasks(Array.isArray(data) ? data : data.tasks || [])
    } catch (err) {
      setError(err.response?.data?.message || 'Unable to load tasks. Check the API connection.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadTasks()
  }, [loadTasks])

  function handleSaved() {
    setEditingTask(null)
    loadTasks()
  }

  return (
    <main className="container">
      <header className="app-header">
        <div>
          <h1>TaskFlow</h1>
          <p>Organize your work. Track your progress.</p>
        </div>
        <span className="task-count">{tasks.length} Tasks</span>
      </header>

      <section className="dashboard">
        <TaskForm
          editingTask={editingTask}
          onCreated={handleSaved}
          onCancel={() => setEditingTask(null)}
        />

        <section className="tasks-section">
          <div className="section-heading">
            <h2>Your Tasks</h2>
            <button className="refresh-button" onClick={loadTasks}>Refresh</button>
          </div>

          <ErrorMessage message={error} onRetry={loadTasks} />
          {loading ? <Loading /> : !error && (
            <TaskList
              tasks={tasks}
              onRefresh={loadTasks}
              onEdit={setEditingTask}
            />
          )}
        </section>
      </section>

      <footer>TaskFlow · Three-Tier AWS Application</footer>
    </main>
  )
}
EOF

# Application entry
cat > src/App.jsx <<'EOF'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Home from './pages/Home'
import './App.css'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Home />} />
      </Routes>
    </BrowserRouter>
  )
}
EOF

# Main entry
cat > src/main.jsx <<'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

# Responsive styling
cat > src/App.css <<'EOF'
* { box-sizing: border-box; }

body {
  margin: 0;
  min-width: 320px;
  min-height: 100vh;
  font-family: Inter, system-ui, Arial, sans-serif;
  background: #f3f5fa;
  color: #20283b;
}

button, input, textarea, select { font: inherit; }
button { cursor: pointer; }
button:disabled { opacity: .6; cursor: not-allowed; }

.container { max-width: 1100px; margin: auto; padding: 40px 24px; }

.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
}

.app-header h1 { margin: 0; font-size: 34px; color: #243b75; }
.app-header p { margin: 7px 0 0; color: #697386; }
.task-count { background: #e4eaff; color: #294a9b; padding: 10px 16px; border-radius: 20px; font-weight: 600; }

.dashboard { display: grid; grid-template-columns: 340px 1fr; gap: 24px; align-items: start; }

.task-form, .tasks-section {
  background: white;
  border: 1px solid #e5e9f1;
  border-radius: 14px;
  padding: 22px;
  box-shadow: 0 4px 16px rgba(25, 40, 75, .04);
}

.task-form h2, .tasks-section h2 { margin: 0 0 18px; font-size: 19px; }

.task-form input, .task-form textarea {
  width: 100%;
  padding: 12px;
  margin-bottom: 12px;
  border: 1px solid #d9deea;
  border-radius: 8px;
  outline-color: #5277d5;
}

.task-form textarea { resize: vertical; }
.form-actions { display: flex; gap: 9px; }
.primary-button, .secondary-button, .refresh-button, .retry-button {
  border: 0;
  border-radius: 8px;
  padding: 10px 15px;
}
.primary-button { background: #3159b7; color: white; flex: 1; }
.secondary-button { background: #e9edf5; color: #34415c; }
.refresh-button { background: #edf1fb; color: #3159a8; }
.form-error { color: #c33232; font-size: 13px; }

.section-heading { display: flex; align-items: center; justify-content: space-between; }
.section-heading h2 { margin-bottom: 18px; }

.task-list { display: grid; gap: 12px; }
.task-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 14px;
  padding: 16px;
  border: 1px solid #e7eaf0;
  border-radius: 10px;
}
.task-details { min-width: 0; }
.task-details h3 { margin: 0 0 6px; font-size: 16px; overflow-wrap: anywhere; }
.task-details p { margin: 0 0 10px; color: #747e90; font-size: 14px; overflow-wrap: anywhere; }

.status { display: inline-block; padding: 5px 9px; border-radius: 20px; font-size: 12px; font-weight: 600; }
.status-todo { background: #fff2d9; color: #986500; }
.status-in_progress { background: #e4efff; color: #2456a5; }
.status-done { background: #def5e7; color: #237443; }

.task-actions { display: flex; align-items: center; flex-wrap: wrap; gap: 7px; }
.task-actions select { max-width: 125px; padding: 7px; border: 1px solid #dce1ea; border-radius: 7px; }
.edit-button, .delete-button { border: 0; padding: 7px 10px; border-radius: 7px; }
.edit-button { background: #edf1fb; color: #3159a8; }
.delete-button { background: #fff0f0; color: #b52f2f; }

.empty-state { padding: 35px 10px; text-align: center; color: #858da0; }
.error-message { display: flex; justify-content: space-between; align-items: center; gap: 12px; padding: 12px; margin-bottom: 15px; background: #fff0f0; color: #a82c2c; border-radius: 8px; font-size: 14px; }
.retry-button { background: #a82c2c; color: white; }
.loading { display: flex; align-items: center; gap: 12px; padding: 30px; color: #68748a; }
.spinner { width: 20px; height: 20px; border: 3px solid #dce4f5; border-top-color: #3159b7; border-radius: 50%; animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

footer { text-align: center; color: #8b93a4; font-size: 13px; padding: 35px 0 10px; }

@media (max-width: 760px) {
  .container { padding: 24px 14px; }
  .dashboard { grid-template-columns: 1fr; }
  .app-header { align-items: flex-start; gap: 12px; }
  .app-header h1 { font-size: 28px; }
  .task-card { align-items: flex-start; flex-direction: column; }
  .task-actions { width: 100%; }
}
EOF

# Verify build
npm run build

echo
echo "TaskFlow frontend files created and production build completed."
