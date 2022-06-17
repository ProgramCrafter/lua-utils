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

local function test(side, slot)
  local test_stack, reason = trn.getStackInSlot(sid.top, 1)
  if not test_stack then
    if reason == 'no inventory' then
      error('Add 7e506b5d-2ccb-4ac4-a249-5624925b0c67 to region members')
    end
  end
end

test(sid.top, 1)

gpu.setBackground(8, true) -- light grey
gpu.setForeground(0x000000)
gpu.set(1, 1, ('|  Вид        Срок  Скорость Т  В Флаги '):rep(2))

--[[
| Вид         Срок  Скорость Т  В Флаги
Forest/Modest 20-30 0.3-0.6 |1 |1 ----
]]

local colours = {
  ['Cultivated'] = 11,
  ['Common']     = 7,
  ['Meadows']    = 14,
  ['Modest']     = 12,
  ['Forest']     = 9,
  ['Diligent']   = 10,
  ['Unweary']    = 13
}

local slot_associations = {}
local function draw_table()
  -- no need to draw header, as it's not updated
  
  gpu.setBackground(4, true) -- yellow
  gpu.setForeground(0x000000)
  gpu.fill(41, 2, 40, 24, ' ')
  
  gpu.setBackground(1, true) -- light orange
  gpu.fill(1, 2, 40, 24, ' ')
  
  local x, y = 1, 2
  for i = 1, 54 do
    local bee_data = {analyze(sid.top, i)}
    if bee_data[1] then
      if colours[bee_data[2]] then
        gpu.setForeground(colours[bee_data[2]], true)
      end
      
      local chr = bee_data[14] == 'Princess' and 0x2606 or 0x2605
      gpu.set(x + 0, y, unc.char(chr) .. bee_data[2]:sub(1, 6))
      
      if bee_data[3] ~= bee_data[2] then
        if colours[bee_data[3]] then
          gpu.setForeground(colours[bee_data[3]], true)
        end
        gpu.set(x + 7, y, '/' .. bee_data[3]:sub(1, 6))
      end
      
      gpu.setForeground(0x000000)
      
      gpu.set(x + 15, y, tostring(bee_data[4]) .. '-' .. tostring(bee_data[5]))
      gpu.set(x + 21, y, tostring(bee_data[6]) .. '-' .. tostring(bee_data[7]))
      gpu.set(x + 29, y, bee_data[8] .. ' ' .. bee_data[9])
      gpu.set(x + 35, y,
        (bee_data[10] and 'N' or ' ') ..
        (bee_data[11] and 'R' or ' ') ..
        (bee_data[12] and 'C' or ' ') ..
        (bee_data[13] and 'E' or ' '))
      
      slot_associations[tostring(x) .. ' ' .. tostring(y)] = i
      
      y = y + 1
      if y > 25 then
        x = x + 40
        y = 2
        
        gpu.setBackground(4, true)
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
    if y == 1 then
      -- exitting
      break
    elseif btn == 0 then
      -- giving a bee away
      x = math.floor((x - 1) / 40) * 40 + 1 -- transforming X to 1/41
      
      local slot = slot_associations[tostring(x) .. ' ' .. tostring(math.floor(y))]
      
      if slot then
        trn.transferItem(sid.top, sid.east, 1, slot, 1)
        slot_associations[tostring(x) .. ' ' .. tostring(math.floor(y))] = nil
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
