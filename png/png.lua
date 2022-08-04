-- Program parsing and showing PNG images.
-- (c) ProgramCrafter, 2022

-- Repositories:
--   https://github.com/ProgramCrafter/lua-utils/
--   https://gitlab.com/ProgramCrafter/lua-utils/

-- TODO:
-- [ ] implement dynamic Huffman decoding
-- [ ] remove log prints (and function msbtolsbfirst)
-- [ ] test the program on big images
-- [ ] implement downscaling
-- [ ] implement dithering
-- [ ] make this a library

local com = require 'component'
local unc = require 'unicode'
local gpu = com.gpu

local function tobits(data)
  local i = 7
  local function readbit()
    i = i + 1
    return (data:byte(i // 8, i // 8) >> (i % 8)) & 1
  end
  local function readn(n)
    local v = 0
    for i = 1,n do
      v = v * 2 + readbit()
    end
    return v
  end
  local function rvreadn(n)
    local v = 0
    for i = 1,n do
      v = v + (readbit() << (i - 1))
    end
    return v
  end
  return {
    read = readbit,
    readn = readn,
    rvreadn = rvreadn
  }
end

local function msbtolsbfirst(v)
  return (((v >> 7) & 1) << 0) + (((v >> 6) & 1) << 1) +
         (((v >> 5) & 1) << 2) + (((v >> 4) & 1) << 3) +
         (((v >> 3) & 1) << 4) + (((v >> 2) & 1) << 5) +
         (((v >> 1) & 1) << 6) + (((v >> 0) & 1) << 7)
end
local function swapbits7(v)
  return (v & 15) + (v & 1) * 63 + (v & 2) * 15 + (v & 4) * 3
                  + (v &16) // 4 + (v &32) //16 + (v &64) //64
end
local function swapbits2(v)
  if v == 1 then return 2 end
  if v == 2 then return 1 end
  return v
end

local function inflate(data)
  local swap_on_log = true
  local swap_bits = swap_on_log and msbtolsbfirst or function(v) return v end
  
  if #data < 48 then
    for i = 1, #data do
      local b = swap_bits(data:byte(i))
      if i <= 2 then io.write'\27[32m' end
      io.write((b >> 7) & 1, (b >> 6) & 1, (b >> 5) & 1, (b >> 4) & 1,
               (b >> 3) & 1, (b >> 2) & 1, (b >> 1) & 1, (b >> 0) & 1,
               '(', string.format('%02X', swap_bits(b)), ') ')
      if i <= 2 then io.write'\27[37m' end
    end
  end
  -- print()
  
  local cmf, flg, dictid = string.unpack('>I1I1I4', data)
  
  if cmf & 15 ~= 8 then
    io.stderr:write('* invalid compression method\n')
    return false
  end
  
  if flg & 32 ~= 0 then
    print('  dictionary present')
    data = data:sub(7)
  else
    -- print('  dictionary not present')
    data = data:sub(3)
  end
  
  -- io.write('  CMF: ', cmf, ', window size: ', cmf >> 4, ', algo: ', cmf & 15, '\n')
  -- io.write('  FLG: ', flg, ', compr level: ', flg >> 6, ', dict: ', (flg >> 5) & 1, '\n')
  io.write('  header sum: ', cmf * 256 + flg, ', ok: ', tostring((cmf * 256 + flg) % 31 == 0), '\n')
  print()
  
  local bitdata = tobits(data)
  local function read_fixed_huffman_code()
    local prefix, v
    prefix = bitdata.readn(7)
    
    if prefix <= 23 then
      v = prefix - 0 + 256
    elseif prefix <= 95 then
      prefix = prefix * 2 + bitdata.read()
      v = prefix - 48 + 0
    elseif prefix <= 99 then
      prefix = prefix * 2 + bitdata.read()
      v = prefix - 192 + 280
    else
      prefix = prefix * 4 + bitdata.readn(2)
      v = prefix - 400 + 144
    end
    
    return v
  end
  
  local output = {}
  while true do
    local bfinal, btype = bitdata.read(), bitdata.rvreadn(2)
    
    if bfinal == 1 then
      io.write('  (final)')
    end
    
    if btype == 0 then
      print('  [chunk | no compression ' .. bfinal .. '00]')
      
      bitdata.readn(5)
      
      local len_uncompressed, ocl_uncompressed = bitdata.rvreadn(16), bitdata.rvreadn(16)
      
      if len_uncompressed + ocl_uncompressed ~= 65535 then
        io.stderr:write('    len of chunk not one\'s complement with nlen\n')
        return false
      end
      
      print('    ' .. len_uncompressed .. ' raw bytes')
      for i = 1, len_uncompressed do
        output[#output + 1] = bitdata.rvreadn(8)
      end
    elseif btype == 1 then
      print('  [chunk | fixed Huffman codes ' .. bfinal .. '01]')
      while true do
        local v = read_fixed_huffman_code()
        if v == 256 then
          print('    end of block: ' .. v)
          break
        end
        
        if v < 256 then
          print('    literal ' .. v)
          
          output[#output + 1] = v
        else
          if #output == 0 then
            io.stderr:write('    repeat token ', v, ' with empty output\n')
            return false
          end
          
          local length = -1
          if v <= 264 then     length = v      - 254
          elseif v <= 268 then length = v * 2  + bitdata.read()     - 519
          elseif v <= 272 then length = v * 4  + bitdata.rvreadn(2) - 1057
          elseif v <= 276 then length = v * 8  + bitdata.rvreadn(3) - 2149
          elseif v <= 280 then length = v * 16 + bitdata.rvreadn(4) - 4365
          elseif v <= 284 then length = v * 32 + bitdata.rvreadn(5) - 8861
          else                 length = v - 27
          end
          
          local v, offset = bitdata.readn(5), -2
          if v <= 3 then      offset = v        + 1
          elseif v <= 5 then  offset = v * 2    + bitdata.read()      - 3
          elseif v <= 7 then  offset = v * 4    + bitdata.rvreadn(2)  - 15
          elseif v <= 9 then  offset = v * 8    + bitdata.rvreadn(3)  - 47
          elseif v <= 11 then offset = v * 16   + bitdata.rvreadn(4)  - 127
          elseif v <= 13 then offset = v * 32   + bitdata.rvreadn(5)  - 319
          elseif v <= 15 then offset = v * 64   + bitdata.rvreadn(6)  - 767
          elseif v <= 17 then offset = v * 128  + bitdata.rvreadn(7)  - 1791
          elseif v <= 19 then offset = v * 256  + bitdata.rvreadn(8)  - 4095
          elseif v <= 21 then offset = v * 512  + bitdata.rvreadn(9)  - 9215
          elseif v <= 23 then offset = v * 1024 + bitdata.rvreadn(10) - 20479
          elseif v <= 25 then offset = v * 2048 + bitdata.rvreadn(11) - 45055
          elseif v <= 27 then offset = v * 4096 + bitdata.rvreadn(12) - 98303
          elseif v <= 29 then offset = v * 8192 + bitdata.rvreadn(13) - 212991
          end
          
          io.write('    [repeat len=', length, ' off=', offset, ' rawoff=', v, ']\n')
          
          local wpos = #output
          local rpos = wpos - offset
          for i = 1, length do
            output[wpos + i] = output[rpos + i]
          end
        end
      end
    elseif btype == 2 then
      print('  [chunk | dynamic Huffman codes ' .. bfinal .. '10]')
      io.stderr:write('    dynamic codes not supported\n')
      
      return false
    else
      io.stderr:write('  [invalid chunk | ' .. bfinal .. '11]\n')
      return false
    end
    
    if bfinal == 1 then
      return true, output
    end
  end
end

local function parse_chunk(handle, image_info)
  local chunk_len = string.unpack('>i4', handle:read(4))
  local chunk_typ = handle:read(4)
  local chunk_dat = handle:read(chunk_len)
  local chunk_crc = handle:read(4)
  
  if chunk_typ == 'IDAT' then print('\nChunk', chunk_typ, chunk_len) end
  
  local critical = chunk_typ:sub(1, 1) == chunk_typ:sub(1, 1):upper()
  -- local public   = chunk_typ:sub(2, 2) == chunk_typ:sub(2, 2):upper()
  local version  = chunk_typ:sub(3, 3) == chunk_typ:sub(3, 3):upper()
  -- local copiable = chunk_typ:sub(4, 4) == chunk_typ:sub(4, 4):upper()
  
  if not version then  return not critical, chunk_typ  end
  
  if chunk_typ:lower() == 'ihdr' then
    image_info.width, image_info.height, image_info.bit_depth, image_info.color_type,
      image_info.compression, image_info.filter, image_info.interlace =
        string.unpack('>I4I4I1I1I1I1I1', chunk_dat)
    
    io.write('  image width: ', image_info.width, ', height: ', image_info.height, '\n')
    io.write('  bit depth: ', image_info.bit_depth, ', color: ', image_info.color_type, '\n')
    
    if image_info.compression ~= 0 or image_info.filter ~= 0 then
      io.stderr:write('* Invalid compression or filter value\n')
      return false, chunk_typ
    end
    if image_info.interlace ~= 0 then
      io.stderr:write('* Interlace not yet supported\n')
      return false, chunk_typ
    end
    -- print('  no interlace, compression = deflate')
    
    return true, chunk_typ
  end
  
  if chunk_typ:lower() == 'idat' then
    print('\nInflating...')
    local success, result = inflate(chunk_dat)
    print('\nInflation result:', success, require'serialization'.serialize(result))
    
    image_info.main_data = result
    return success, chunk_typ
  end
  
  return not critical, chunk_typ
end

local function draw_image(bx, by, image_info)
  gpu.setBackground(0x000000)
  gpu.fill(bx, by, 78, 25, ' ')
  
  local bpp = (image_info.color_type & 4) > 0 and 4 or 3
  
  for x = 1, image_info.width do
    for hy = 1, (image_info.height + 1) // 2 do -- half-Y
      local top_r = image_info.main_data[(hy * 2 - 2) * (image_info.width * bpp + 1) + x * bpp - 1]
      local top_g = image_info.main_data[(hy * 2 - 2) * (image_info.width * bpp + 1) + x * bpp]
      local top_b = image_info.main_data[(hy * 2 - 2) * (image_info.width * bpp + 1) + x * bpp + 1]
      local top = top_r * 65536 + top_g * 256 + top_b
      
      local bot_r = image_info.main_data[(hy * 2 - 1) * (image_info.width * bpp + 1) + x * bpp - 1]
      local bot_g = image_info.main_data[(hy * 2 - 1) * (image_info.width * bpp + 1) + x * bpp]
      local bot_b = image_info.main_data[(hy * 2 - 1) * (image_info.width * bpp + 1) + x * bpp + 1]
      local bot = bot_b and (bot_r * 65536 + bot_g * 256 + bot_b) or 0
      
      gpu.setBackground(top)
      gpu.setForeground(bot)
      gpu.set(bx + x - 1, by + hy - 1, unc.char(0x2584))
    end
  end
  
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
end

local function parse_png(handle)
  local signature = handle:read(8)
  if signature ~= string.char(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A) then
    io.stderr:write('Incorrect signature\n')
    for i = 1,8 do
      io.write(string.format('0x%02X ', signature:byte(i)))
    end
    io.write('\n')
    return
  end
  
  local image_info = {}
  
  while true do
    local parsed, chunk_type = parse_chunk(handle, image_info)
    
    if chunk_type == 'IDAT' then
      draw_image(3, 5, image_info)
    end
    
    if not parsed or chunk_type == 'IEND' then break end
    
    os.sleep(0)
  end
end

-- [[
local result, out = inflate 'x\x01\x01\x03\x00\xfc\xff\x00\xff\x10\x02\x11\x01\x10'
print(require'serialization'.serialize(out))
print()
print('\27[36m' .. ('='):rep(77) .. '\27[37m')

local result, out = inflate 'x\x9cc\xf8/\x00\x00\x02\x11\x01\x10'
print(require'serialization'.serialize(out))
print()
print('\27[36m' .. ('='):rep(77) .. '\27[37m')

local result, out = inflate 'x^c`\x80\x00\x00\x00\x08\x00\x01'
print(require'serialization'.serialize(out))
print()
print('\27[36m' .. ('='):rep(77) .. '\27[37m')
--]]

for fn in pairs({['test-decode-v2'] = true}) do
  io.write(fn .. '.png')
  
  local f = io.open(fn .. '.png', 'rb')
  parse_png(f)
  f:close()
  
  print('\27[36m' .. ('='):rep(77) .. '\27[37m')
end
