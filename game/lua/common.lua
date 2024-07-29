-- unlockteams, lockhumans, lockaliens, firebomboff, kick, defaultrot, fillbots_humans, mute, delaysd, extend, draw, kickbots, map_restart, nextmap, botskill, layout, unmute, map, poll, fillbots_aliens, fillbots, maxminers, alienfunds, minerbp, humanpve, spectate, alienpve, firebombon

local chat = require('lua/chat.lua')
local cvars = require('lua/cvars.lua')


sgame.RegisterVote('instabuild', { type = 'V_PUBLIC', target = 'T_NONE' }, function(ent, team, args)
    cvars:addCleanup('g_instantBuilding')
    local instabuild = cvars:parseBool(Cvar.get('g_instantBuilding'))
    local status = instabuild and '^1OFF^*' or '^2ON^*'
    cvars.addCleanup('g_instantBuilding')
    return true, 'toggle g_instantBuilding', 'Toggle instant building: ' .. status
end)

sgame.RegisterVote('devmap', { type = 'V_PUBLIC', target = 'T_NONE' }, function(ent, team, args)
    local layout = ''
    if #args > 0 then
        layout = args[1]
    end
    local map = Cvar.get('mapname')
    return true, 'devmap ' .. map, 'Enable devmap on current map'
end)

sgame.RegisterVote('botskill', { type = 'V_PUBLIC', target = 'T_OTHER' }, function(ent, team, args)
    local skill = tonumber(args[1])
    if not skill or skill < 1 or skill > 9 then
        local num = -2
        if not ent then
            num = ent.number
        end
        chat.Say(ent, 'Must pass in a skill between 1 and 7')
        return false
    end

    return true, 'setg g_bot_defaultSkill ' .. skill .. ';bot skill ' .. skill, 'Set bot skill level to: ' .. skill
end)

sgame.RegisterVote('maxminers', { type = 'V_PUBLIC', target = 'T_OTHER' }, function(ent, team, args)
    local max = tonumber(args[1])
    if not max then
        local num = -2
        if not ent then
            num = ent.number
        end
        chat.Say(ent, 'Must pass a number for max miners or -1 for infinite')
        return false
    end

    return true, 'setg g_maxMiners ' .. max, 'Set max number of miners per team to: ' .. max
end)

sgame.RegisterVote('minerbp', { type = 'V_PUBLIC', target = 'T_OTHER' }, function(ent, team, args)
    local bp = tonumber(args[1])
    if not bp or bp <= 0 then
        local num = -2
        if not ent then
            num = ent.number
        end
        chat.Say(ent, 'Must pass a positive number for minerbp')
        return false
    end

    return true, 'setg g_BPBudgetPerMiner ' .. bp, 'Set BP per miner to: ' .. bp
end)

sgame.RegisterServerCommand('humanpve', 'Start a PVE game with players against human bots', function(args)
    for i = 0, sgame.level.max_clients do
        local ent = sgame.entity[i]
        if ent and ent.client and ent.team == 'human' then
            ent.client:forceteam('aliens')
        end
    end

    cvars:set('g_BPInitialBudgetHumans', '1000')
    -- After 15 min, lock down human building
    Timer.add(15 * 60 * 1000, function() cvars:set('g_BPInitialBudgetHumans', tostring(sgame.level.humans.spent_budget)) end)
    local numBots = math.min(math.max(6, sgame.level.num_connected_players * 2), 14)

    Cmd.exec('bot fill ' .. numBots .. ' h')
    Cmd.exec('bot fill 3 a')
    chat.GlobalCP('Starting Human PVE mode!')
end)

sgame.RegisterVote('humanpve', { type = 'V_PUBLIC', target = 'T_NONE' }, function(ent, team, args)
    return true, 'humanpve', 'Start Human PVE mode (Aliens vs Human bots)!'
end)

sgame.RegisterServerCommand('alienpve', 'Start a PVE game with players against alien bots', function(args)
    for i = 0, sgame.level.max_clients do
        local ent = sgame.entity[i]
        if ent and ent.client and ent.team == 'alien' then
            ent.client:forceteam('humans')
        end
    end

    cvars:set('g_BPInitialBudgetAliens', '1000')
    -- After 15 min, lock down alien building
    Timer.add(15 * 60 * 1000, function() cvars:set('g_BPInitialBudgetAliens', tostring(sgame.level.aliens.spent_budget)) end)
    local numBots = math.min(math.max(6, sgame.level.num_connected_players * 2), 14)
    Cmd.exec('bot fill ' .. numBots .. ' a')
    Cmd.exec('bot fill 3 h')
    chat.GlobalCP('Starting Alien PVE mode!')
end)

sgame.RegisterVote('alienpve', { type = 'V_PUBLIC', target = 'T_NONE' }, function(ent, team, args)
    return true, 'alienpve', 'Start Alien PVE mode (Humans vs Alien bots)!'
end)

sgame.RegisterVote('juggernaut', { type = 'V_PUBLIC', target = 'T_NONE' }, function(ent, team, args)
    return true, 'set lua_gamemode juggernaut/jug.lua;map_restart', 'Start the juggernaut gamemode!'
end)

sgame.RegisterVote('towerdefense', { type = 'V_PUBLIC', target = 'T_NONE' }, function(ent, team, args)
    return true, 'set lua_gamemode towerdefense/game.lua;map_restart', 'Start the Tower Defense gamemode!'
end)


_ALIEN_FREE_FUNDS = {
    evos = 0,
    interval = 0,
    enabled = false,
}

local function _addalienmoney()
    for i = 0, 64 do
        local ent = sgame.entity[i]
        if ent and ent.client and ent.team == 'alien' then
            ent.client.evos = math.min(math.max(ent.client.evos + _ALIEN_FREE_FUNDS.evos, 0), 20)
        end
    end

    if sgame.level.intermission or not _ALIEN_FREE_FUNDS.enabled then
        return
    end

    Timer.add(_ALIEN_FREE_FUNDS.interval, _addalienmoney)
end

sgame.RegisterServerCommand('setalienfreefunds', 'Set how many funds aliens get at which interval', function(args)
    local usage = function()
        print('setalienfreefunds <time in s> [# of evos] ')
    end
    if #args < 1 then
        usage()
        return
    end
    local interval = tonumber(args[1])
    local evos = tonumber(args[2]) or 1
    if not interval then
        print('interval must be a number.')
        usage()
        return
    end
    _ALIEN_FREE_FUNDS.evos = evos
    _ALIEN_FREE_FUNDS.interval = interval * 1000
    if not _ALIEN_FREE_FUNDS.enabled and interval > 0 then
        Timer.add(_ALIEN_FREE_FUNDS.interval, _addalienmoney)
        _ALIEN_FREE_FUNDS.enabled = true
    elseif interval <= 0 then
        _ALIEN_FREE_FUNDS.enabled = false
    end
end)

sgame.RegisterVote('alienfunds', { type = 'V_PUBLIC', target = 'T_OTHER' }, function(ent, team, args)
    local interval = tonumber(args[1])
    local evos = tonumber(args[2]) or 1
    if not interval then
        chat.Say(ent, 'Must pass a number for for interval!\ncallvote alienfunds <interval in s> [# of evos]')
        return false
    end

    return true, 'setg g_freeFundPeriod 0;setalienfreefunds ' .. evos .. ' ' .. interval,
        'Give aliens ' .. evos .. ' evos every ' .. interval .. 'ms'
end)

local function pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0             -- iterator variable
    local iter = function() -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

HIGHEST_ADMIN_H = 0
HIGHEST_ADMIN_A = 0

_BOTEQUIP_H_CVARS = {
    psaw = 'g_bot_painsaw',
    shotgun = 'g_bot_shotgun',
    lgun = 'g_bot_lasgun',
    mdriver = 'g_bot_mdriver',
    chaingun = 'g_bot_chain',
    prifle = 'g_bot_prifle',
    flamer = 'g_bot_flamer',
    lcannon = 'g_bot_lcannon',
    bsuit = 'g_bot_battlesuit',
    firebomb = 'g_bot_firebomb',
    grenade = 'g_bot_grenade',
    radar = 'g_bot_radar',
    build = 'g_bot_buildHumans',
}

_BOTEQUIP_A_CVARS = {
    level1 = 'g_bot_level1',
    level2 = 'g_bot_level2',
    level2upg = 'g_bot_level2upg',
    level3 = 'g_bot_level3',
    level3upg = 'g_bot_level3upg',
    level4 = 'g_bot_level4',
    build = 'g_bot_buildAliens',
}

local boolMap = {
    [true] = "ON",
    [false] = "OFF",
}

sgame.RegisterClientCommand('botequip', function(ent, args)
    if not ent or ent.team == 'spectator' then
        chat.Say(ent, 'Must join a team to use botequip.')
        return
    end
    local t = ent.team == 'alien' and _BOTEQUIP_A_CVARS or _BOTEQUIP_H_CVARS
    local status = function()
        local txt = ''

        local first = true
        for k, v in pairsByKeys(t) do
            if first then
                first = false
            else
                txt = txt .. ', '
            end
            local val = Cvar.get(v)
            val = cvars:parseBool(val)
            txt = txt .. k .. ' = ' .. boolMap[val]
        end
        chat.Say(ent, txt)
    end
    if #args < 1 then
        status()
        return
    end

    local cmd = ''
    local txt = ''
    for _, v in ipairs(args) do
        local cvar = t[v]
        if not cvar then
            chat.Say(ent, 'Invalid equipment ' .. v)
            return
        end
        cmd = cmd .. 'toggle ' .. cvar .. '\n'
        cvars:addCleanup(cvar)
        local val = Cvar.get(cvar)
        val = cvars:parseBool(val)
        txt = txt .. v
        if val then
            txt = txt .. ' ^1Denied^*\n'
        else
            txt = txt .. ' ^2Allowed^*\n'
        end
    end
    Cmd.exec(cmd)
    chat.Say(ent, txt)
end)

sgame.RegisterServerCommand('setg', 'Set a cvar for the duration of the game. After which it will be restored to the previous value.', function(args)

    cvars:set(args[1], tostring(args[2]))
end)
