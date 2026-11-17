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
