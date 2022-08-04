local com = require 'component'
local unc = require 'unicode'
local evt = require 'event'

local opb = com.openperipheral_bridge

-- 480x270(?) - auto interface
-- 960x480 - large interface

local CHEST_SIDES = {[require 'sides'.top] = true, [require 'sides'.north] = true}
local DROP_SIDE = require 'sides'.east
local TRUST_PLAYERS = {['ProgramCrafter'] = true}

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
      :gsub('Both ', unc.char(0x2195))
      :gsub('Down ', unc.char(0x2193))
      :gsub('Up ',   unc.char(0x2191))
      :gsub('None',  '--')
  local humid = active_tolerance(bee_info.active.humidityTolerance,
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
  for side in pairs(sides) do
    for slot, slot_info in pairs(trn.getAllStacks(side).getAll()) do
      local info = {analyze(slot_info)}
      if info[1] then
        info[15] = {side, slot + 1}
        
        local tier1, tier2 = bees_tier[bee[2]] or 0, bees_tier[bee[3]] or 0
        if tier1 < tier2 then tier1, tier2 = tier2, tier1 end
        local tier_key = tostring(tier1) .. '+' .. tostring(tier2)
        bees_by_tier[tier_key] = bees_by_tier[tier_key] or {}; table.insert(bees_by_tier[tier_key], info)
      end
    end
  end
  
  local function compare(t1, t2)
    for i = 1, #t1 do
      if t1[i] < t2[i] then return true elseif t2[i] < t1[i] then return false end
    end return false
  end
  local function bee_comparator(bee1, bee2)
    return compare( -- reverse order
      {bee2[14],math.max(bee2[4],bee2[5]),math.max(bee2[6],bee2[7])},
      {bee1[14],math.max(bee1[4],bee1[5]),math.max(bee1[6],bee1[7])})
  end
  
  local full_bees = {}
  for tier, bees in pairs(bees_by_tier) do
    table.sort(bees, bees_comparator)
    for i = 1, 4 do
      if bees[i] then full_bees[#full_bees + 1] = bees[i] end
    end
  end
  
  os.sleep(0)
  return full_bees
end

local ui = {}

ui.title_back = opb.addBox(0, 0, 480, 12, 0xFFFFAA)
ui.icon = opb.addIcon(1, 0, 'Forestry:beeDroneGE')
ui.title = opb.addText(16, 1, 'Beealyzer v1.OP', 0)
ui.credits_back = opb.addBox(76, 0, 109, 12, 0xFFDDAA)
ui.credits = opb.addText(81, 1, 'created by ProgramCrafter', 0)
ui.ad = opb.addText(189, 1, '[AD] Do you want to beta-test remake of board game "Right Honey"? [/AD]', 0)
ui.icon.setScale(0.75)

ui.main_screen = opb.addBox(0, 12, 480, 258, 0x888888)

ui.bees = {}

for x = 2, 480, 120 do
  for i = 1, 20 do
    local y = 2 + i * 12
    ui.bees[i] = {}
    ui.bees[i].icon = opb.addIcon(x, y, 'Forestry:beePrincessGE')
    ui.bees[i].icon.setScale(0.75)
    ui.bees[i].icon.setLabel(tostring(math.floor(x / 6 + i)))
    ui.bees[i].label = opb.addText(x + 14, y + 4, 'Fores/Modest')
    ui.bees[i].label.setScale(0.75)
    ui.bees[i].lifespan = opb.addText(x + 52, y + 2, '30-35')
    ui.bees[i].lifespan.setScale(0.6)
    ui.bees[i].speed = opb.addText(x + 52, y + 8, '0.3-1.2')
    ui.bees[i].speed.setScale(0.6)
    ui.bees[i].temp = opb.addText(x + 68, y + 4, 'T' .. unc.char(0x2195) .. '1', 0xFFFFAA)
    ui.bees[i].temp.setScale(0.75)
    ui.bees[i].humid = opb.addText(x + 78, y + 4, 'H' .. unc.char(0x2193) .. '2', 0xAAAAFF)
    ui.bees[i].humid.setScale(0.75)
    ui.bees[i].flags = opb.addText(x + 94, y + 4, 'N CE')
    ui.bees[i].flags.setScale(0.75)
  end
end

opb.sync()
opb.clear()

evt.pull 'glasses_capture'
opb.getCaptureControl(opb.getUsers()[1].uuid).setBackground(0x000000, 0)
opb.getCaptureControl(opb.getUsers()[1].uuid).toggleGuiElements
  {OVERLAY = true, PORTAL = false, HOTBAR = false, CROSSHAIRS = false, BOSS_HEALTH = false,
   HEALTH = false, ARMOR = false, FOOD = false, MOUNT_HEALTH = false, AIR = false,
   EXPERIENCE = false, JUMP_BAR = false, OBJECTIVES = false}

evt.pull 'glasses_release'
opb.sync()
