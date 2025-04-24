local M = {}

local GridWindow = {}

GridWindow.default_config = {
  relative = 'win',
  style = 'minimal',
  border = 'single',
  focusable = false,
}

function GridWindow:new(o)
  o = o or {}
  setmetatable(o, self)
  self._handle = -1
  self._config = {}
  self._bufnr = -1
  self.__index = self
  return o
end

function GridWindow:_calc_offset()
  self._config.row = (vim.o.lines - self._config.height) / 2
  self._config.col = (vim.o.columns - self._config.width) / 2

  if self._config.relative == 'win' then
    self._config.row = (vim.fn.winheight(0) - self._config.height) / 2
    self._config.col = (vim.fn.winwidth(0) - self._config.width) / 2
  end
end

function GridWindow:open(width, height)
  self._config = vim.tbl_deep_extend('force', self.default_config, {
    width = width,
    height = height,
    row = 0,
    col = 0,
  })

  self:_calc_offset()
  if not self._bufnr or not vim.api.nvim_buf_is_valid(self._bufnr) then
    self._bufnr = vim.api.nvim_create_buf(false, true)
  end

  if not vim.api.nvim_win_is_valid(self._handle) then
    local cfg = vim.tbl_deep_extend('force', self._config, { noautocmd = true })
    self._handle = vim.api.nvim_open_win(self._bufnr, false, cfg)
    vim.api.nvim_set_option_value(
      'winhighlight',
      'NormalFloat:Normal,FloatBorder:ReachBorder',
      { win = self._handle, scope = 'local' }
    )
  end
end

function GridWindow:resize(width, height)
  self._config.width = width
  self._config.height = height
  self:_calc_offset()
  vim.api.nvim_win_set_config(self._handle, self._config)
end

function GridWindow:paint(lines, line_hls)
  local width = vim.api.nvim_strwidth(lines[1])
  local height = #lines

  self:resize(width, height)

  vim.api.nvim_buf_set_lines(self._bufnr, 0, -1, false, lines)
  for i, line_hl in ipairs(line_hls) do
    for _, hl in ipairs(line_hl) do
      vim.api.nvim_buf_add_highlight(
        self._bufnr,
        -1,
        hl.group,
        i - 1,
        hl.start,
        hl.stop
      )
    end
  end

  vim.api.nvim_command('redraw')
end

function GridWindow:close()
  if vim.api.nvim_buf_is_valid(self._bufnr) then
    vim.api.nvim_buf_delete(self._bufnr, { force = true, unload = false })
    self._bufnr = -1
    self._handle = -1
  end
end

M.CharPicker = {}

function M.CharPicker:new(o)
  o = o or {}
  setmetatable(o, self)

  self._win = GridWindow:new()

  self._lines = {}
  self._highlights = {}

  self._width = 0
  self._height = 0

  self._items = {}
  self._display_attr_to_hl = {}
  self._display_attrs = {}

  self.__index = self
  return o
end

function M.CharPicker:set_display_attr_hls(hls)
  self._display_attr_to_hl = vim.tbl_deep_extend('force', {}, hls)
end

function M.CharPicker:set_display_attrs(attrs)
  self._display_attrs = vim.tbl_deep_extend('force', {}, attrs)
end

function M.CharPicker:append_item(item)
  table.insert(self._items, item)
end

function M.CharPicker:extend_items(items)
  vim.list_extend(self._items, items)
end

function M.CharPicker:_calc_layout()
  local lines = {}
  local highlights = {}
  local attr_to_width = {}

  for _, item in ipairs(self._items) do
    for _, attr in ipairs(self._display_attrs) do
      attr_to_width[attr] = math.max(
        attr_to_width[attr] or 0,
        vim.api.nvim_strwidth(item[attr] or '')
      )
    end
  end

  for _, item in ipairs(self._items) do
    local line_text = ''
    local line_hl = {}

    for _, attr in ipairs(self._display_attrs) do
      local col = ''
      if item[attr] then
        col = item[attr]
        if #line_text > 0 then
          line_text = line_text .. ' '
        end
        if #col > 0 and self._display_attr_to_hl[attr] then
          table.insert(line_hl, {
            group = self._display_attr_to_hl[attr],
            start = #line_text,
            stop = #line_text + #col,
          })
        end
        line_text = line_text
          .. col
          .. string.rep(' ', attr_to_width[attr] - vim.api.nvim_strwidth(col))
      end
    end

    table.insert(lines, line_text)
    table.insert(highlights, line_hl)
  end

  self._lines = lines
  self._highlights = highlights

  self._width = 0
  self._height = #lines
  if #lines > 0 then
    self._width = vim.api.nvim_strwidth(lines[1])
  end
end

function M.CharPicker:_open()
  self:_calc_layout()
  self._win:open(self._width, self._height)
  self._win:paint(self._lines, self._highlights)
end

function M.CharPicker:_close()
  self._win:close()
end

function M.CharPicker:prompt()
  local chosen = nil

  if self._items and #self._items > 0 then
    self:_open()

    local input = vim.fn.getcharstr()
    if input ~= '^[' then
      for _, item in ipairs(self._items) do
        if item.handle == input then
          chosen = item
          break
        end
      end
    end

    self:_close()
  end

  return chosen
end

return M
