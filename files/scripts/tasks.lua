---@class tasks
local tasks = {}

---@type DeferredTask[]
tasks.deferred_tasks = {}

---@param frames number
---@param fn function
function tasks:AddDeferredTask(frames, fn)
  ---@param frames number
  ---@param fn function
  local function CreateDeferredTask(frames, fn)
    ---@class DeferredTask
    local state = { done = false, wait_frames = frames, task = fn }

    function state:Update()
      if self.wait_frames <= 0 and not self.done then
        self.task()
        self.done = true
      else
        self.wait_frames = self.wait_frames - 1
      end
    end

    return state
  end

  table.insert(self.deferred_tasks, CreateDeferredTask(frames, fn))
end

function tasks:ProcessDeferredTasks()
  local i = 1
  while i <= #self.deferred_tasks do
    self.deferred_tasks[i]:Update()
    if self.deferred_tasks[i].done then
      table.remove(self.deferred_tasks, i)
    else
      i = i + 1
    end
  end
end

return tasks
