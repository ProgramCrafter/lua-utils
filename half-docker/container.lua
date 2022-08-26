local ser = require 'serialization'
local evt = require 'event'
local shl = require 'shell'

local openos = '/mnt/b66'
local handle = io.open('archive.bin', 'rb')

local files = {}

for i = 1, string.unpack('<I4', handle:read(4)) do
  local plen = string.unpack('<I8', handle:read(8))
  local path = handle:read(plen)
  
  if path:sub(-1) ~= '/' then
    files[path] = {}
    files[path].size = string.unpack('<I4', handle:read(4))
    files[path].offset = handle:seek('cur', 0)
    
    handle:seek('cur', files[path].size)
  end
end

local function open(path, mode)
  assert(not mode or mode == 'r' or mode == 'rb', 'unsupported open type: ' .. tostring(mode))
  
  path = require 'filesystem'.canonical(path)  -- removing dangerous ..
  if path:sub(1, 1) ~= '/' then
    path = '/home/' .. path
  end
  
  if files[path] then
    local file = files[path]
    local i = 0
    
    return {
      read = function(self, n)
        handle:seek('set', file.offset + i)
        
        if n == '*a' then n = file.size - i end
        assert(type(n) ~= 'string', 'unsupported read type: ' .. n)
        
        n = math.min(n or math.huge, file.size - i)
        
        local result, reason = handle:read(n)
        if result then i = i + #result end
        return result, reason
      end,
      close = function(self)
        file = nil
      end
    }
  else
    return io.open(openos .. path)
  end
end

local function copyto(t1, t2)
  for k, v in pairs(t1) do t2[k] = v end
end
local function copy(t)
  local t2 = {}
  copyto(t, t2)
  return t2
end

local args = {...}

local program = assert(table.remove(args, 1))
local prog_path = shl.resolve(program, 'lua')

local env = copy(_G)
env.io = copy(_G.io)
env.io.open = open
env._G = env
env._ENV = env

local prog_handle = assert(open(prog_path) or io.open(prog_path))  -- allow launching programs in container
local prog_code = prog_handle:read('*a')
prog_handle:close()

local prog_fn = assert(load(prog_code, program, 't', env))
prog_fn(table.unpack(args))
