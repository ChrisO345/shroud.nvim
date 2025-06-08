local group = vim.api.nvim_create_augroup("shroud", {})
local namespace = vim.api.nvim_create_namespace("shroud")

local M = {}

M.opts = {
  enabled = true,
  patterns = { { file = "*.env*", shroud = "=.*" } },
  character = "*",
  offset = 1,             -- Set to 1 to include the prefix character in the shrouded text
  _visible_lin_num = nil, -- This is used to track the visible line number for unshrouding
}

M.setup = function(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
  vim.b.shroud_enabled = M.opts.enabled

  for _, pattern in ipairs(M.opts.patterns) do
    if not pattern.file or not pattern.shroud then
      error("Invalid pattern: " .. vim.inspect(pattern))
    end

    vim.api.nvim_create_autocmd(
      { 'BufEnter', 'TextChanged', 'TextChangedI', 'TextChangedP' }, {
        pattern = pattern.file,
        callback = function()
          if M.opts.enabled then
            M.shroud(pattern)
          else
            M.unshroud()
          end
        end,
        group = group,
      }
    )
  end

  local usercmd = vim.api.nvim_create_user_command
  usercmd("ShroudEnable", M.enable, {})
  usercmd("ShroudDisable", M.disable, {})
  usercmd("ShroudToggle", M.toggle, {})
  usercmd("ShroudPeek", M.peek, {})
end

M.shroud = function(pattern)
  -- Resets the line shrouding to prevent ghosting issues
  M.unshroud()

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    if i ~= M.opts._visible_lin_num then
      local function shroud_line(length, prefix)
        local shroud_str = prefix .. M.opts.character:rep(length)
        local remaining_length = length - vim.fn.strchars(shroud_str)

        -- Detemine offset
        shroud_str = shroud_str:sub(M.opts.offset + 1)

        return shroud_str .. ('?'):rep(remaining_length)
      end

      local first, last, matching_prefix = -1, 1, nil

      local cur_first, cur_last, _ = line:find(pattern.shroud)
      if cur_first ~= nil and cur_last ~= nil then
        first, last = cur_first, cur_last
        matching_prefix = line:sub(first, first)
      end

      if first > -1 then
        local offset = math.min(M.opts.offset or 0, last - first)
        local prefix = matching_prefix or ""
        local visible_length = last - first
        local replacement = shroud_line(visible_length, prefix)

        vim.api.nvim_buf_set_extmark(0, namespace, i - 1, first - 1 + offset, {
          virt_text = { { replacement, "Comment" } },
          virt_text_pos = "overlay",
          hl_mode = "combine",
        })
      end
    end
  end
end

M.reshroud = function()
  if not M.opts.enabled then
    return
  end

  -- Resets the line shrouding to prevent ghosting issues
  M.unshroud()

  for _, pattern in ipairs(M.opts.patterns) do
    M.shroud(pattern)
  end
end

M.unshroud = function()
  vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
end

M.unshroud_line = function(line)
  if not line then
    error("Line number is required to unshroud a specific line")
  end

  vim.api.nvim_buf_clear_namespace(0, namespace, line - 1, line)

  -- Add listener to track any movement in the buffer, and remove the unshroud from this line
end

M.enable = function()
  if M.opts.enabled then
    return
  end

  M.opts.enabled = true
  vim.b.shroud_enabled = true

  for _, pattern in ipairs(M.opts.patterns) do
    M.shroud(pattern)
  end

  -- Set the visible line number to nil to indicate no line is currently unshrouded
  M.opts._visible_lin_num = nil
end

M.disable = function()
  if not M.opts.enabled then
    return
  end

  M.opts.enabled = false
  vim.b.shroud_enabled = false
  M.unshroud()
end

M.toggle = function()
  if M.opts.enabled then
    M.disable()
  else
    M.enable()
  end
end

M.peek = function()
  local buf = vim.api.nvim_win_get_buf(0)
  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  M.opts._visible_lin_num = line_number

  vim.api.nvim_create_autocmd(
    { "CursorMoved", "CursorMovedI", "BufLeave" }, {
      buffer = buf,
      callback = function()
        M.opts._visible_lin_num = nil
        M.reshroud()

        return true
      end,
      group = group,
    }
  )

  M.unshroud_line(line_number)
end

return M
