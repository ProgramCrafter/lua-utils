local com = require 'component'
local sid = require 'sides'

local red = com.redstone
local sen = com.openperipheral_sensor

local con_trn = com.proxy '45c65c9f-a1b3-444b-b1e3-2b9e2bb473d9'

local left = sid.east
local right = sid.west

local left_cost = 0
local right_cost = 0

local prices = {
  ['item.netherquartz@0']     = 16,
  ['tile.stone@0']            = 1,
  ['tile.stonebricksmooth@0'] = 1,
  ['tile.stonebrick@0']       = 1,  -- cobblestone
  ['tile.sand@0']             = 2,
  ['tile.wood@0']             = 2,
  ['tile.obsidian@0']         = 18,
  ['tile.blockIron@0']        = 18,
  ['tile.blockGold@0']        = 54,
  ['tile.blockLapis@0']       = 27,
  ['tile.blockDiamond@0']     = 108,
  ['tile.blockEmerald@0']     = 108,
  ['item.itemPowderIngot@8']  = 2
}

local function collapse(t)
  local ct = {}
  for _, v in pairs(t) do
    ct[#ct + 1] = v
  end
  return ct
end

local function equal(--[[const]] t1, t2)
  if type(t1) ~= type(t2) then return false end
  t2.n = nil
  
  for k, v in pairs(t1) do
    if t2[k] ~= v then return false end
    t2[k] = nil
  end
  for k in pairs(t2) do return false end
  return true
end

--------------------------

local abs = math.abs
local EPS = 0.000001

while true do
  red.setOutput(sid.top, 15)
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
  
  com.modem.broadcast(877, players_in_zone[1])
  
  left_cost = 0
  right_cost = 0
  local left_items = {}
  
  while true do
    os.sleep(0.05)
    
    -- [[volatile]] player is expected to put his cell inside left ME drive
    local left_cells = con_trn.getAllStacks(left).getAll()
    
    if left_cells[0] and left_cells[0].getAvailableItems then
      left_items = left_cells[0].getAvailableItems
      left_items.n = nil
      break
    end
  end
  
  local right_cell = con_trn.getStackInSlot(sides.down, 1)
  local right_items = right_cell.getAvailableItems
  right_items.n = nil
  
  con_trn.transferItem(sides.down, right, 1, 1)
  
  for _, slot_info in pairs(left_items) do
    local count = slot_info:sub(1, slot_info:find('x') - 1)
    local id = slot_info:sub(slot_info:find('x') + 1)
    
    left_cost = left_cost + (prices[id] or 0) * count
  end
  
  for _, slot_info in pairs(right_items) do
    local count = slot_info:sub(1, slot_info:find('x') - 1)
    local id = slot_info:sub(slot_info:find('x') + 1)
    
    right_cost = right_cost + (prices[id] or 0) * count
  end
  
  print('Trading ' .. tostring(math.floor(left_cost)) ..
    'FCM against ' .. tostring(math.floor(right_cost)) .. 'FCM')
  
  if left_cost ~= right_cost then
    print('Trade cannot be made due to inequal costs.')
    con_trn.transferItem(right, sides.down, 1, 1)
    goto trade_fin
  end
  
  while true do
    local trade_left_cell = con_trn.getStackInSlot(left, 1)
    if not trade_left_cell or not equal(left_items, trade_left_cell.getAvailableItems) then
      print('Trade cancelled by user')
      con_trn.transferItem(right, sides.down, 1, 1)
      break
    end
    
    local trade_right_cell = con_trn.getStackInSlot(right, 1)
    if not trade_right_cell or not equal(right_items, trade_right_cell.getAvailableItems) then
      print('Trade successful')
      con_trn.transferItem(left, sides.down, 1, 1)
      break
    end
  end
  
  ::trade_fin::
  
  com.modem.broadcast(877, players_in_zone[1] .. '\0finished')
  
  red.setOutput(sid.top, 15)
  
  os.sleep(20) -- to let player go out of room
end
