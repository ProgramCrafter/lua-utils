local ser = require 'serialization'
local com = require 'component'
local unc = require 'unicode'
local evt = require 'event'
local trm = require 'term'

local gpu = com.gpu

local status = '--'

local tos = tostring

local ship = com.warpdriveShipController

local function in_aabb(e, x, y, rx, by)
  return e[3] >= x and e[3] <= rx and e[4] >= y and e[4] <= by
end

local function update_screen()
  local name = ship.shipName()
  local x, y, z = ship.position()
  local a, b, c = ship.dim_positive()
  local d, e, f = ship.dim_negative()
  local cmd = ship.command()
  local _, jd = ship.getMaxJumpDistance()
  
  if gpu.getScreen() then
    gpu.fill(1, 1, 80, 25, ' ')
  else
    gpu.bind(com.screen.address, true)
    gpu.setResolution(80, 25)
  end
  
  gpu.set(40, 8, '=== ' .. name .. ' ship ===')
  gpu.set(40, 10, 'Position: ' .. tos(x) .. ' ' .. tos(y) .. ' ' .. tos(z))
  gpu.set(40, 11, 'Volume: ' .. tostring((a + d + 1) * (b + e + 1) * (c + f + 1)))
  gpu.set(40, 13, '[Request jump (max distance = ' .. tostring(jd) .. ')]')
  gpu.set(1, 24, '| Command: ' .. cmd .. ' |')
  gpu.set(1, 25, '| Status: ' .. status .. ' |')
  
  local e = {evt.pull()}
  if e[1] == 'interrupted' then return false end
  
  if e[1] == 'touch' and in_aabb(e, 40, 13, 54, 13) then
    trm.setCursor(42, 14)
    io.write 'dx: '
    local dx = io.read()
    dx = dx and tonumber(dx)
    if not dx then return true end
    
    trm.setCursor(42, 15)
    io.write 'dy: '
    local dy = io.read()
    dy = dy and tonumber(dy)
    if not dy then return true end
    
    trm.setCursor(42, 16)
    io.write 'dz: '
    local dz = io.read()
    dz = dz and tonumber(dz)
    if not dz then return true end
    
    gpu.set(1, 25, '| Status: JUMPING |')
    
    gpu.set(1, 24, '| Command:  ' .. ser.serialize{ ship.command('MANUAL') })
    gpu.set(1, 23, '| Movement: ' .. ser.serialize{ ship.movement(dx, dy, dz)    })
    ship.enable(true)
    
    os.sleep(5)
  end
  
  return true
end

gpu.setResolution(80, 25)
ship.shipName 'SpaceMaster'
while update_screen() do  end
ship.command 'OFFLINE'
trm.setCursor(1, 1)
