local escapechar = {
  ["<"] = "&lt;",
  [">"] = "&gt;",
  ['"'] = "&quot;",
  ["'"] =  "&apos;",
  ["&"] = "&amp;"
}

local formatting

local function strhtml(str)
  local res = {}
  local current = {}
  local mode = ""
  local function switch(char)
    local s = table.concat(current)
    local formatted = formatting[mode](s, url)
    table.insert(res, formatted)
    current = {}
    mode = char
  end
  local startpos = 1
  while true do
    local pos, _ = str:find("[_`\\^]", startpos)
    if not pos then
      table.insert(current, str:sub(startpos, #str))
      switch()
      return table.concat(res)
    end

    table.insert(current, str:sub(startpos, pos - 1))

    local char = str:sub(pos, pos)
    if char == "\\" then
      table.insert(current, str:sub(pos + 1, pos + 1))
      startpos = pos + 2
    else
      if mode == "" then switch(char)
      elseif char == mode then switch("")
      else table.insert(current, char)
      end
      startpos = pos + 1
    end
  end
end

local function escape(str)
  local res, _ = (str or ""):gsub("[<>\"'&]", escapechar)
  return res
end

function tagged(tag)
  return function(s)
    return "<" .. tag .. ">" .. (inner or strhtml)(s) .. "</" .. tag .. ">"
  end
end

function link(str)
  local url, desc = str:match("^%s*(%S+)%s*(.-)%s*$")
  if not url then return escape(str) end

  url = escape(url)
  local desc = ((desc ~= "") and escape(desc)) or fullurl
  return '<a href="' .. url .. '">' .. desc .. '</a>'
end

formatting = {
  ["`"] = tagged("code", escape),
  ["_"] = tagged("em", escape),
  ["^"] = link,
  [""] = escape
}

local states = {
  { pattern = "^  (.*)$", open = "<pre><code>", close = "</code></pre>", f = escape, br = "\n" },
  { pattern = "^(%s*)$", f = function(str) return "" end },
  { pattern = "^## *(.*)$", close = "\n", f = tagged("h2") },
  { pattern = "^# *(.*)$", close = "\n", f = tagged("h1") },
  { pattern = "^[*] *(.*)$", open = "<ul>", close = "</ul>\n", f = tagged("li") },
  { pattern = "^ *(.*)$", open = "<p>", close = "</p>\n", f = function(str) return strhtml(str) end, br = "<br>" }
}

local function parseline(str)
  for _, state in ipairs(states) do
    local text = str:match(state.pattern)
    if text then return { state = state, text = text, html = state.f(text) } end
  end
  error("unreachable")
end

function parse(lines)
  local state = states[2]
  local function f()
    for line in lines do
      local res = parseline(line)
      if res.state ~= state then
        if state.close then coroutine.yield(state.close, res) end
        state = res.state
        if state.open then coroutine.yield(state.open, res) end
      elseif state.br then
        coroutine.yield(state.br, res)
      end
      coroutine.yield(res.html, res)
    end
    if state.close then coroutine.yield(state.close) end
  end
  return coroutine.wrap(f)
end

return { escape = escape, parse = parse }

