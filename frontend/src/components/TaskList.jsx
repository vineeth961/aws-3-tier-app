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
      await updateTask(task.id ?? task.task_id, {
        title: task.title,
        description: task.description || '',
        status,
      })
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
