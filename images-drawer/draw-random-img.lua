local ser = require 'serialization'
local com = require 'component'
local cmp = require 'computer'
local unc = require 'unicode'
local evt = require 'event'
local gpu = com.gpu
local int = com.internet

_G.bit32 = require 'bit32'
local png_available, png_graffiti = pcall(require, 'graffiti')
if not png_available then
  os.execute('mkdir /usr/lib >/dev/null 2>/dev/null')
  os.execute('wget -f https://pastebin.com/raw/1WmfjNfU /usr/lib/graffiti.lua')
  png_available, png_graffiti = pcall(require, 'graffiti')
end
_G.bit32 = nil

package.loaded['gif'] = nil
local gif_available, gif_lib = pcall(require, 'gif')
if not gif_available then
  os.execute('wget -f https://github.com/Xytabich/GIF-Lua/raw/master/5.3/gif.lua /usr/lib/gif.lua')
  gif_available, gif_lib = pcall(require, 'gif')
end

local handle, reason = io.open '/usr/bin/JPGDraw.lua'
if not handle then
  os.execute('mkdir /usr/bin >/dev/null 2>/dev/null')
  os.execute('wget -f https://pastebin.com/raw/TvQZb6fu /usr/bin/JPGDraw.lua')
else
  handle:close()
end

-- Config

local waifu_pics_base = 'https://api.waifu.pics/sfw/'

local categories = {'waifu', 'neko', 'shinobu', 'megumin', 'bully', 'cuddle',
                    'cry', 'hug', 'awoo', 'kiss', 'lick', 'pat', 'smug', 'bonk',
                    'yeet', 'blush', 'smile', 'wave', 'highfive', 'handhold',
                    'nom', 'bite', 'glomp', 'slap', 'kill', 'kick', 'happy',
                    'wink', 'poke', 'dance'}
-- {'waifu', 'neko', 'trap', 'blowjob'}

-- Config end

local function setForeground(f)
  if gpu.getForeground() ~= f then
    gpu.setForeground(f)
  end
end
local function setBackground(b)
  if gpu.getBackground() ~= b then
    gpu.setBackground(b)
  end
end
local function set_halfpixel(x, y, back, fore)
  local bg, fg = gpu.getBackground(), gpu.getForeground()
  if bg == fore then
    gpu.setForeground(back)
    gpu.set(x, y, unc.char(0x2584))
  else
    if bg ~= back then gpu.setBackground(back) end
    if fg ~= fore then gpu.setForeground(fore) end
    gpu.set(x, y, unc.char(0x2580))
  end
end

local function exact_readable(stream)
  return {
    read = function(n)
      n = n or 1
      
      local result = ''
      while #result < n do
        result = result .. stream.read(n - #result)
        gpu.set(40, 25, tostring(#result) .. '/' .. tostring(n) .. '     ')
        os.sleep(0.05)
      end
      return result
    end,
    read_between = function(n, m)
      n = n or 1
      
      local result = ''
      while #result < n do
        result = result .. stream.read(m - #result)
        -- gpu.set(40, 25, tostring(#result) .. '/' .. tostring(math.floor(n)) .. '/' .. tostring(m) .. '     ')
        os.sleep(0)
      end
      return result
    end,
    close = stream.close or function() end
  }
end
local function seekable(exact_readable_stream)
  local cache = ''
  local function ensure_cached(n)
    if #cache < n then cache = cache .. exact_readable_stream.read_between(n - #cache, 131072) end
  end
  
  local ptr = 0
  return {
    read = function(self, n)
      ensure_cached(ptr + n)
      ptr = ptr + n
      return cache:sub(ptr - n + 1, ptr)
    end,
    seek = function(self, whence, pos)
      pos = pos or 0
      if whence == 'set' then
        ptr = pos
        ensure_cached(ptr)
        return ptr
      elseif whence == 'cur' or not whence then
        ptr = ptr + pos
        ensure_cached(ptr)
        return ptr
      end
      error('Unsupported seek method: ' .. (ser.serialize(whence, true) or 'cur'))
    end,
    close = exact_readable_stream.close or function() end
  }
end

-- bmp24 by ov3rwrite
local function bmp24(img, content_length, window)
  local res = content_length - 54  -- count of image bytes not in header
  
  if img:read(2) ~= "BM" then error("input file is not .bmp") end
  img:read(16)
  local w = string.unpack(">B", img:read(1))
  img:read(3)
  local h = string.unpack(">B", img:read(1))
  img:read(31)
  
  local extrabytes = (res - w*h*3) / h -- extra bytes in end of each pixels row
  local rgb_t = {}
  local px_t = {}
  
  local upt = cmp.uptime()
  for i = 1, res - extrabytes*h do
    local byte_to_int = string.unpack(">B", img:read(1))
    table.insert(rgb_t, 1, byte_to_int)
    if i % (w*3) == 0 then -- end of data row
      img:read(extrabytes)
    end
    if #rgb_t == 3 then
      table.insert(px_t, 1, rgb_t[1] * 65536 + rgb_t[2] * 256 + rgb_t[3])
      rgb_t={}
    end
    if i % 20 == 0 and cmp.uptime() >= upt + 4 then
      os.sleep(0)
      upt = cmp.uptime()
    end
  end
  
  gpu.fill(window.x, window.y, window.w, window.h, ' ')
  w = math.min(w, window.w)
  h = math.min(h, window.h)
  
  local l = 1
  for k = 1, math.ceil(h/2) do
    for j = 1, w do
      gpu.setForeground(px_t[l])
      gpu.setBackground(px_t[l + w])
      gpu.set(window.x + w - j + 1, window.y + k, '▀')
      l = l + 1
    end
    l = l + w
  end
end

-- png (graffiti) by Zer0Galaxy
local function png(img, content_length, window)
  local name = '/tmp/' .. tostring(math.random(100000000, 999999999)) .. '.png'
  local handle = io.open(name, 'wb')
  handle:write(img.read(content_length))
  handle:close()
  
  png_graffiti.draw(name, window.x, window.y, window.w, window.h)
end

-- gif by Xytabich
local function gif(img, content_length, window)
  local function unpalette(palette, s, w, h)
    local function get_pixel(x, y)
      return palette[s:byte((y - 1) * w + x)] or 0xFF00FF
    end
    
    return get_pixel
  end
  
  local function linear_downscale(t, frame, palette)
    local w, h = frame.width, frame.height
    frame.width, frame.height = w // 2, h // 2
    
    local function get_pixel(nx, ny)
      return t(nx * 2 - 1, ny * 2 - 1)
    end
    
    return get_pixel
  end
  
  -- img = io.open('/home/test.gif', 'rb')
  
  local colors = {}
  
  -- gpu.setBackground(0x333333)
  -- gpu.fill(window.x, window.y, window.w, window.h, ' ')
  -- gpu.setBackground(0)
  
  local stt = cmp.uptime()
  
  for info, frame in gif_lib.images(img) do
    require 'term'.setCursor(1, 40)
    
    colors = info.colors or frame.colors or colors
    
    os.sleep(0.05) -- freeing memory
    gpu.set(100, 1, 'Free ' .. math.floor(cmp.freeMemory() * 100 / 1024) / 100 .. ' KB  ')
    gpu.set(120, 1, cmp.totalMemory() / 1024 .. ' KB  ')
    
    local pixels = unpalette(colors, frame.pixels, frame.width, frame.height)
    gpu.set(60, 1, #frame.pixels .. 'px  ')
    
    while frame.height * 5 / 6 > window.h * 2 or frame.width * 5 / 6 > window.w do
      pixels = linear_downscale(pixels, frame)
      print('Downscaled to', frame.width, frame.height)
      os.sleep(0.05)
    end
    
    for x = 1, math.min(frame.width, window.w - frame.x) do
      for y = 1, math.min(frame.height, window.h * 2 - frame.y), 2 do
        local tc = pixels(x, y)
        local bc = pixels(x, y + 1)
        
        set_halfpixel(window.x + frame.x + x - 1, window.y + frame.y + (y // 2), tc, bc)
      end
    end
    
    gpu.setBackground(0)
    gpu.setForeground(0xFFFFFF)
    gpu.set(90, 1, math.floor((cmp.uptime() - stt) * 100) / 100 .. 's    ')
    
    break
  end
  
  img:close()
  -- ]==]
end

-- jpg by MeXaN1cK
local function jpg(img, content_length, window)
  --[===[
  local name = --[['/tmp/' ..]] tostring(math.random(100000000, 999999999)) .. '.jpg'
  local handle = io.open(name, 'wb')
  print(handle:write(img.read(content_length)))
  if handle.flush then handle:flush() print(116) end
  handle:close()
  ]===]
  local name = '775251537.0.jpg'
  
  
  local vgpu = {
    ['set'] = function(i, j, k)
      if i > window.w or j > window.h then return end
      gpu.set(window.x + i, window.y + j, k)
    end,
    ['setBackground'] = gpu.setBackground,
    ['setForeground'] = gpu.setForeground,
    ['setResolution'] = function() end
  }
  local vcom = {
    ['gpu'] = vgpu
  }
  local vrequire = function(s)
    if s == 'component' then return vcom end
    return require(s)
  end
  
  local v_G = {}
  for k, v in pairs(_G) do
    v_G[k] = v
  end
  v_G._ENV = v_G
  v_G._G = v_G
  v_G.require = vrequire
  
  local jpg_handle = io.open '/usr/bin/JPGDraw.lua'
  local code = jpg_handle:read '*a'
  jpg_handle:close()
  
  local f, reason = load(code, 'jpg', 't', v_G)
  assert(f, reason)
  f(name)
end

--[[
local api_url = waifu_pics_base .. categories[math.random(1, #categories)]

local r = int.request(api_url, nil, {
  ['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:94.0) Gecko/20100101 Firefox/94.0'
})
while true do
  local success, reason = r.finishConnect()
  if success then break end
  assert(not reason, reason)
end

local result = r.read():gsub('%s', '')
local url = result:sub(9, -3)
]]
local url = 'https://i.waifu.pics/SWMEyvi.gif'
print(url)

-- Checking that given image type can be processed

local ext = url:sub(-3)

local handler = ({['bmp'] = bmp24, ['png'] = png, ['jpg'] = jpg, ['gif'] = gif})[ext]
assert(handler, 'No handler found for this image type')

-- Downloading image

local img = int.request(url, nil, {
  ['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:94.0) Gecko/20100101 Firefox/94.0'
})
while true do
  local success, reason = img.finishConnect()
  if success then break end
  assert(not reason, reason)
end

local _, _, headers = img.response()
handler(seekable(exact_readable(img)),
        tonumber(headers['Content-Length'][1]),
        {x = 1, y = 3, w = 160, h = 50 - 2})
