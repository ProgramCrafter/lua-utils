local handle = io.open('archive.bin', 'rb')

for i = 1, string.unpack('<I4', handle:read(4)) do
  local plen = string.unpack('<I8', handle:read(8))
  local path = handle:read(plen)
  
  if path:sub(-1) == '/' then
    os.execute('mkdir ' .. path .. ' >/dev/null 2>/dev/null')
  else
    local file_size = string.unpack('<I4', handle:read(4))
    
    local file_data = io.open(path, 'wb')
    file_data:write(handle:read(file_size))
    file_data:close()
  end
end

handle:close()
