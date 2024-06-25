-- Globals
SPAWN_PTS = {
    plat23 = {2301, 2315, 148},
    antares = {-839, -1526, 15},
}
DEFAULT_SPAWN_PT = SPAWN_PTS[Cvar.get('mapname')] or {0, 0 , 0}

juggernaut = nil
oldOrigin = nil
gameOver = false
teleported = false
KILLS_REQ = 10
KILLS = {}

function CopyTable(src)
    local n = {}
    for k, v in ipairs(src) do
        n[k] = v
    end
    return n
end

function Say(ent, txt)
    local num = -1
    if ent then
        num = ent.number
    end
    sgame.SendServerCommand(num, 'print ' .. '"' .. txt .. '"')
end

function CP(ent, txt)
    local num = -1
    if ent then
        num = ent.number
    end
    sgame.SendServerCommand(num, 'cp ' .. '"' .. txt .. '"')
end

function SayCP(ent, txt)
    Say(ent, txt)
    CP(ent, txt)
end

function Putteam(ent, team)
    if not ent or not ent.client then
        return
    end
    Timer.add(1, function ()
        ent.client:forceteam(team)
        if ent.bot then
            local skill = ent.bot.skill
            ent.bot.skill = skill
        end
    end)
end

function PrintHelp(ent, args)
    Say(ent, string.format([=[Welcome to the Juggernaut mod!
Kill the Juggernaut (the alien) to become the alien.
First alien with %d kills wins the game!
List of commands: /help /kills']=], KILLS_REQ))
end

function PrintKills(ent, args)
    local out = "Kills Required: " .. KILLS_REQ .. "\n"
    out = out .. "Kills:\n"
    for k,v in pairs(KILLS) do
        out = out .. sgame.entity[k].client.name .. "^* = " .. v .. "\n"
    end
    Say(ent, out)
end

function SameEnt(a, b)
    if a == nil or b == nil then
        return false
    end
    return a.number == b.number
end

function WelcomeClient(ent, connect)
    CP(ent, 'Welcome to the Juggernaut mod! Type /help for more info.')
end

function SetJuggernaut(ent)
    juggernaut = ent
    Putteam(ent, 'a')
    if not KILLS[ent.number] then
        KILLS[ent.number] = 0
    end
    CP(nil, ent.client.name .. ' is now the juggernaut!')
end

function OnTeamChange(ent, team)
    -- Set the first juggernaut.
    if juggernaut == nil then
        if team == 'human' then
            SetJuggernaut(ent)
            return
        end
    end
    -- If the current juggernaut leaves, reset...
    if SameEnt(juggernaut, ent) then
        if team ~= 'alien' then
            juggernaut = nil
            ResetJug()
        end
        ent.client:cmd('class level0')
        return
    end
    -- Don't let people join aliens unless they are the juggernaut.
    if team == 'alien' then
        Putteam(ent, 'h')
    end
end

function ResetJug()
    local start = math.random(0, sgame.level.max_clients)
    local i = start
    while true do
        local e = sgame.entity[i]
        if e and e.client and e.team == "human" then
            SetJuggernaut(e)
            return
        end
        i = i + 1
        i = i % sgame.level.max_clients
        if i == start then
            break
        end
    end
    SayCP(nil, "Unable to set juggeranut!")
end

function MaybeResetJug(ent, connect)
    -- TODO: Make this smarter by picking a player with the largest kill count or something...
    if SameEnt(ent, juggernaut) and not connect then
        juggernaut = nil
        ResetJug()
    end
end

function JugDie(ent, inflictor, attacker, mod)
    if inflictor ~= nil and inflictor.client ~= nil then
        oldOrigin = CopyTable(ent.origin)
        Putteam(juggernaut, 'h')
        SetJuggernaut(inflictor)
    else
        oldOrigin = nil
    end
    teleported = false
end

function RestoreHealth()
    local health = juggernaut.client.health
    local max_health = Unv.classes[juggernaut.client.class].health
    health = health + max_health * 0.5
    if health > max_health then
        health = max_health
    end
    juggernaut.client.health = health
end

function KillCount(ent, inflictor, attacker, mod)
    if SameEnt(inflictor, juggernaut) then
        KILLS[juggernaut.number] = KILLS[juggernaut.number] + 1
        CP(nil, 'Juggernaut has ' .. KILLS[juggernaut.number] .. ' kills!')
        RestoreHealth()
        if KILLS[juggernaut.number] == KILLS_REQ then
            gameOver = true
        end
    end
end

function OnPlayerSpawn(ent)
    if ent.team == 'spectator' then
        return
    end
    if SameEnt(ent, juggernaut) then
        -- If they are a spec but on aliens, then they just entered the spawn menu. So force them to spawn.
        if ent.client.class == 'spectator' and ent.team == 'alien' then
            ent.client:cmd('class level0')
            return
        end
        ent.die = JugDie
        local teleLocation = oldOrigin and oldOrigin or DEFAULT_SPAWN_PT
        if not teleported and teleLocation then
            ent.client:teleport(teleLocation)
            oldOrigin = nil
            teleported = true
        end
        return
    end
    ent.die = KillCount
end

function GameEnd()
    if gameOver then
        return 'aliens'
    end
    return false
end

function SetupBuildables()
    local eggs = {}
    local nodes = {}
    for _, ent in pairs(sgame.entity) do
        if ent.team == 'alien' and ent.buildable ~= nil then
            ent.buildable.god = true
            if ent.buildable.name == 'eggpod' then
                eggs[#eggs+1] = ent
            elseif ent.buildable.name ~= 'overmind' and ent.buildable.name ~= 'booster' then
                ent.buildable:decon()
            end
        elseif ent.team == 'human' and ent.buildable ~= nil then
            ent.buildable.god = true
            if ent.buildable.name == 'telenode' then
                nodes[#nodes+1] = ent
            elseif ent.buildable.name ~= 'reactor' and ent.buildable.name ~= 'arm' and ent.buildable.name ~= 'medistat' then
                ent.buildable:decon()
            end
        end
    end
    local num_spawn = 16
    local eggs_per_egg = math.floor(num_spawn / #eggs)
    print('Using ' .. eggs_per_egg .. ' spawns per spawn')
    if eggs_per_egg < 1 then
        return
    end
    for _, egg in ipairs(eggs) do
        for i=0,eggs_per_egg do
            local new_egg = sgame.SpawnBuildable('eggpod', egg.origin, egg.angles, egg.origin2, true)
            if not new_egg then
                print("error creating egg")
            end
            new_egg.buildable.god = true
        end
    end
    local nodes_per_node = math.floor(num_spawn / #nodes)
    for _, node in ipairs(nodes) do
        for i=0,nodes_per_node do
            local new_node = sgame.SpawnBuildable('telenode', node.origin, node.angles, node.origin2, true)
            if not new_node then
                print("error creating egg")
            end
            new_node.buildable.god = true
        end
    end

end

function AddBots()
    local numBots = math.min(math.max(6, sgame.level.num_connected_players * 2), 14)
    local cmd = ''
    for i=0,numBots do
        cmd = cmd .. 'bot add * h 5;'
    end
    Cmd.exec(cmd)
end

function init()
    sgame.hooks.RegisterClientConnectHook(WelcomeClient)
    sgame.hooks.RegisterClientConnectHook(MaybeResetJug)
    sgame.hooks.RegisterTeamChangeHook(OnTeamChange)
    sgame.hooks.RegisterPlayerSpawnHook(OnPlayerSpawn)
    sgame.hooks.RegisterGameEndHook(GameEnd)
    SetupBuildables()
    Cvar.set('g_bot_attackStruct', '0')
    Cvar.set('g_disabledClasses', 'builder,builderupg')
    Cvar.set('g_disabledEquipment', 'ckit')
    Cvar.set('g_momentumBaseMod', '1.0')
    Cvar.set('g_momentumHalfLife', '0')
    Cvar.set('g_momentumKillMod', '2')
    Cvar.set('g_evolveAroundHumans', '-1')
    Cvar.set('g_bot_defaultFill', '0')

    sgame.RegisterClientCommand('help', PrintHelp)
    sgame.RegisterClientCommand('kills', PrintKills)

    sgame.RegisterServerCommand('jug_req_kills', 'Set the number of kills required to win', function(args)
        local kills = tonumber(args[1])
        if not kills or kills < 1 then
            print('Invalid number. Kills must be greater than 0')
        end
        KILLS_REQ = kills
    end)

    sgame.RegisterVote('jugkills', { type = 'V_PUBLIC', target = 'T_OTHER' }, function(ent, team, args)
        local kills = tonumber(args[1])
        if not kills or kills < 1 then
            Say(ent, 'Invalid number. Kills must be greater than 0')
        end

        return true, 'jug_req_kills ' .. kills, 'Set of juggernaut kills to win: ' .. kills
    end)

    Cmd.exec('lock a')
    AddBots()
    print('Loaded lua...')

end

Timer.add(1, init)
