local mark = require("smolmark")

local function writehtmlfile(txtpath)
  local htmlpath = txtpath:sub(1, -5) .. ".html"
  local fin = io.open(txtpath)
  local lines = fin:lines()
  local fout = io.open(htmlpath, "w")
  local parse = mark.parse(lines)
  local firsthtml, title = parse()
  fout:write([[<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>]])
    fout:write(mark.escape(title.text or "untitled"))
    fout:write([[</title>
  </head>
  <body>]])
  fout:write(firsthtml)
  for html, _ in parse do
    fout:write(html)
  end
  fout:write([[</body>
</html>]])
  assert(fout:close())
  assert(fin:close())
end

local windows = package.config:sub(1, 1) == "\\"
local cmd = [[powershell.exe "gci -Recurse -Filter '*.txt' | rvpa -Relative"]]
local lunix = [[find . -name \*.txt -print]]
local command = windows and cmd or lunix
local pipe = io.popen(command)
local str = pipe:read()
while str do
  writehtmlfile(str)
  str = pipe:read()
end
assert(pipe:close())

