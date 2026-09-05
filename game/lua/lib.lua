local str = require('lua/str.lua')
local cvars = require('lua/cvars.lua')

local entities = sgame.entity
local level = sgame.level

local M = {}

function _setCSVCvar(var, equip)
    local e = Cvar.get(var)
    local tarr = str.split(e, ',')
    local t = {}
    for _, p in ipairs(tarr) do
        t[p] = false
    end
    for k,v in pairs(equip) do
        if v then
            t[k] = nil
        else
            t[k] = v
        end
    end

    local val = ''
    for k,v in pairs(t) do
        if not v then
            val = val .. k .. ','
        end
    end

    val = val:sub(1,-2)
    cvars.set(var, val)
end

function M.SetAvailableEquipment(equip)
    _setCSVCvar('g_disabledEquipment', equip)
end

function M.SetAvailableEquipment(equip)
    _setCSVCvar('g_disabledEquipment', equip)
end

function M.AllPlayers()
    local idx = -1
    local max = level.num_connected_clients
    local count = 0
    return function ()
        if count == max then
            return nil
        end
        idx = idx + 1
        local ent = entities[idx]
        if ent ~= nil and ent.client ~= nil then
            count = count + 1
            return ent
        end
    end
end

return M
