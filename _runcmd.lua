local M = {}

local Process = {}

function Process:new(o)
  local opts = o
  o = setmetatable({}, self)
  self.__index = self

  self._cmd = opts.cmd
  self._cwd = opts.cwd
  self._env = {}

  self._is_exited = nil

  self._stdout = nil
  self._stderr = nil

  self._stdout_reader = nil
  self._stderr_reader = nil

  self._stdout_data = nil
  self._stderr_data = nil

  for k, v in pairs(opts.env or {}) do
    assert(type(k) == "string", "expected env var name")
    table.insert(self._env, k .. "=" .. tostring(v))
  end

  return o
end

function Process:_spawn()
  local exe_ok, is_exe = pcall(vim.fn.executable, self._cmd[1])
  assert(exe_ok and is_exe >= 1, "exe not found")

  local uv_opts = {}

  assert(self._cmd and #self._cmd >= 1, "expected command")
  uv_opts.command = self._cmd[1]
  uv_opts.args = { select(2, unpack(self._cmd)) }

  uv_opts.cwd = self._cwd
  uv_opts.env = self._env

  assert(self._stdout, "expected stdout already initialized")
  assert(self._stderr, "expected stderr already initialized")
  uv_opts.stdio = { nil, self._stdout, self._stderr }

  return vim.loop.spawn(uv_opts.command, uv_opts, function(exitcode, signal)
    self:_on_exit(exitcode, signal)
  end)
end

function Process:_reader(f)
  return coroutine.wrap(function(_, data, is_done)
    while data ~= nil and not is_done do
      f(data)
      _, data, is_done = coroutine.yield()
    end
  end)
end

function Process:_execute()
  self._stdout = vim.loop.new_pipe(false)
  self._stderr = vim.loop.new_pipe(false)

  self._handle, self._pid = self:_spawn()

  assert(self._handle, "no handle")
  assert(self._pid and self._pid >= 0, "no _pid (failed to start process?)")

  self._stdout_reader = self:_reader(function(data)
    self._stdout_data = (self._stdout_data or "") .. data
  end)

  self._stderr_reader = self:_reader(function(data)
    self._stderr_data = (self._stderr_data or "") .. data
  end)

  self._stdout:read_start(self._stdout_reader)
  self._stderr:read_start(self._stderr_reader)
end

function Process:_wait(timeout_ms, poll_ms)
  timeout_ms = timeout_ms or 5000
  poll_ms = poll_ms or 10

  vim.wait(timeout_ms, function()
    return self._is_exited
  end, poll_ms, false)
end

function Process:run(timeout_ms)
  self:_execute()
  self:_wait(timeout_ms)
  return self._exitcode, self._stdout_data, self._stderr_data
end

function Process:_on_exit(exitcode, signal)
  assert(not self._is_exited, "cannot exit more than once")

  self._is_exited = true

  self._exitcode = exitcode
  self._signal = signal

  self._stdout:read_stop()
  self._stdout:close()
  self._stdout_reader = nil

  self._stderr:read_stop()
  self._stderr:close()
  self._stderr_reader = nil

  self._handle:close()
  self._handle = nil
end

function M.run(cmd)
  local proc = Process:new({ cmd = cmd })
  return proc:run()
end

return M
