-- Tool for launching other applications in container with changed filesystem.
-- (c) ProgramCrafter, 2022

-- Contains partial copy of /lib/package.lua and /lib/io.lua by Sangar.
--[[
=================================================================================
| Copyright (c) 2013-2015 Florian "Sangar" Nücke                                |
|                                                                               |
| Permission is hereby granted, free of charge, to any person obtaining a copy  |
| of this software and associated documentation files (the "Software"), to deal |
| in the Software without restriction, including without limitation the rights  |
| to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     |
| copies of the Software, and to permit persons to whom the Software is         |
| furnished to do so, subject to the following conditions:                      |
|                                                                               |
| The above copyright notice and this permission notice shall be included in    |
| all copies or substantial portions of the Software.                           |
|                                                                               |
| THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    |
| IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      |
| FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   |
| AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        |
| LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, |
| OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     |
| THE SOFTWARE.                                                                 |
=================================================================================
]]

local ser = require 'serialization'
local fs  = require 'filesystem'
local evt = require 'event'
local shl = require 'shell'

local cwd = '/home/'

local openos = '/' -- please, point to the newest version of OpenOS
-- local openos = '/mnt/b66'

local handle = io.open('archive.bin', 'rb')

local files = {}
local dirs = {}

for i = 1, string.unpack('<I4', handle:read(4)) do
  local plen = string.unpack('<I8', handle:read(8))
  local path = handle:read(plen)
  
  if path:sub(-1) ~= '/' then
    files[path] = {}
    files[path].size = string.unpack('<I4', handle:read(4))
    files[path].offset = handle:seek('cur', 0)
    
    handle:seek('cur', files[path].size)
  else
    dirs[path] = true
  end
end

--------------------------------------------------------------------------------

local function copysome(t1, t2, filter)
  for _, k in ipairs(filter) do t2[k] = t1[k] end
end
local function copyto(t1, t2)
  for k, v in pairs(t1) do t2[k] = v end
end
local function copy(t)
  local t2 = {}
  copyto(t, t2)
  return t2
end

local env = copy(_G)

--------------------------------------------------------------------------------

local custom_fs = {}
local custom_fs_proxy = {address = '00000000-0000-4649-4C45-53595354454D', slot = -1}

function custom_fs.isAutorunEnabled() return false end
function custom_fs.setAutorunEnabled() end
custom_fs.canonical = fs.canonical
custom_fs.segments = fs.segments
custom_fs.concat = fs.concat
custom_fs.path = fs.path
custom_fs.name = fs.name
function custom_fs.proxy() return custom_fs_proxy end
function custom_fs.mount() return nil, 'mounting not supported' end
function custom_fs.mounts() return function() end end
function custom_fs.umount() return nil, 'unmounting not supported' end
function custom_fs.isLink() return false end
function custom_fs.link() return nil, 'links not supported' end
function custom_fs.get() return custom_fs_proxy, '/' end
function custom_fs.exists(path)
  if path:sub(-1) == '/' then
    return dirs[fs.canonical(path)] or fs.exists(openos .. fs.canonical(path))
  end
  
  local handle = custom_fs.open(path, 'r')
  if handle then handle:close() return true end
  
  -- testing dirs
  return dirs[fs.canonical(path .. '/')] or fs.exists(openos .. fs.canonical(path .. '/'))
end
function custom_fs.size(path)
  path = fs.canonical(path)  -- removing dangerous ..
  if path:sub(1, 1) ~= '/' then
    path = '/home/' .. path
  end
  
  if files[path] then
    return files[path].size
  else
    return fs.size(openos .. path)
  end
end
function custom_fs.isDirectory(path)
  return dirs[fs.canonical(path)] or fs.isDirectory(openos .. fs.canonical(path))
end
function custom_fs.lastModified() return 0 end
function custom_fs.list(base_path)
  local t, i = {}, 0
  
  base_path = fs.canonical(base_path)
  if base_path:sub(-1) ~= '/' then    base_path = base_path .. '/'    end
  
  local n = #base_path
  for path in pairs(files) do
    if #path > n and path:sub(1, n) == base_path and not path:sub(n + 1, -2):find('/') then
      t[#t + 1] = path:sub(n + 1)
    end
  end
  
  for path in fs.list(openos .. base_path) do    t[#t + 1] = path    end
  return    function()  i = i + 1  return t[i]  end
end
function custom_fs.makeDirectory() return nil, 'making directories not supported' end
function custom_fs.remove() return nil, 'removing files not supported' end
function custom_fs.rename() return nil, 'renaming files not supported' end
function custom_fs.copy() return nil, 'copying files not supported' end
function custom_fs.open(path, mode)
  if path == '/dev/null' then
    assert(mode == 'w' or mode == 'wb' or mode == 'wt', '/dev/null only supports writing')
    return {
      read = error,  seek = error,  close = function() end,  write = function() return true end
    }
  end
  if path == '/dev/full' then
    assert(mode == 'w' or mode == 'wb' or mode == 'wt', '/dev/full only supports writing')
    return {
      read = error,  seek = error,  close = function() end,  write = function() return false, 'no space available' end
    }
  end
  
  assert(not mode or mode == 'r' or mode == 'rb', 'unsupported open type: ' .. tostring(mode))
  
  path = fs.canonical(path)  -- removing dangerous ..
  if path:sub(1, 1) ~= '/' then
    path = cwd .. path
  end
  
  if files[path] then
    local file = files[path]
    local i = 0
    
    return {
      read = function(self, n)
        if i == file.size then return nil end
        
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
      end,
      seek = function(self, whence, offset)
        offset = offset or 0
        if not whence or whence == 'cur' then
          i = math.min(i + offset, file.size)
        elseif whence == 'set' then
          i = math.min(offset, file.size)
        elseif whence == 'end' then
          i = file.size + math.min(offset, 0)
        else
          error 'unknown whence'
        end
        return i
      end
    }
  else
    return io.open(openos .. path)
  end
end
function custom_fs.realPath(path) return custom_fs.canonical(path) end

--------------------------------------------------------------------------------

local function searchpath(name, path, sep, rep)
  checkArg(1, name, "string")
  checkArg(2, path, "string")
  sep = sep or '.'
  rep = rep or '/'
  sep, rep = '%' .. sep, rep
  name = string.gsub(name, sep, rep)
  local fs = custom_fs
  local errorFiles = {}
  for subPath in string.gmatch(path, "([^;]+)") do
    subPath = string.gsub(subPath, "?", name)
    if subPath:sub(1, 1) ~= "/" then
      subPath = fs.concat(cwd, subPath)
    end
    if fs.exists(subPath) then
      local file = fs.open(subPath, "r")
      if file then
        file:close()
        return subPath
      end
    end
    table.insert(errorFiles, "\tno file '" .. subPath .. "'")
  end
  return nil, table.concat(errorFiles, "\n")
end

local function _loadfile(path)
  local lib, reason = custom_fs.open(path, 'r')
  if not lib then return lib, reason end
  local code = lib:read('*a')
  lib:close()
  
  lib, reason = load(code, path, 't', env)
  return lib, reason
end

local loading = {}
function env.require(module)
  checkArg(1, module, "string")
  if env.package.loaded[module] ~= nil then
    return env.package.loaded[module]
  elseif not env.package.loading[module] then
    local library, status, step

    step, library, status = "not found", searchpath(module, env.package.path)

    if library then
      step, library, status = "loadfile failed", _loadfile(library)
    end

    if library then
      env.package.loading[module] = true
      step, library, status = "load failed", pcall(library, module)
      env.package.loading[module] = false
    end

    assert(library, string.format("module '%s' %s:\n%s", module, step, status))
    env.package.loaded[module] = status
    return status
  else
    error("already loading: " .. module .. "\n" .. debug.traceback(), 2)
  end
end
function package_delay(lib, file)
  local mt = {}
  function mt.__index(tbl, key)
    mt.__index = nil
    env.loadfile(file)()
    return tbl[key]
  end
  if lib.internal then
    setmetatable(lib.internal, mt)
  end
  setmetatable(lib, mt)
end

--------------------------------------------------------------------------------

function _io_open(path, mode)
  local resolved_path = env.require('shell').resolve(path)
  local stream, result = env.require('filesystem').open(resolved_path, mode)
  if stream then
    return env.require('buffer').new(mode, stream)
  else
    return nil, result
  end
end

--------------------------------------------------------------------------------

local args = {...}

local program = assert(table.remove(args, 1))
local prog_path = shl.resolve(program, 'lua')

env.loadfile = _loadfile
env.package = copy(_G.package)
env.package.searchpath = searchpath
env.package.loaded = {}

copysome(package.loaded, env.package.loaded,
  {'component', 'computer', 'string', 'table', 'serialization', 'math',
   'coroutine', 'event', 'unicode', 'os'})
env.package.loaded.package = env.package
env.package.loaded.filesystem = custom_fs
env.package.loading = loading
env.package.delay = package_delay

env.io = copy(_G.io)
env.io.open = _io_open
env.io.stdin = env.io.input()
env.io.stdout = env.io.output()
env.io.stderr = env.io.error()

-- Forwarding some libraries into container.

-- env.require('tty').isAvailable = require('tty').isAvailable
env.package.loaded.process = require('process')
env.package.loaded.tty = require('tty')

env._G = env
env._ENV = env

-- allow launching programs from container
local prog_handle = assert(custom_fs.open(prog_path) or io.open(prog_path))
local prog_code = prog_handle:read('*a')
prog_handle:close()

local prog_fn = assert(load(prog_code, program, 't', env))
prog_fn(table.unpack(args))
