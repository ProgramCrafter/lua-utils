local ser = require 'serialization'
local com = require 'component'
local cmp = require 'computer'
local unc = require 'unicode'
local evt = require 'event'
local gpu = com.gpu
local int = com.internet

_G.bit32 = require 'bit32'
_G.warn = print
package.loaded['graffiti'] = nil
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

local stage = ''
local stage_start = 0

local n = 0
local old_pull_signal = cmp.pullSignal
function cmp.pullSignal(...)
  n = n + 1
  if n % 4 == 0 then
    local s = stage .. ' | ' .. math.floor((cmp.uptime() - stage_start) * 10) / 10 .. 's'
    gpu.set(61, 1, s .. (' '):rep(100 - #s))
  end
  
  return old_pull_signal(...)
end

local function mark_stage(s)
  if not s then
    stage = s
    cmp.pullSignal = old_pull_signal
    return
  end
  
  stage = s
  stage_start = cmp.uptime()
  
  s = s .. ' | 0s'
  gpu.set(61, 1, s .. (' '):rep(100 - #s))
end

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
        local chunk = assert(stream.read(n - #result))
        result = result .. chunk
        
        if #chunk >= 1024 then os.sleep(0) end
      end
      return result
    end,
    read_between = function(n, m)
      m = math.max(n, m)
      
      local result = ''
      while #result < n do
        local chunk = assert(stream.read(m - #result))
        result = result .. chunk
        
        if #chunk >= 2048 then os.sleep(0) end
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
  -- local name = '/tmp/' .. tostring(math.random(100000000, 999999999)) .. '.png'
  local name = '/home/25082022.736.png'
  if img then
    mark_stage 'Downloading image'
    
    local handle = io.open(name, 'wb')
    handle:write(img:read(content_length))
    handle:close()
  end
  
  mark_stage 'Drawing image'
  png_graffiti.draw(name, window.x, window.y * 2 - 1, window.w, window.h * 2)
  
  mark_stage(nil)
  evt.pull 'touch'
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
  
  local colors = {}
  
  
  mark_stage('Requesting GIF frame')
  
  for info, frame in gif_lib.images(img) do
    mark_stage('Downscaling GIF frame')
    
    colors = info.colors or frame.colors or colors
    
    os.sleep(0.05) -- freeing memory
    
    local pixels = unpalette(colors, frame.pixels, frame.width, frame.height)
    
    return pixels, frame.width, frame.height
    
    --[[
    while frame.height * 5 / 6 > window.h * 2 or frame.width * 5 / 6 > window.w do
      pixels = linear_downscale(pixels, frame)
      os.sleep(0.05)
    end
    
    mark_stage('Drawing GIF frame')
    
    for x = 1, math.min(frame.width, window.w - frame.x) do
      for y = 1, math.min(frame.height, window.h * 2 - frame.y), 2 do
        local tc = pixels(x, y)
        local bc = pixels(x, y + 1)
        
        set_halfpixel(window.x + frame.x + x - 1, window.y + frame.y + (y // 2), tc, bc)
      end
    end
    
    setBackground(0)
    setForeground(0xFFFFFF)
    
    break
    ]]
  end
  
  mark_stage(nil)
  
  img:close()
  -- ]==]
end

-- jpg by MeXaN1cK
local function jpg(img, content_length, window)
  local name = '/home/775251537.0.jpg'
  -- local name = --[['/tmp/' ..]] tostring(math.random(100000000, 999999999)) .. '.jpg'
  if img then
    mark_stage 'Downloading image'
    
    local handle = io.open(name, 'wb')
    handle:write(img:read(content_length))
    handle:close()
  end
  
  mark_stage 'Preparing venv'
  
  local v_G = {}
  for k, v in pairs(_G) do
    v_G[k] = v
  end
  v_G._ENV = v_G
  v_G._G = v_G
  
  setmetatable(v_G, {
    __newindex = function(self, k, v)
      print('Warning: write to global env', k, v)
      rawset(v_G, k, v)
    end
  })
  
  local jpg_handle = io.open '/usr/bin/JPGDraw.lua'
  local code = jpg_handle:read '*a'
  jpg_handle:close()
  
  local f, reason = load(code, 'jpg', 't', v_G)
  assert(f, reason)
  
  mark_stage 'Loading image'
  return f(name)
end

local function draw(get_pixel, frame, window)
  assert(frame.w * frame.h > 0, 'empty frame')
  
  mark_stage('Drawing image')
  
  io.write(window.w, '\t', window.h, '\t', frame.w, '\t', frame.h)
  local scale = math.min(window.w / frame.w, window.h / frame.h * 2)
  window.w = math.floor(frame.w * scale)
  window.h = math.floor(frame.h * scale / 2)
  print('->', scale, window.w, window.h)
  
  local function to_rgb(px)
    return px >> 16, (px >> 8) & 255, px & 255
  end
  local function from_rgb(r, g, b)
    return (r << 16) + (g << 8) + b
  end
  
  local function mix(lt, rt, lb, rb, x, y)
    x = x % 1    y = y % 1
    return math.floor(
      lt * (1-x) * (1-y)    +    rt * x * (1-y)    +
      lb * (1-x) * y        +    rb * x * y
    )
  end
  local function mix_rgb(px_lt, px_rt, px_lb, px_rb, x, y)
    local r_lt, g_lt, b_lt = to_rgb(px_lt or 0xFF00FF)
    local r_rt, g_rt, b_rt = to_rgb(px_rt or 0xFF00FF)
    local r_lb, g_lb, b_lb = to_rgb(px_lb or 0xFF00FF)
    local r_rb, g_rb, b_rb = to_rgb(px_rb or 0xFF00FF)
    
    return from_rgb(
      mix(r_lt, r_rt, r_lb, r_rb, x, y),
      mix(g_lt, g_rt, g_lb, g_rb, x, y),
      mix(b_lt, b_rt, b_lb, b_rb, x, y)
    )
  end
  
  local function interpolate(small_x, small_y)
    local big_x = math.floor(small_x / scale)
    local big_y = math.floor(small_y / scale)
    
    return get_pixel(big_x, big_y) or 0xFF00FF
    --[[
    return mix_rgb(
      get_pixel(big_x, big_y),      get_pixel(big_x + 1, big_y),
      get_pixel(big_x, big_y + 1),  get_pixel(big_x + 1, big_y + 1),
      
      small_x * scale - big_x,      small_y * scale - big_y
    )
    ]]
  end
  
  for x = 1, window.w do
    for y = 1, window.h, 2 do
      local tc = interpolate(x, y)
      local bc = interpolate(x, y + 1)
      
      set_halfpixel(window.x + x - 1, window.y + (y // 2), tc, bc)
    end
  end
  
  setBackground(0)
  setForeground(0xFFFFFF)
  
  mark_stage(nil)
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

local url = 'https://cdn.catboys.com/images/image_180.jpg'
-- local url = 'https://cdn.catboys.com/images/image_171.jpg'  -- unsupported compression
-- local url = 'https://i.waifu.pics/X9GqUZr.gif'
-- local url = 'https://i.imgur.com/HCZRGQn.png'
-- local url = 'https://i.waifu.pics/anKsYF2.png'
-- local url = 'https://i.waifu.pics/oRYkwh4.png'
-- local url = 'https://imgs.xkcd.com/comics/types_2x.png'

gpu.set(1, 1, url)
require 'term'.setCursor(1, 2)

-- Checking that given image type can be processed

local ext = url:sub(-3):lower()

local handler = ({['bmp'] = bmp24, ['png'] = png, ['jpg'] = jpg,
                  ['gif'] = gif,   ['peg'] = jpg})[ext]
assert(handler, 'No handler found for this image type')

-- Downloading image

local headers = {['Content-Length'] = {'0', n=1}}
local _

-- [[
local img = int.request(url, nil, {
  ['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:94.0) Gecko/20100101 Firefox/94.0'
})
while true do
  local success, reason = img.finishConnect()
  if success then break end
  assert(not reason, reason)
end

_, _, headers = img.response()
-- ]]

local result, reason = xpcall(function()
  local window = {x = 1, y = 4, w = 160}
  window.h = 51 - window.y
  
  local get_pixel, w, h = handler(img and seekable(exact_readable(img)),
                                  tonumber(headers['Content-Length'][1]),
                                  window)
  if get_pixel and w and h then
    os.sleep(0.05)
    draw(get_pixel, {w = w, h = h}, window)
  end
end, debug.traceback)
mark_stage(nil)

if not result then
  io.stderr:write(reason)
  io.stderr:write '\n'
end
