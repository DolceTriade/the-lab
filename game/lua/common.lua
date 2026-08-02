-- unlockteams, lockhumans, lockaliens, firebomboff, kick, defaultrot, fillbots_humans, mute, delaysd, extend, draw, kickbots, map_restart, nextmap, botskill, layout, unmute, map, poll, fillbots_aliens, fillbots, maxminers, alienfunds, minerbp, humanpve, spectate, alienpve, firebombon

local chat = require('lua/chat.lua')
local cvars = require('lua/cvars.lua')


sgame.RegisterVote('instabuild', { type = 'V_PUBLIC', target = 'T_NONE' }, function(ent, team, args)
    cvars.addCleanup('g_instantBuilding')
    local instabuild = cvars.parseBool(Cvar.get('g_instantBuilding'))
    local status = instabuild and '^1OFF^*' or '^2ON^*'
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

sgame.RegisterVote('alienbp', { type = 'V_PUBLIC', target = 'T_OTHER' }, function(ent, team, args)
    local bp = tonumber(args[1])
    if not bp or bp <= 0 then
        local num = -2
        if not ent then
            num = ent.number
        end
        chat.Say(ent, 'Must pass a positive number for alienbp')
        return false
    end

    return true, 'setg g_BPInitialBudgetAliens ' .. bp, 'Set Alien BP to: ' .. bp
end)

sgame.RegisterVote('humanbp', { type = 'V_PUBLIC', target = 'T_OTHER' }, function(ent, team, args)
    local bp = tonumber(args[1])
    if not bp or bp <= 0 then
        local num = -2
        if not ent then
            num = ent.number
        end
        chat.Say(ent, 'Must pass a positive number for humanbp')
        return false
    end

    return true, 'setg g_BPInitialBudgetHumans ' .. bp, 'Set Human BP to: ' .. bp
end)

sgame.RegisterServerCommand('alienpve', 'Start a PVE game with players against human bots', function(args)
    for i = 0, sgame.level.max_clients do
        local ent = sgame.entity[i]
        if ent and ent.client and ent.team == 'human' then
            ent.client:forceteam('aliens')
        end
    end

    cvars.set('g_BPInitialBudgetHumans', '2000')
    local numBots = 9

    Cmd.exec('bot fill 3 a')
    cvars.set('g_bot_defaultBehaviorHuman', 'pve.lua')
    cvars.set('g_bot_buildCooldown', '4000')
    Cmd.exec('bot fill ' .. numBots .. ' h')
    Cmd.exec('lock h')
    chat.GlobalCP('Starting Alien PVE mode!')
end)

sgame.RegisterVote('alienpve', { type = 'V_PUBLIC', target = 'T_NONE' }, function(ent, team, args)
    return true, 'map_restart; delay 10f alienpve', 'Start Alien PVE mode (Aliens vs Human bots)!'
end)

sgame.RegisterServerCommand('humanpve', 'Start a PVE game with players against alien bots', function(args)
    for i = 0, sgame.level.max_clients do
        local ent = sgame.entity[i]
        if ent and ent.client and ent.team == 'alien' then
            ent.client:forceteam('humans')
        end
    end

    cvars.set('g_BPInitialBudgetAliens', '2000')
    local numBots = 9
    Cmd.exec('lock a;bot del all')
    Cmd.exec('bot fill 3 h')
    cvars.set('g_bot_defaultBehaviorAlien', 'pve.lua')
    cvars.set('g_bot_buildCooldown', '4000')
    Cmd.exec('bot fill ' .. numBots .. ' a')
    chat.GlobalCP('Starting Human PVE mode!')
end)

sgame.RegisterVote('humanpve', { type = 'V_PUBLIC', target = 'T_NONE' }, function(ent, team, args)
    return true, 'map_restart; delay 10f humanpve', 'Start Alien PVE mode (Humans vs Alien bots)!'
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
            val = cvars.parseBool(val)
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
        cvars.addCleanup(cvar)
        local val = Cvar.get(cvar)
        val = cvars.parseBool(val)
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
    if #args ~= 2 then
        print('Expected 2 args')
    end
    cvars.set(args[1], tostring(args[2]))
end)
