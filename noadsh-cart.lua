local com = require 'component'
local sid = require 'sides'
local evt = require 'event'

local scr = '9fb3d33a-60c5-4af3-9937-ca94467dcc0f'
local pscr = '466ec26a-8987-4e50-a310-2c705917f800'

local sell_mei = com.proxy '08adeb28-9d78-48e8-810b-bd792e347ff3'
local sell_sid = sid.down
local sell_con_sid = sid.south

local shop_mei = com.proxy 'b7727a24-f1be-441d-b07c-e173b40d507f'
local shop_sid = sid.east

local prices = {
  ['minecraft:quartz@0']      = 16,
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
  ['EnderIO:itemPowderIngot@8']  = 2
}

local function take_cell()
  com.transposer.transferItem(sid.top, sell_con_sid)
end

local function export_to_sell(id, dmg, amount)
  assert(amount <= 64)
  
  local fingerprint = {id = id, damage = dmg}
  amount = shop_mei.exportItem(fingerprint, 'SOUTH', amount, 1).size
  amount = com.transposer.transferItem(shop_sid, sell_sid, amount)
  return amount
end

local function finalize()
  com.transposer.transferItem(sell_con_sid, sid.top)
end

com.modem.open(877)

local gpu = com.gpu
gpu.bind(scr, false)
gpu.setResolution(80, 50)

while true do
  take_cell()
  
  gpu.fill(1, 1, 80, 50, ' ')
  
  local y = 41
  local items = {}
  for _, item in pairs(shop_mei.getItemsInNetwork()) do
    if _ ~= 'n' then
      print(require'serialization'.serialize(item))
      local key = item.name .. '@' .. tostring(math.floor(item.damage))
      
      gpu.set(1, y, item.label or key)
      gpu.set(36, y, tostring(prices[key] or 0) .. 'FCM')
      
      gpu.set(45, y, '[+1]')
      gpu.set(50, y, '[+2]')
      gpu.set(55, y, '[+5]')
      gpu.set(60, y, '[+10]')
      gpu.set(65, y, '[+32]')
      gpu.set(70, y, '[+64]')
      
      gpu.set(75, y, '<' .. tostring(math.floor(item.size)))
      
      items[y] = item
      y = y + 1
    end
  end
  
  while true do
    local e = {evt.pull()}
    
    if e[1] == 'interrupted' then
      -- gpu.bind(pscr, false)
      -- return
      break
    end
    
    if e[1] == 'modem_message' then
      break
    end
    
    if e[1] == 'touch' then
      local x = e[3]
      local y = e[4]
      
      if items[y] then
        local add = 0
        if x >= 45 then add = 1 end
        if x >= 50 then add = 2 end
        if x >= 55 then add = 5 end
        if x >= 60 then add = 10 end
        if x >= 65 then add = 32 end
        if x >= 70 then add = 64 end
        if x >= 75 then add = 0 end
        
        if add > 0 then
          export_to_sell(items[y].name, items[y].damage, add)
        end
      end
    end
  end
  
  finalize()
  -- evt.pull 'modem_message'
  break
end

gpu.bind(pscr, false)
