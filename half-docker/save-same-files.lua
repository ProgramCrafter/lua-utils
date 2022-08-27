local ser = require 'serialization'
local fs  = require 'filesystem'
local cmp = require 'computer'

local base = 'archive.bin'
local paths = {}

---------------------------------------------------

local handle = io.open(base, 'rb')

for i = 1, string.unpack('<I4', handle:read(4)) do
  local plen = string.unpack('<I8', handle:read(8))
  local path = handle:read(plen)
  
  if path:sub(-1) ~= '/' then
    local size = string.unpack('<I4', handle:read(4))
    handle:seek('cur', size)
  end
  
  if fs.exists(path) then
    paths[path] = true
  else
    print('Warning: lost file ' .. path)
  end
end

handle:close()

---------------------------------------------------

local handle = io.open(base, 'wb')

local paths_count = 0
for _ in pairs(paths) do
  paths_count = paths_count + 1
end

handle:write(string.pack('<I4', paths_count))

for file in pairs(paths) do
  handle:write(string.pack('<s', file))
  
  if file:sub(-1) ~= '/' then
    handle:write(string.pack('<I4', fs.size(file)))
    
    local file_data = io.open(file, 'rb')
    handle:write(file_data:read('*a'))
    file_data:close()
  end
end

handle:close()
