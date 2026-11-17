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
