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

function M.AllPlayers()
    local idx = -1
    local maxClients = level.max_clients
    local connectedClients = level.num_connected_clients
    local found = 0
    return function ()
        while found < connectedClients and idx < maxClients do
            idx = idx + 1
            local ent = entities[idx]
            if ent ~= nil and ent.client ~= nil then
                found = found + 1
                return ent
            end
        end
        return nil
    end
end

function M.RegisterBotBalanceHook(botTeam, minimumBots)
    local function balance()
        local playerTeam = botTeam == 'human' and sgame.level.aliens or sgame.level.humans
        local botCount = math.max(minimumBots, playerTeam.num_players)
        Cmd.exec(('bot fill %d %s'):format(botCount, botTeam))
    end

    local function queue(ent)
        if ent and ent.bot then
            return
        end
        if queued then
            return
        end
        Timer.add(1, function()
            balance()
        end)
    end

    sgame.hooks.RegisterClientConnectHook(queue)
    sgame.hooks.RegisterTeamChangeHook(queue)
    return balance
end

function PrintTable(t)
    for i, v in pairs(t) do
        print(('[%s] => %s'):format(i, v))
    end
end

return M
