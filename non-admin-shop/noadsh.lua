local com = require 'component'
local sid = require 'sides'
local evt = require 'event'

local gpu = com.gpu
local red = com.redstone
local sen = com.openperipheral_sensor

------------------------------------------------------------------

local cart, cost = {}, 0
local prices_y_mapping = {}
local prices_sell = { -- TODO: add prices_buy
  ['minecraft:quartz@0']      = 16,
  ['minecraft:stone@0']       = 1,
  ['minecraft:stonebrick@0']  = 1,
  ['minecraft:cobblestone@0'] = 1,
  ['minecraft:sand@0']        = 2,
  ['minecraft:planks@0']      = 2,
  ['minecraft:obsidian@0']    = 18,
  ['minecraft:iron_block@0']  = 18,
  ['minecraft:gold_block@0']  = 54,
  ['minecraft:lapis_block@0'] = 27,
  ['minecraft:diamond_block@0']  = 108,
  ['minecraft:emerald_block@0']  = 108,
  ['EnderIO:itemPowderIngot@8']  = 2
}
local mappings_trn_to_id = {
  ['item.netherquartz@0']     = 'minecraft:quartz@0',
  ['tile.stone@0']            = 'minecraft:stone@0',
  ['tile.stonebricksmooth@0'] = 'minecraft:stonebrick@0',
  ['tile.stonebrick@0']       = 'minecraft:cobblestone@0',
  ['tile.sand@0']             = 'minecraft:sand@0',
  ['tile.wood@0']             = 'minecraft:planks@0',
  ['tile.obsidian@0']         = 'minecraft:obsidian@0',
  ['tile.blockIron@0']        = 'minecraft:iron_block@0',
  ['tile.blockGold@0']        = 'minecraft:gold_block@0',
  ['tile.blockLapis@0']       = 'minecraft:lapis_block@0',
  ['tile.blockDiamond@0']     = 'minecraft:diamond_block@0',
  ['tile.blockEmerald@0']     = 'minecraft:emerald_block@0',
  ['item.itemPowderIngot@8']  = 'EnderIO:itemPowderIngot@8'
}

------------------------------------------------------------------

local function open_door() red.setOutput(sid.top, 15) end
local function close_door() red.setOutput(sid.top, 0) end
local function is_in_zone(pos)
  return math.abs(pos.x) + math.abs(pos.z) <= 4 and math.abs(pos.y + 1) < 0.000001
end
local function wait_for_single_player_come()
  while true do
    local players_in_zone = {}
    
    local players = sen.getPlayers()
    for i = 1, #players do
      local ok, info = pcall(function()
        return sen.getPlayerByName(players[i].name).basic()
      end)
      local pos = ok and info.position or {x = -10, y = -10, z = -10}
      if is_in_zone(pos) then table.insert(players_in_zone, players[i].name) end
    end
    
    if #players_in_zone == 1 then return players_in_zone end
    
    os.sleep(0.05)
  end
end
local function clear_cart()
  cart = {}
  cost = 0
end

------------------------------------------------------------------

local function count_keys(t)
  local v = 0
  for _ in pairs(t) do v = v + 1 end
  return v
end

function gpu.rset(x, y, text)
  gpu.set(x - #text + 1, y, text)
end

function gpu.tset(t)
  local widths = {}
  for i = 1, #t do
    for j = 1, #t[1] do
      assert(t[i][j])
      widths[j] = math.max(widths[j] or 0, #t[i][j])
    end
  end
  
  for y = 1, #t do
    local s = ''
    for j = 1, #t[1] do
      s = s .. t[y][j] .. (' '):rep(widths[j] + 1 - #t[y][j])
    end
    gpu.set(1, y, s)
  end
end

local function show_prices()
  gpu.fill(1, 1, 160, 50, ' ')
  
  gpu.set(157, 1,  '   +')
  gpu.set(157, 2,  '---+')
  gpu.set(157, 3, '\\  /')
  gpu.set(158, 3, tostring(count_keys(cart)))
  gpu.rset(160, 4, tostring(cost) .. 'FCM')
  
  local y = 2
  local items = {}
  local table_set = {}
  table_set[1] = {
    'Название товара',
    'Цена',
    '', '', '', '', '', '', '',
    'Остаток',
    'В корзине',
  }
  
  for _, item in pairs(shop_mei.getItemsInNetwork()) do
    if _ ~= 'n' then
      -- print(require'serialization'.serialize(item))
      local key = item.name .. '@' .. tostring(math.floor(item.damage))
      
      local less = ((cart[key] or 0) > 0) and '[-1]' or '    '
      
      table_set[y] = {
        item.label or key,
        tostring(prices[key] or 9999) .. 'FCM',
        less, '[+1]', '[+2]', '[+5]', '[+10]', '[+32]', '[+64]',
        tostring(math.floor(item.size)),
        tostring(cart[key] or 0)
      }
      
      items[y] = item
      y = y + 1
    end
  end
  
  gpu.tset(table_set)
  
  return items
end

------------------------------------------------------------------

local function show_trade_screen()
  
end

------------------------------------------------------------------

while true do
  open_door()
  wait_for_single_player_come()
  close_door()
  
  clear_cart()
  
  while true do
    prices_y_mapping = show_prices()
    local e = {evt.pull()}
    handle_buy_event(e)
    if is_cart_finish_event(e) then break end
  end
  
  while true do
    if show_trade_screen() == cost then break end
    os.sleep(0.05)
  end
  
  show_pull_hint_screen()
  pull_cell_up()
  while true do
    if not left_cell_active() then push_cell_down(RIGHT) break end
    if not right_cell_active() then push_cell_down(LEFT) break end
    os.sleep(0.05)
  end
  
  show_final_screen()
  open_door()
  os.sleep(20)
  close_door()
end
