local ser = require 'serialization'
local fs  = require 'filesystem'
local cmp = require 'computer'

local base = '/'
local vs   = '/mnt/b66/'  -- clean installation

local paths = {}
local function traverse_pos(path)
  local path_exact_fs = fs.get(path)
  
  for file in fs.list(path) do
    if file:sub(-1) == '/' then
      -- directory
      -- checking if it's on same file system
      
      local dir_exact_fs = fs.get(path .. file)
      if dir_exact_fs == path_exact_fs and file ~= 'mnt/' then
        print('Falling into ' .. path .. file)
        
        paths[path .. file] = true
        traverse_pos(path .. file)
        os.sleep(0)
      end
    else
      paths[path .. file] = ''
    end
  end
end
local function traverse_neg(path, erase_path)
  local path_exact_fs = fs.get(path)
  
  for file in fs.list(path) do
    if file:sub(-1) == '/' then
      -- directory
      -- checking if it's on same file system
      
      local dir_exact_fs = fs.get(path .. file)
      if dir_exact_fs == path_exact_fs and file ~= 'mnt/' then
        print('Falling into ' .. path .. file)
        
        paths[erase_path .. file] = nil
        traverse_neg(path .. file, erase_path .. file)
        os.sleep(0)
      end
    else
      paths[erase_path .. file] = nil
    end
  end
end

---------------------------------------------------

traverse_pos(base);            print(('='):rep(75))
traverse_neg(vs, base);        print(('='):rep(75))
print(ser.serialize(paths));   print(('='):rep(75))

paths['/home/archive.bin'] = nil

---------------------------------------------------

local handle = io.open('/home/archive.bin', 'wb')

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
