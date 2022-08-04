-- Program showing information about bees in chest.
-- (c) ProgramCrafter, 2022
local com = require 'component'
local unc = require 'unicode'
local evt = require 'event'
local trn = com.transposer
local gpu = com.gpu

local CHEST_SIDES = {[require 'sides'.top] = true, [require 'sides'.north] = true}
local DROP_SIDE = require 'sides'.east
local TRUST_PLAYERS = {['ProgramCrafter'] = true}
local SHOW_TOP_BEES = 15

local function active_tolerance(tol1, tol2)
  if tol1 == 'Both 1' or tol1 == 'Down 1' or tol1 == 'Up 1' then return tol1 end
  if tol2 == 'Both 1' or tol2 == 'Down 1' or tol2 == 'Up 1' then return tol2 end
  return tol1
end
local function analyze(slot_info)
  if not slot_info then            return false, 'empty slot'    end
  if not slot_info.individual then return false, 'not a bee'     end
  local bee_type = slot_info.label:gmatch('Princess')() or 'Drone'
  local bee_info = slot_info.individual
  if not bee_info.isAnalyzed then  return false, 'not analyzed'  end
  local spec1 = bee_info.active.species
  local spec2 = bee_info.inactive.species
  local lifespan1 = math.floor(bee_info.active.lifespan)
  local lifespan2 = math.floor(bee_info.inactive.lifespan)
  local speed1 = math.floor(10 * bee_info.active.speed + 0.1) / 10
  local speed2 = math.floor(10 * bee_info.inactive.speed + 0.1) / 10
  if lifespan1 > lifespan2 then  lifespan1, lifespan2 = lifespan2, lifespan1  end
  if speed1 > speed2 then        speed1, speed2 = speed2, speed1              end
  local temp = active_tolerance(bee_info.active.temperatureTolerance,
                                bee_info.inactive.temperatureTolerance)
      :gsub('Both ', unc.char(0x2195)):gsub('Down ', unc.char(0x2193))
      :gsub('Up ',   unc.char(0x2191)):gsub('None',  '--')
  local humid = active_tolerance(bee_info.active.humidityTolerance,
                                 bee_info.inactive.humidityTolerance)
      :gsub('Both ', unc.char(0x2195)):gsub('Down ', unc.char(0x2193))
      :gsub('Up ',   unc.char(0x2191)):gsub('None',  '--')
  local night_active = bee_info.active.nocturnal
  local rain_active = bee_info.active.tolerantFlyer
  local cave_active = bee_info.active.caveDwelling
  local effects = bee_info.active.effect ~= 'None'
  return true, spec1, spec2, lifespan1, lifespan2, speed1, speed2, temp, humid,
               night_active, rain_active, cave_active, effects, bee_type
end

local bees_tier = { --[[ignore-spacing-errors(reason="minimizing")]] --[[ignore-line-length(reason="minimizing")]]
 ['Forest']     =0.1,['Meadows'] =0.2,['Modest']    =0.3,['Tropical']=0.4,['Valiant'] =0.5,['Steadfast']=0.6,['Ended']=0.7,['Wintry']=0.8,['Marshy']=0.9,['Monastic']=0.0,
 ['Common']     =1.1,['Heroic']  =1.2,['Leporine']  =1.3,['Merry']   =1.4,['Tipsy']   =1.5,
 ['Cultivated'] =2.1,                               
 ['Diligent']   =3.1,['Noble']   =3.2,['Sinister']  =3.3,
 ['Unweary']    =4.1,['Majestic']=4.2,['Fiendish']  =4.3,['Frugal']  =4.4,['Rural']   =4.5,['Tricky']   =4.6,['Miry'] =4.7,
 ['Industrious']=5.1,['Imperial']=5.2,['Demonic']   =5.3,['Austere'] =5.4,['Farmerly']=5.5,['Boggy']    =5.6,
 ['Exotic']     =6.1,['Icy']     =6.2,['Vindictive']=6.3,['Agrarian']=6.4,['Secluded']=6.5,
 ['Edenic']     =7.1,['Glacial'] =7.2,['Vengeful']  =7.3,['Hermitic']=7.4,['Scummy']  =7.5,
 ['Spectral']   =8.1,['Avenging']=8.2,
 ['Phantasmal'] =9.1,
}

local function analyze_all_bees(sides)
  local bees_by_tier = {}
  for side in pairs(sides) do for slot, slot_info in pairs(trn.getAllStacks(side).getAll()) do
    local info = {analyze(slot_info)} if info[1] then
      local tier_key = math.max(bees_tier[info[2]],bees_tier[info[3]])
      info[15] = {side, slot + 1} bees_by_tier[tier_key] = bees_by_tier[tier_key] or {} table.insert(bees_by_tier[tier_key], info)
    end
  end end
  local function compare(t1, t2)
    for i = 1, #t1 do
      if t1[i] < t2[i] then return true elseif t2[i] < t1[i] then return false end
    end return false
  end
  local function bee_comparator(bee1, bee2)
    return compare({bee2[14],math.min(bees_tier[bee2[2]],bees_tier[bee2[3]]),math.max(bee2[4],bee2[5]),math.max(bee2[6],bee2[7])},
                   {bee1[14],math.min(bees_tier[bee1[2]],bees_tier[bee1[3]]),math.max(bee1[4],bee1[5]),math.max(bee1[6],bee1[7])})
  end
  
  local bees = {}
  for tier = 0, 91 do
    if bees_by_tier[tier / 10] then
      table.sort(bees_by_tier[tier / 10], bee_comparator)
      for i = 1, SHOW_TOP_BEES do
        if bees_by_tier[tier / 10][i] then bees[#bees + 1] = bees_by_tier[tier / 10][i] end
      end
      
      os.sleep(0)
    end
  end
  
  return bees
end

local tier3 = false
local function test(side, slot)
  local test_stack, reason = trn.getStackInSlot(side, 1)
  if not test_stack and reason == 'no inventory' then
    error 'Add 7e506b5d-2ccb-4ac4-a249-5624925b0c67 to region members'
  end
  
  local color_depth = gpu.getDepth()
  if color_depth == 1 then
    error 'This program cannot be run on tier1 terminal'
  end
  tier3 = color_depth == 8
end

test(next(CHEST_SIDES), 1)

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

local colours = { --[[ignore-spacing-errors(reason="minimizing")]] --[[ignore-line-length(reason="minimizing")]]
 ['Forest']     =0x336699,['Meadows'] =0xFF3333,['Modest']    =0x663300,['Tropical']=0x006600,['Valiant'] =0x333399,['Steadfast']=0x9933CC,['Ended']=0x9933CC,['Wintry']=0xCCCCEE,['Marshy']=0x006600,['Monastic']=0x333333,
 ['Common']     =0x333333,['Heroic']  =0xFF00FF,['Leporine']  =0xFF00FF,['Merry']   =0xFF00FF,['Tipsy']   =0xFF00FF,
 ['Cultivated'] =0x333399,                               
 ['Diligent']   =0x9933CC,['Noble']   =0x996633,['Sinister']  =0x333333,
 ['Unweary']    =0x336600,['Majestic']=0x660000,['Fiendish']  =0x333333,['Frugal']  =0xCCCCEE,['Rural']   =0x999933,['Tricky']   =0x9933CC,['Miry'] =0x336600,
 ['Industrious']=0xFF00FF,['Imperial']=0xFF00FF,['Demonic']   =0x333333,['Austere'] =0xFF00FF,['Farmerly']=0x996633,['Boggy']    =0x333333,
 ['Exotic']     =0x006600,['Icy']     =0xCCCCEE,['Vindictive']=0xCCCCEE,['Agrarian']=0xFF00FF,['Secluded']=0x333333,
 ['Edenic']     =0xFF00FF,['Glacial'] =0xFF00FF,['Vengeful']  =0x999933,['Hermitic']=0xFF00FF,['Scummy']  =0x333399,
 ['Spectral']   =0x9933CC,['Avenging']=0xFF00FF,
 ['Phantasmal'] =0xFF3333,
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
  for _, bee_data in ipairs(analyze_all_bees(CHEST_SIDES)) do
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
  if TRUST_PLAYERS[user] then
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
        trn.transferItem(slot[1], DROP_SIDE, 1, slot[2], 1)
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
