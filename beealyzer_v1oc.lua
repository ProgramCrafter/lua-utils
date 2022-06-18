-- Program showing information about bees in chest.
-- (c) ProgramCrafter, 2022

local com = require 'component'
local unc = require 'unicode'
local evt = require 'event'
local sid = require 'sides'
local trn = com.transposer
local gpu = com.gpu

local function active_tolerance(tol1, tol2)
  if tol1 == 'Both 1' or tol1 == 'Down 1' or tol1 == 'Up 1' then return tol1 end
  if tol2 == 'Both 1' or tol2 == 'Down 1' or tol2 == 'Up 1' then return tol2 end
  return tol1
end

local function analyze(side, slot)
  local slot_info = trn.getStackInSlot(side, slot)
  if not slot_info then
    return false, 'empty slot'
  end
  if not slot_info.individual then
    return false, 'not a bee'
  end
  
  local bee_type = slot_info.label:gmatch('Princess')() or 'Drone'
  local bee_info = slot_info.individual
  
  if not bee_info.isAnalyzed then
    return false, 'not analyzed'
  end
  
  local spec1 = bee_info.active.species
  local spec2 = bee_info.inactive.species
  local lifespan1 = math.floor(bee_info.active.lifespan)
  local lifespan2 = math.floor(bee_info.inactive.lifespan)
  local speed1 = math.floor(10 * bee_info.active.speed + 0.1) / 10
  local speed2 = math.floor(10 * bee_info.inactive.speed + 0.1) / 10
  
  if lifespan1 > lifespan2 then
    lifespan1, lifespan2 = lifespan2, lifespan1
  end
  if speed1 > speed2 then
    speed1, speed2 = speed2, speed1
  end
  
  local temp = active_tolerance(
    bee_info.active.temperatureTolerance,
    bee_info.inactive.temperatureTolerance)
      :gsub('Both ', unc.char(0x2195))
      :gsub('Down ', unc.char(0x2193))
      :gsub('Up ',   unc.char(0x2191))
      :gsub('None',  '--')
  local humid = active_tolerance(
    bee_info.active.humidityTolerance,
    bee_info.inactive.humidityTolerance)
      :gsub('Both ', unc.char(0x2195))
      :gsub('Down ', unc.char(0x2193))
      :gsub('Up ',   unc.char(0x2191))
      :gsub('None',  '--')
  
  local night_active = bee_info.active.nocturnal
  local rain_active = bee_info.active.tolerantFlyer
  local cave_active = bee_info.active.caveDwelling
  
  local effects = bee_info.active.effect ~= 'None'
  
  return true,
         spec1, spec2, lifespan1, lifespan2, speed1, speed2, temp, humid,
         night_active, rain_active, cave_active, effects, bee_type
end

local bees_tier = {
  ['Forest']     = 1.1,  ['Meadows']   = 1.2, ['Modest']  = 1.3, ['Tropical']  = 1.4,
  ['Common']     = 2.1,
  ['Cultivated'] = 3.1,
  ['Diligent']   = 4.1,  ['Noble']     = 4.2,
  ['Unweary']    = 5.1,  ['Majestic']  = 5.2
}

local function analyze_all_bees(side)
  local bees = {}
  for slot = 1, trn.getInventorySize(side) do
    local info = {analyze(side, slot)}
    if info[1] then info[15] = slot bees[#bees + 1] = info end
  end
  
  local function compare(t1, t2)
    for i = 1, #t1 do
      if t1[i] < t2[i] then return true elseif t2[i] < t1[i] then return false end
    end return false
  end
  local function bee_comparator(bee1, bee2)
    local tier11, tier12 = bees_tier[bee1[2]] or 0, bees_tier[bee1[3]] or 0
    if tier11 < tier12 then tier11, tier12 = tier12, tier11 end
    local tier21, tier22 = bees_tier[bee2[2]] or 0, bees_tier[bee2[3]] or 0
    if tier21 < tier22 then tier21, tier22 = tier22, tier21 end
    return compare( -- reverse order
      {tier21,tier22,bee2[14],math.max(bee2[4],bee2[5]),math.max(bee2[6],bee2[7])},
      {tier11,tier12,bee1[14],math.max(bee1[4],bee1[5]),math.max(bee1[6],bee1[7])})
  end
  
  table.sort(bees, bee_comparator)
  
  return bees
end

local tier3 = false
local function test(side, slot)
  local test_stack, reason = trn.getStackInSlot(sid.top, 1)
  if not test_stack and reason == 'no inventory' then
    error 'Add 7e506b5d-2ccb-4ac4-a249-5624925b0c67 to region members'
  end
  
  local color_depth = gpu.getDepth()
  if color_depth == 1 then
    error 'This program cannot be run on tier1 terminal'
  end
  tier3 = color_depth == 8
end

test(sid.top, 1)

gpu.setBackground(0xCCCCCC)
gpu.setForeground(0x000000)

if tier3 then
  gpu.set(1, 1, ('|  Вид         Срок Скорость Т  В Флаги '):rep(4))
  gpu.set(1, 26, ('|  Вид         Срок Скорость Т  В Флаги '):rep(4))
else
  gpu.set(1, 1, ('|  Вид         Срок Скорость Т  В Флаги '):rep(2))
end

--[[
|  Вид         Срок Скорость Т  В Флаги 
  Fores/Modest 20-30 0.3-0.6 |1 |1 ----
]]

local colours = {
  ['Cultivated'] = 0x333399,
  ['Common']     = 0x333333,
  ['Meadows']    = 0xFF3333,  ['Modest']     = 0x663300, ['Forest']     = 0x336699,
  ['Diligent']   = 0x9933CC,
  ['Unweary']    = 0x336600
}

local slot_associations = {}
local function draw_table()  -- no need to draw header, as it's not updated
  if tier3 then
    gpu.setBackground(0xFFFFAA)
    gpu.fill(1, 27, 40, 24, ' ')
    gpu.fill(81, 27, 40, 24, ' ')
    gpu.fill(41, 2, 40, 24, ' ')
    gpu.fill(121, 2, 40, 24, ' ')
    gpu.setBackground(0xFFDDAA)
    gpu.fill(1, 2, 40, 24, ' ')
    gpu.fill(81, 2, 40, 24, ' ')
    gpu.fill(41, 27, 40, 24, ' ')
    gpu.fill(121, 27, 40, 24, ' ')
  else
    gpu.setBackground(0xFFFF33)
    gpu.fill(41, 2, 40, 24, ' ')
    gpu.setBackground(0xFFCC33)
    gpu.fill(1, 2, 40, 24, ' ')
  end
  gpu.setForeground(0x000000)
  
  local x, y, z = 1, 2, 0
  for _, bee_data in ipairs(analyze_all_bees(sid.top)) do
    if bee_data[1] then
      if colours[bee_data[2]] then
        gpu.setForeground(colours[bee_data[2]])
      end
      
      local chr = bee_data[14] == 'Princess' and 0x2606 or 0x2605
      gpu.set(x + 0, y + z, unc.char(chr) .. bee_data[2]:sub(1, 6))
      
      if bee_data[3] ~= bee_data[2] then
        if colours[bee_data[3]] then
          gpu.setForeground(colours[bee_data[3]])
        end
        gpu.set(x + 7, y + z, '/' .. bee_data[3]:sub(1, 6))
      end
      gpu.setForeground(0x000000)
      
      gpu.set(x + 15, y + z, tostring(bee_data[4]) .. '-' .. tostring(bee_data[5]))
      gpu.set(x + 21, y + z, tostring(bee_data[6]) .. '-' .. tostring(bee_data[7]))
      gpu.set(x + 29, y + z, bee_data[8] .. ' ' .. bee_data[9])
      gpu.set(x + 35, y + z,
        (bee_data[10] and 'N' or ' ') ..
        (bee_data[11] and 'R' or ' ') ..
        (bee_data[12] and 'C' or ' ') ..
        (bee_data[13] and 'E' or ' '))
      
      slot_associations[tostring(x) .. ' ' .. tostring(y) .. ' ' .. tostring(z)] = bee_data[15]
      
      y = y + 1
      if y > 25 then
        x = x + 40        y = 2
        
        if x > 160 then
          x = 1           z = z + 25
        end
        
        if (x // 40 + z // 25) % 2 == 0 then
          gpu.setBackground(tier3 and 0xFFDDAA or 0xFFCC33)
        else
          gpu.setBackground(tier3 and 0xFFFFAA or 0xFFFF33)
        end
      end
    end
  end
  
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
end

draw_table()

while true do
  local _, _, x, y, btn, user = evt.pull 'touch'
  if user == 'ProgramCrafter' then
    x = x // 1
    y = y // 1
    if y == 1 or y == 26 then
      -- exitting
      break
    elseif btn == 0 then
      -- giving a bee away
      x = math.floor((x - 1) / 40) * 40 + 1 -- transforming X to 1/41
      
      local z = 0
      if y > 25 then
        y = y - 25
        z = 25
      end
      
      local key = tostring(x) .. ' ' .. tostring(math.floor(y)) .. ' ' .. tostring(z)
      local slot = slot_associations[key]
      
      if slot then
        trn.transferItem(sid.top, sid.east, 1, slot, 1)
        slot_associations[key] = nil
        draw_table()
      end
    elseif btn == 1 then
      -- updating list
      slot_associations = {}
      draw_table()
    end
  end
end

os.execute 'cls'
