local cvars = require('lua/cvars.lua')

local Juggernaut = {}
Juggernaut.__index = Juggernaut

local SPAWN_PTS = {
    plat23 = { 2301, 2315, 148 },
    antares = { -839, -1526, 15 },
}

local function sameEnt(a, b)
    return a ~= nil and b ~= nil and a.number == b.number
end

function Juggernaut.new(options)
    options = options or {}
    return setmetatable({
        juggernaut = nil,
        oldOrigin = nil,
        gameOver = false,
        teleported = false,
        killsReq = 10,
        kills = {},
        defaultSpawnPoint = SPAWN_PTS[Cvar.get('mapname')] or { 0, 0, 0 },
        difficulty = options.difficulty,
    }, Juggernaut)
end

function Juggernaut:copyTable(src)
    local copy = {}
    for k, v in ipairs(src) do
        copy[k] = v
    end
    return copy
end

function Juggernaut:say(ent, txt)
    local num = ent and ent.number or -1
    sgame.SendServerCommand(num, 'print ' .. '"' .. txt .. '"')
end

function Juggernaut:cp(ent, txt)
    local num = ent and ent.number or -1
    sgame.SendServerCommand(num, 'cp ' .. '"' .. txt .. '"')
end

function Juggernaut:sayCP(ent, txt)
    self:say(ent, txt)
    self:cp(ent, txt)
end

function Juggernaut:putTeam(ent, team)
    if not ent or not ent.client then
        return
    end
    Timer.add(1, function()
        ent.client:forceteam(team)
        if ent.bot then
            ent.bot.skill = ent.bot.skill
        end
    end)
end

function Juggernaut:printHelp(ent)
    self:say(ent, string.format([=[Welcome to the Juggernaut mod!
Kill the Juggernaut (the alien) to become the alien.
First alien with %d kills wins the game!
List of commands: /help /kills']=], self.killsReq))
end

function Juggernaut:printKills(ent)
    local out = 'Kills Required: ' .. self.killsReq .. '\nKills:\n'
    for k, value in pairs(self.kills) do
        out = out .. sgame.entity[k].client.name .. '^* = ' .. value .. '\n'
    end
    self:say(ent, out)
end

function Juggernaut:welcomeClient(ent, connect)
    self:cp(ent, 'Welcome to the Juggernaut mod! Type /help for more info.')
end

function Juggernaut:setJuggernaut(ent)
    self.juggernaut = ent
    self:putTeam(ent, 'a')
    if not self.kills[ent.number] then
        self.kills[ent.number] = 0
    end
    self:cp(nil, ent.client.name .. '^* is now the juggernaut!')
end

function Juggernaut:onTeamChange(ent, team)
    if self.juggernaut == nil and team == 'human' then
        self:setJuggernaut(ent)
        return
    end

    if sameEnt(self.juggernaut, ent) then
        if team ~= 'alien' then
            self.juggernaut = nil
            self:resetJug()
        end
        ent.client:cmd('class level0')
        return
    end

    if team == 'alien' then
        self:putTeam(ent, 'h')
    end
end

function Juggernaut:resetJug()
    local start = math.random(0, sgame.level.max_clients)
    local i = start
    while true do
        local ent = sgame.entity[i]
        if ent and ent.client and ent.team == 'human' then
            self:setJuggernaut(ent)
            return
        end
        i = (i + 1) % sgame.level.max_clients
        if i == start then
            break
        end
    end
    self:sayCP(nil, 'Unable to set juggernaut!')
end

function Juggernaut:maybeResetJug(ent, connect)
    if sameEnt(ent, self.juggernaut) and not connect then
        self.juggernaut = nil
        self:resetJug()
    end
end

function Juggernaut:jugDie(ent, inflictor)
    self:putTeam(self.juggernaut, 'h')
    if inflictor ~= nil and inflictor.client ~= nil then
        self.oldOrigin = self:copyTable(ent.origin)
        self:setJuggernaut(inflictor)
    else
        self.oldOrigin = nil
        self.juggernaut = nil
        self:resetJug()
    end
    self.teleported = false
end

function Juggernaut:restoreHealth()
    local health = self.juggernaut.client.health
    local maxHealth = Unv.classes[self.juggernaut.client.class].health
    self.juggernaut.client.health = math.min(health + maxHealth * 0.5, maxHealth)
end

function Juggernaut:killCount(ent, inflictor)
    if not sameEnt(inflictor, self.juggernaut) then
        return
    end
    self.kills[self.juggernaut.number] = self.kills[self.juggernaut.number] + 1
    self:cp(nil, 'Juggernaut has ' .. self.kills[self.juggernaut.number] .. ' kills!')
    self:restoreHealth()
    if self.kills[self.juggernaut.number] == self.killsReq then
        self.gameOver = true
    end
end

function Juggernaut:onPlayerSpawn(ent)
    if ent.team == 'spectator' then
        return
    end
    if sameEnt(ent, self.juggernaut) then
        if ent.client.class == 'spectator' and ent.team == 'alien' then
            ent.client:cmd('class level0')
            return
        end
        ent.die = function(...) self:jugDie(...) end
        local teleLocation = self.oldOrigin or self.defaultSpawnPoint
        if not self.teleported and teleLocation then
            ent.client:teleport(teleLocation)
            self.oldOrigin = nil
            self.teleported = true
        end
        return
    end
    ent.die = function(...) self:killCount(...) end
end

function Juggernaut:gameEnd()
    return self.gameOver and 'aliens' or false
end

function Juggernaut:setupBuildables()
    local eggs = {}
    local nodes = {}
    for _, ent in pairs(sgame.entity) do
        if ent.team == 'alien' and ent.buildable ~= nil then
            ent.buildable.god = true
            if ent.buildable.name == 'eggpod' then
                eggs[#eggs + 1] = ent
            elseif ent.buildable.name ~= 'overmind' and ent.buildable.name ~= 'booster' then
                ent.buildable:decon()
            end
        elseif ent.team == 'human' and ent.buildable ~= nil then
            ent.buildable.god = true
            if ent.buildable.name == 'telenode' then
                nodes[#nodes + 1] = ent
            elseif ent.buildable.name ~= 'reactor' and ent.buildable.name ~= 'arm' and ent.buildable.name ~= 'medistat' then
                ent.buildable:decon()
            end
        end
    end

    local numSpawn = 16
    if #eggs == 0 or #nodes == 0 then
        print('Juggernaut map is missing spawn buildables')
        return
    end
    local eggsPerEgg = math.floor(numSpawn / #eggs)
    print('Using ' .. eggsPerEgg .. ' spawns per spawn')
    if eggsPerEgg < 1 then
        return
    end
    for _, egg in ipairs(eggs) do
        for _ = 0, eggsPerEgg do
            local newEgg = sgame.SpawnBuildable('eggpod', egg.origin, egg.angles, egg.origin2, true)
            if newEgg then
                newEgg.buildable.god = true
            end
        end
    end

    local nodesPerNode = math.floor(numSpawn / #nodes)
    for _, node in ipairs(nodes) do
        for _ = 0, nodesPerNode do
            local newNode = sgame.SpawnBuildable('telenode', node.origin, node.angles, node.origin2, true)
            if newNode then
                newNode.buildable.god = true
            end
        end
    end
end

function Juggernaut:addBots()
    local numBots = math.min(math.max(6, sgame.level.num_connected_players * 2), 14)
    local cmd = ''
    for _ = 0, numBots do
        cmd = cmd .. 'bot add * h 5;'
    end
    Cmd.exec(cmd)
end

function Juggernaut:start()
    sgame.hooks.RegisterClientConnectHook(function(...) self:welcomeClient(...) end)
    sgame.hooks.RegisterClientConnectHook(function(...) self:maybeResetJug(...) end)
    sgame.hooks.RegisterTeamChangeHook(function(...) self:onTeamChange(...) end)
    sgame.hooks.RegisterPlayerSpawnHook(function(...) self:onPlayerSpawn(...) end)
    sgame.hooks.RegisterGameEndHook(function(...) return self:gameEnd(...) end)

    self:setupBuildables()
    cvars.set('g_bot_attackStruct', '0')
    cvars.set('g_disabledClasses', 'builder,builderupg')
    cvars.set('g_disabledEquipment', 'ckit')
    cvars.set('g_momentumBaseMod', '1.0')
    cvars.set('g_momentumHalfLife', '0')
    cvars.set('g_momentumKillMod', '2')
    cvars.set('g_evolveAroundHumans', '-1')
    cvars.set('g_bot_defaultFill', '0')

    sgame.RegisterClientCommand('help', function(ent) self:printHelp(ent) end)
    sgame.RegisterClientCommand('kills', function(ent) self:printKills(ent) end)
    sgame.RegisterServerCommand('jug_req_kills', 'Set the number of kills required to win', function(args)
        local kills = tonumber(args[1])
        if not kills or kills < 1 then
            print('Invalid number. Kills must be greater than 0')
            return
        end
        self.killsReq = kills
    end)
    sgame.RegisterVote('jugkills', { type = 'V_PUBLIC', target = 'T_OTHER' }, function(ent, team, args)
        local kills = tonumber(args[1])
        if not kills or kills < 1 then
            self:say(ent, 'Invalid number. Kills must be greater than 0')
            return false
        end
        return true, 'jug_req_kills ' .. kills, 'Set Juggernaut kills to win: ' .. kills
    end)

    Cmd.exec('lock a')
    self:addBots()
    print('Loaded lua...')
end

return Juggernaut
