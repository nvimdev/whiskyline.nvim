local co, api = coroutine, vim.api
local whk = {}

local function stl_format(name, val)
  return '%#Whisky' .. name .. '#' .. val .. '%*'
end

local function stl_hl(name, attr)
  api.nvim_set_hl(0, 'Whisky' .. name, attr)
end

function whk.gen_pieces()
  local pieces = {}
  if not whk.cache then
    whk.cache = {}
  end
  for i, e in pairs(whk.elements) do
    local res = e()
    table.insert(pieces, stl_format(res.name, res.stl))
    if res.attr then
      stl_hl(res.name, res.attr)
    end
    whk.cache[i] = {
      event = type(res.event) == 'string' and { res.event } or res.event,
      name = res.name,
      stl = res.stl,
    }
  end
  require('whiskyline.provider').initialized = true
  return table.concat(pieces, '')
end

function whk.refresh(event)
  local data = {}
  for i, item in pairs(whk.cache or {}) do
    if item.event and vim.tbl_contains(item.event, event) then
      local comp = whk.elements[i]
      local res = comp()
      item.stl = res.stl
      if res.attr then
        stl_hl(item.name, res.attr)
      end
    end
    table.insert(data, stl_format(item.name, item.stl))
  end
  return table.concat(data, '')
end

function whk.render(event)
  if not whk.cache then
    return whk.gen_pieces()
  else
    return whk.refresh(event)
  end
end

local function default()
  local p = require('whiskyline.provider')
  return {
    p.sep,
    p.mode,
    p.sep,
    p.fileicon,
    p.fileinfo,
    p.sep,
    p.lnumcol,
    p.sep,
    p.diagError,
    p.diagWarn,
    p.diagInfo,
    p.diagHint,
    p.pad,
    p.lsp,
    p.pad,
    p.gitadd,
    p.sep,
    p.gitchange,
    p.sep,
    p.gitdelete,
    p.sep,
    p.branch,
    p.sep,
    p.encoding,
    p.sep,
  }
end

function whk.setup()
  whk.elements = default()

  local stl_render = co.create(function()
    local event
    while true do
      local pieces = whk.render(event)
      event = co.yield(pieces)
    end
  end)

  api.nvim_create_autocmd({ 'User' }, {
    pattern = { 'LspProgressUpdate', 'GitSignsUpdate' },
    callback = function(opt)
      if opt.event == 'User' then
        opt.event = opt.match
      end

      local status, stl = co.resume(stl_render, opt.event)
      if status then
        vim.wo.stl = stl
      end
      -- run once again make sure it update the lsp name
      if opt.event == 'LspProgressUpdate' then
        status, stl = co.resume(stl_render, opt.event)
        if status then
          vim.wo.stl = stl
        end
      end
    end,
  })

  api.nvim_create_autocmd(
    { 'DiagnosticChanged', 'ModeChanged', 'WinEnter', 'BufEnter', 'CursorHold' },
    {
      callback = function(opt)
        local status, stl = co.resume(stl_render, opt.event)
        if status then
          vim.wo.stl = stl
        end
      end,
    }
  )
end

return whk