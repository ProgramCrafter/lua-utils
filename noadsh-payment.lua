local com = require 'component'
local sid = require 'sides'

local red = com.redstone
local sen = com.openperipheral_sensor

red.setOutput(sid.top, 15)

local abs = math.abs
local EPS = 0.000001

local players_in_zone = {}

while true do
  players_in_zone = {}
  
  local players = sen.getPlayers()
  for i = 1, #players do
    local ok, info = pcall(function()
      return sen.getPlayerByName(players[i].name).basic()
    end)
    local pos = ok and info.position or {x = -10, y = -10, z = -10}
    
    if abs(pos.y + 1) < EPS and abs(pos.x) + abs(pos.z) <= 4 then
      table.insert(players_in_zone, players[i].name)
    end
  end
  
  if #players_in_zone == 1 then
    break
  end
  
  os.sleep(0.05)
end

red.setOutput(sid.top, 0)

print('Locked: ' .. players_in_zone[1])
