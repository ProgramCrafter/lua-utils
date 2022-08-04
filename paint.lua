-- Program for editing small icons containing Unicode characters.
-- Supports all Unicode (to enter some character, select it on the right side with keyboard arrows and enter the new code),
--          characters colouring (LMB on some screen pixel to copy its foreground color, RMB to copy background)
--          and saving the result (take a look at paint.dat after closing this program).
-- (c) ProgramCrafter, 2022

-- Repositories:
--   https://github.com/ProgramCrafter/lua-utils/
--   https://gitlab.com/ProgramCrafter/lua-utils/

-- TODO:
-- [ ] increase edit field size from 8x4
-- [ ] allow characters to be pasted from clipboard into icon

local ser = require 'serialization'
local com = require 'component'
local unc = require 'unicode'
local evt = require 'event'

require'term'.setCursor(1, 25)

local gpu = com.gpu
gpu.setResolution(71, 50)

local data = {
  {0x2588, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20},
  {0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20},
  {0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20},
  {0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x2588}
}
local overlay = {}

local f = io.open('paint.dat')
if f then
  local env = {}
  pcall(load(f:read('*a'), '=paint', 't', env))
  data = env.data or data
  overlay = env.overlay or overlay
  f:close()
end

local function hex(row)
  local conv = {}
  for i = 1, #row do
    conv[i] = string.format('0x%04X', row[i])
  end
  return conv
end
local function tostr(row)
  local s = {}
  local i = 1
  while i <= #row do
    s[#s + 1] = unc.char(row[i])
    i = i + math.max(1, unc.wlen(unc.char(row[i])))
  end
  return table.concat(s, '')
end

local h = 0x2550
local v = 0x2551

local sel = {1, 1, hex(data[1])[1]}

gpu.fill(1, 1, 71, 50, ' ')

local gt = {0x00, 0x24, 0x49, 0x6D, 0x92, 0xB6, 0xDB, 0xFF}
for g = 0, 7 do
  for r = 0, 5 do
    for b = 0, 4 do
      gpu.setBackground(r * 0x330000 + gt[g + 1] * 0x100 + math.min(0xFF, b * 0x40))
      gpu.set(4 + r * 10 + b * 2, 10 + g, '  ')
    end
  end
  
  gpu.setBackground(g * 0x1E1E1E + 0x0F0F0F)
  gpu.set(64, 10 + g, '  ')
  gpu.setBackground((g + 1) * 0x1E1E1E)
  gpu.set(66, 10 + g, '  ')
end
gpu.setBackground(0x000000)

local swaps = {[0x20] = 0x2588, [0x2588] = 0x20}

while true do
  gpu.fill(1, 1, 71, 9, ' ')
  
  gpu.set(1, 1, unc.char(0x2554,h,h,h,h,h,h,h,h,h,h,h,h,0x2557))
  gpu.set(1, 8, unc.char(0x255A,h,h,h,h,h,h,h,h,h,h,h,h,0x255D))
  gpu.set(1, 2, unc.char(v,v,v,v,v,v), true)
  gpu.set(14, 2, unc.char(v,v,v,v,v,v), true)
  
  gpu.set(4, 3, tostr(data[1]))
  gpu.set(4, 4, tostr(data[2]))
  gpu.set(4, 5, tostr(data[3]))
  gpu.set(4, 6, tostr(data[4]))
  
  local cf = 0xFFFFFF
  local cb = 0x000000
  for _,chr in pairs(overlay) do
    if cf ~= chr[1] then
      cf = chr[1]
      gpu.setForeground(cf)
    end
    if cb ~= chr[2] then
      cb = chr[2]
      gpu.setBackground(cb)
    end
    gpu.set(3 + chr[3], 2 + chr[4], unc.char(data[chr[4]][chr[3]]))
  end
  if cf ~= 0xFFFFFF then
    cf = 0xFFFFFF
    gpu.setForeground(cf)
  end
  if cb ~= 0x000000 then
    cb = 0x000000
    gpu.setBackground(cb)
  end
  
  gpu.set(16, 3, table.concat(hex(data[1]), ' '))
  gpu.set(16, 4, table.concat(hex(data[2]), ' '))
  gpu.set(16, 5, table.concat(hex(data[3]), ' '))
  gpu.set(16, 6, table.concat(hex(data[4]), ' '))
  
  gpu.setForeground(0x40A0FF)
  gpu.set(9 + sel[1] * 7, 2 + sel[2], sel[3] .. (' '):rep(7 - #sel[3]))
  gpu.setForeground(0xFFFFFF)
  
  local e = {evt.pull(0.05)}
  if e[1] == 'interrupted' then
    local f = io.open('paint.dat', 'w')
    f:write 'data = {\n  {'
    f:write(table.concat(hex(data[1]), ', '))
    f:write '},\n  {'
    f:write(table.concat(hex(data[2]), ', '))
    f:write '},\n  {'
    f:write(table.concat(hex(data[3]), ', '))
    f:write '},\n  {'
    f:write(table.concat(hex(data[4]), ', '))
    f:write '}\n}\noverlay = '
    f:write(ser.serialize(overlay))
    f:write '\n'
    f:close()
    
    break
  elseif e[1] == 'key_up' then
    if e[4] == 14 then                      --  Backspace
      if #sel[3] > 2 then
        sel[3] = sel[3]:sub(1, #sel[3] - 1)
      end
    elseif 97 <= e[3] and e[3] <= 102 or    --  a-f
           65 <= e[3] and e[3] <= 70 or     --  A-F
           e[3] == 120 or e[3] == 88 or     --  x,X
           48 <= e[3] and e[3] <= 57 then   --  0-9
      if #sel[3] < 6 then
        sel[3] = sel[3] .. string.char(e[3])
      end
    elseif e[4] == 208 then                 --  arrow down
      sel[2] = math.min(sel[2] + 1, 4)
      sel[3] = hex(data[sel[2]])[sel[1]]
    elseif e[4] == 203 then                 --  arrow left
      sel[1] = math.max(sel[1] - 1, 1)
      sel[3] = hex(data[sel[2]])[sel[1]]
    elseif e[4] == 200 then                 --  arrow up
      sel[2] = math.max(sel[2] - 1, 1)
      sel[3] = hex(data[sel[2]])[sel[1]]
    elseif e[4] == 205 then                 --  arrow right
      sel[1] = math.min(sel[1] + 1, 8)
      sel[3] = hex(data[sel[2]])[sel[1]]
    end
    
    data[sel[2]][sel[1]] = tonumber(sel[3]) or data[sel[2]][sel[1]]
  elseif e[1] == 'touch' then
    local x = math.floor(e[3])
    local y = math.floor(e[4])
    
    local _, _, col = gpu.get(x, y)
        
    local key = sel[1] .. ' ' .. sel[2]
    if not overlay[key] then
      overlay[key] = {0xFFFFFF, 0x000000, sel[1], sel[2]}
    end
    
    if e[5] == 0 then  --  left mouse button
      overlay[key][1] = math.floor(col)
    else
      overlay[key][2] = math.floor(col)
    end
    
    if overlay[key][1] == 0xFFFFFF and overlay[key][2] == 0 then
      overlay[key] = nil
    elseif overlay[key][1] == 0 and overlay[key][2] == 0xFFFFFF and
           swaps[data[sel[2]][sel[1]]] then
      overlay[key] = nil
      data[sel[2]][sel[1]] = swaps[data[sel[2]][sel[1]]]
    end
  end
end
