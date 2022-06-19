local com = require 'component'
local unc = require 'unicode'
local evt = require 'event'

local opb = com.openperipheral_bridge

-- 480x270(?) - auto interface
-- 960x480 - large interface

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
opb.getCaptureControl(opb.getUsers()[1].uuid).toggleGuiElements
  {OVERLAY = true, PORTAL = false, HOTBAR = false, CROSSHAIRS = false, BOSS_HEALTH = false,
   HEALTH = false, ARMOR = false, FOOD = false, MOUNT_HEALTH = false, AIR = false,
   EXPERIENCE = false, JUMP_BAR = false, OBJECTIVES = false}

evt.pull 'glasses_release'
opb.sync()
