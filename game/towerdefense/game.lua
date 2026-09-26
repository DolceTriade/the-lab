local str = require('lua/str.lua')
local cvars = require('lua/cvars.lua')

local TowerDefense = {}
TowerDefense.__index = TowerDefense

local MAX_WAVE = 5
local TARGET_KILLS = 100

function TowerDefense.new(options)
    options = options or {}
    return setmetatable({
        wave = 1,
        waveDeaths = 0,
        started = false,
        cvarReset = {},
        difficulty = options.difficulty,
    }, TowerDefense)
end

function TowerDefense:say(ent, txt)
    local num = ent and ent.number or -1
    sgame.SendServerCommand(num, 'print ' .. '"^2Tower Defense^*: ' .. txt .. '"')
end

function TowerDefense:cp(ent, txt)
    local num = ent and ent.number or -1
    sgame.SendServerCommand(num, 'cp ' .. '"' .. txt .. '"')
end

function TowerDefense:sayCP(ent, txt)
    self:cp(ent, txt)
    self:say(ent, txt)
end

function TowerDefense:lockTeam(team)
    Cmd.exec('lock ' .. team)
end

function TowerDefense:welcomeClient(ent, connect)
    if connect then
        self:cp(ent, 'Welcome to Tower Defense!')
    end
end

function TowerDefense:startGame(ent, team)
    if team == 'alien' or self.started then
        return
    end
    self.started = true
    self:sayCP(nil, 'Game starts now! You have 5 minutes to build!')
    Timer.add(5 * 60 * 1000, function() self:startWave() end)
    Timer.add(4 * 60 * 1000, function() self:sayCP(nil, '60 seconds before 1st wave!') end)
end

function TowerDefense:setAvailableEquipment(equip)
    local current = Cvar.get('g_disabledEquipment')
    local disabled = {}
    for _, item in ipairs(str.split(current, ',')) do
        disabled[item] = false
    end
    for item, enabled in pairs(equip) do
        if enabled then
            disabled[item] = nil
        else
            disabled[item] = enabled
        end
    end

    local value = ''
    for item, enabled in pairs(disabled) do
        if not enabled then
            value = value .. item .. ','
        end
    end
    cvars.set('g_disabledEquipment', value:sub(1, -2))
end

function TowerDefense:enableBuilding()
    self:say(nil, '-- Building Allowed!')
    self:setAvailableEquipment({ ckit = true })
end

function TowerDefense:disableBuilding()
    self:say(nil, '-- Building Not Allowed!')
    self:setAvailableEquipment({ ckit = false })
    for i = 0, sgame.level.max_clients do
        local ent = sgame.entity[i]
        if ent and ent.client and ent.client.weapon == 'ckit' then
            ent.client:forceweapon('rifle')
        end
    end
end

function TowerDefense:forceBotEvo(level)
    local classes = {
        level1 = false,
        level2 = true,
        level3 = true,
        level4 = false,
    }
    for class, enabledForClass in pairs(classes) do
        local enabled = level == class and '1' or '0'
        local cvar = 'g_bot_' .. class
        cvars.set(cvar, enabled)
        self.cvarReset[cvar] = true
        if enabledForClass then
            cvars.set(cvar .. 'upg', enabled)
            self.cvarReset[cvar .. 'upg'] = true
        end
    end
end

function TowerDefense:setupAlienBase()
    local eggs = {}
    for _, ent in pairs(sgame.entity) do
        if ent.team == 'alien' and ent.buildable ~= nil then
            ent.buildable.god = true
            if ent.buildable.name == 'eggpod' then
                eggs[#eggs + 1] = ent
            end
        end
    end

    local numEggs = 16
    if #eggs == 0 then
        print('Tower Defense map has no alien eggpods')
        return
    end
    local eggsPerEgg = math.floor(numEggs / #eggs)
    print('Using ' .. eggsPerEgg .. ' eggs per egg')
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
end

function TowerDefense:countDeaths(ent)
    if not ent or ent.team ~= 'alien' then
        return
    end
    self.waveDeaths = self.waveDeaths + 1
    if self.waveDeaths % 5 == 0 then
        self:say(nil, 'Kills: ' .. self.waveDeaths .. ' / ' .. TARGET_KILLS)
    end
    if self.waveDeaths == TARGET_KILLS then
        self:nextWave()
    end
end

function TowerDefense:playerSpawn(ent)
    if not ent then
        return
    end
    if ent.team == 'alien' then
        ent.client.evos = 20
        ent.die = function(...) self:countDeaths(...) end
    end
end

function TowerDefense:deleteAlienBots()
    local cmd = ''
    for i = 0, sgame.level.max_clients do
        local ent = sgame.entity[i]
        if ent and ent.bot and ent.team == 'alien' then
            cmd = cmd .. 'bot del ' .. i .. '\n'
        end
    end
    Cmd.exec(cmd)
end

function TowerDefense:nextWave()
    self:deleteAlienBots()
    if MAX_WAVE == self.wave then
        Cmd.exec('humanWin')
        return
    end

    self.wave = self.wave + 1
    self.waveDeaths = 0
    self:enableBuilding()
    self:sayCP(nil, 'Wave ' .. self.wave .. ' starts in 60s!')
    Timer.add(60 * 1000, function() self:startWave() end)
    Timer.add(50 * 1000, function() self:sayCP(nil, 'Wave ' .. self.wave .. ' starts in 10s!') end)
end

function TowerDefense:startWave()
    self:disableBuilding()
    self:forceBotEvo('level' .. self.wave)
    local cmd = ''
    for _ = 0, 16 do
        cmd = cmd .. 'bot add * a 5 towerdefense\n'
    end
    Cmd.exec(cmd)
    sgame.level.aliens.momentum = 300
end

function TowerDefense:start()
    sgame.hooks.RegisterClientConnectHook(function(...) self:welcomeClient(...) end)
    sgame.hooks.RegisterPlayerSpawnHook(function(...) self:playerSpawn(...) end)
    sgame.hooks.RegisterTeamChangeHook(function(...) self:startGame(...) end)

    self:setupAlienBase()
    self:lockTeam('a')
    cvars.set('g_instantBuilding', '1')
    cvars.set('g_BPInitialBudgetHumans', '9999')
    self:setAvailableEquipment({ jetpack = false, firebomb = false })
    cvars.set('g_disabledBuildables', 'reactor,telenode')
    cvars.set('g_evolveAroundHumans', '-1')
    print('Loaded lua...')
end

return TowerDefense
