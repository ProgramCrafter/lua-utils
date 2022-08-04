local com = require 'component'
local sid = require 'sides'
local evt = require 'event'

local scr = '9fb3d33a-60c5-4af3-9937-ca94467dcc0f'
local pscr = '466ec26a-8987-4e50-a310-2c705917f800'

local sell_mei = com.proxy 'f2f100a5-05dc-4ea2-98e6-7d595b9a87e1'
local sell_sid = sid.down
local sell_con_sid = sid.south

local shop_mei = com.proxy 'b7727a24-f1be-441d-b07c-e173b40d507f'
local shop_sid = sid.east

local prices = {
  ['minecraft:quartz@0']      = 16,
  ['minecraft:stone@0']       = 1,
  ['minecraft:stonebrick@0']  = 1,
  ['minecraft:cobblestone@0'] = 1,  -- cobblestone
  ['minecraft:sand@0']        = 2,
  ['minecraft:wood@0']        = 2,
  ['minecraft:obsidian@0']    = 18,
  ['minecraft:iron_block@0']  = 18,
  ['minecraft:gold_block@0']  = 54,
  ['minecraft:lapis_block@0'] = 27,
  ['minecraft:diamond_block@0']  = 108,
  ['minecraft:emerald_block@0']  = 108,
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
  amount = sell_mei.pullItem('UP', 1)
  return amount
end

local function import_to_shop(id, dmg, amount)
  assert(amount <= 64)
  
  local fingerprint = {id = id, damage = dmg}
  amount = sell_mei.exportItem(fingerprint, 'UP', amount, 1).size
  amount = com.transposer.transferItem(sell_sid, shop_sid, amount)
  amount = shop_mei.pullItem('SOUTH', 1)
  return amount
end

local function finalize()
  com.transposer.transferItem(sell_con_sid, sid.top)
end

com.modem.open(877)

local gpu = com.gpu
gpu.bind(scr, false)
gpu.setResolution(80, 25)

while true do
  take_cell()
  
  while true do
    gpu.fill(1, 1, 80, 25, ' ')
    
    local y = 1
    local items = {}
    for _, item in pairs(shop_mei.getItemsInNetwork()) do
      if _ ~= 'n' then
        -- print(require'serialization'.serialize(item))
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
    
    local e = {evt.pull()}
    
    if e[1] == 'interrupted' then
      gpu.bind(pscr, false)
      return
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
  evt.pull 'modem_message'
  
  take_cell()
  for _, item in pairs(sell_mei.getItemsInNetwork()) do
    if _ ~= 'n' then
      local remaining = item.size
      
      -- print(item.name, item.size)
      
      while remaining > 0 do
        local s, value = pcall(import_to_shop, item.name, item.damage, math.min(64, remaining))
        if not s then break end
        remaining = remaining - value
      end
      
      -- print('  remaining', remaining)
    end
  end
  finalize()
  
  -- io.write('...') io.read()
end

gpu.bind(pscr, false)
