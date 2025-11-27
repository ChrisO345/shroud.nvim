local group = vim.api.nvim_create_augroup("shroud", {})
local namespace = vim.api.nvim_create_namespace("shroud")

local M = {}

M.opts = {
  enabled = true,
  patterns = { { file = "*.env*", shroud = "=.*" } },
  character = "*",
  offset = 1,           -- Set to 1 to include the prefix character in the shrouded text
  on_shroud = function() -- Disable completion when shrouding
    require("cmp").setup.buffer({ enabled = false })
  end,
  on_unshroud = function() -- Enable completion when unshrouding
    require("cmp").setup.buffer({ enabled = true })
  end,
  snacks = true, -- Enable snacks integration if available
}

M.setup = function(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
  vim.b.shroud_enabled = M.opts.enabled

  for _, pattern in ipairs(M.opts.patterns) do
    if not pattern.file or not pattern.shroud then
      error("Invalid pattern: " .. vim.inspect(pattern))
    end

    vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI", "TextChangedP" }, {
      pattern = pattern.file,
      callback = function()
        if M.opts.enabled then
          M.shroud(pattern)
        else
          M.unshroud()
        end
      end,
      group = group,
    })

    if M.opts.snacks then
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "snacks_picker_input",
        callback = function()
          M.enable_snacks(pattern)
        end,
        group = group,
      })
    end
  end

  local usercmd = vim.api.nvim_create_user_command
  usercmd("ShroudEnable", M.enable, {})
  usercmd("ShroudDisable", M.disable, {})
  usercmd("ShroudToggle", M.toggle, {})
  usercmd("ShroudPeek", M.peek, {})
end

M.shroud = function(pattern, buf)
  -- Resets the line shrouding to prevent ghosting issues
  M.unshroud()

  if M.opts.on_shroud then
    M.opts.on_shroud()
  end

  if not buf then
    buf = 0
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    if i ~= vim.b.visible_line_num then
      local function shroud_line(length, prefix)
        local shroud_str = prefix .. M.opts.character:rep(length)
        local remaining_length = length - vim.fn.strchars(shroud_str)

        -- Detemine offset
        shroud_str = shroud_str:sub(M.opts.offset + 1)

        return shroud_str .. ("?"):rep(remaining_length)
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

        vim.api.nvim_buf_set_extmark(buf, namespace, i - 1, first - 1 + offset, {
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

  if M.opts.on_unshroud then
    M.opts.on_unshroud()
  end
end

M.unshroud_line = function(line)
  if not line then
    error("Line number is required to unshroud a specific line")
  end

  vim.api.nvim_buf_clear_namespace(0, namespace, line - 1, line)
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

  vim.b.visible_line_num = nil
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
  vim.b.visible_line_num = line_number

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
    buffer = buf,
    callback = function()
      vim.b.visible_line_num = nil
      M.reshroud()

      return true
    end,
    group = group,
  })

  M.unshroud_line(line_number)
end

local function glob_to_pattern(glob)
  local pattern = glob:gsub("([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1") -- escape Lua special chars
  pattern = pattern:gsub("%*", ".*")                             -- convert * to .*
  pattern = pattern:gsub("%?", ".")                              -- convert ? to .
  return pattern
end

M.enable_snacks = function(pattern)
  local title_filter = pattern.file or nil
  if not title_filter then
    return
  end

  title_filter = glob_to_pattern(title_filter)

  local picker_buf = vim.api.nvim_get_current_buf()
  local group_ = vim.api.nvim_create_augroup("shroud_snacks_preview", { clear = false })

  -- Helper: get the floating window title for a preview buffer
  local function get_preview_window_title(buf)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == buf then
        local ok, config = pcall(vim.api.nvim_win_get_config, win)
        if ok and config and config.title then
          return config.title
        end
      end
    end
    return nil
  end

  -- Helper: determine if title contains the filter pattern
  local function title_matches(title, pattern_)
    if not title then
      return false
    end
    for _, segment in ipairs(title) do
      local text = segment[1]
      if text:match(pattern_) then
        return true
      end
    end
    return false
  end

  -- Helper: shroud preview buffers that match the title pattern
  local function shroud_preview()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
        if ft == "snacks_picker_preview" then
          local title = get_preview_window_title(buf)
          if title_matches(title, title_filter) then
            M.shroud(pattern, buf)
          end
        end
      end
    end
  end

  -- Key press detection in picker buffer
  _ = vim.on_key(function()
    if vim.api.nvim_get_current_buf() == picker_buf then
      vim.defer_fn(shroud_preview, 5) -- allow Snacks to update preview first
      M.a = (M.a or 0) + 1
    end
  end, picker_buf)

  -- Detect text changes and buffer writes in preview buffers
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
    group = group_,
    pattern = "*",
    callback = function(args)
      local ft = vim.api.nvim_get_option_value("filetype", { buf = args.buf })
      if ft == "snacks_picker_preview" then
        vim.defer_fn(shroud_preview, 5)
      end
    end,
  })
end

return M
