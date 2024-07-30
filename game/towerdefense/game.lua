-- Globals
local str = require('lua/str.lua')
local cvars = require('lua/cvars.lua')

MAX_WAVE = 5
WAVE = 1
WAVE_DEATHS = 0

TARGET_KILLS = 100

STARTED = false

CVAR_RESET = {}

function Say(ent, txt)
    local num = -1
    if ent ~= nil then
        num = ent.number
    end
    sgame.SendServerCommand(num, 'print ' .. '"^2Tower Defense^*: ' .. txt .. '"')
end

function CP(ent, txt)
    local num = -1
    if ent ~= nil then
        num = ent.number
    end
    sgame.SendServerCommand(num, 'cp ' .. '"' .. txt .. '"')
end

function SayCP(ent, txt)
    CP(ent, txt)
    Say(ent, txt)
end

function LockTeam(team)
    Cmd.exec('lock ' .. team)
end

function SameEnt(a, b)
    if a == nil or b == nil then
        return false
    end
    return a.number == b.number
end

function WelcomeClient(ent, connect)
    if not connect then
        return
    end
    CP(ent, 'Welcome to Tower Defense!')
end

function StartGame(ent, team)
    if team == 'alien' then
        return
    end
    if STARTED then
        return
    end
    STARTED = true
    SayCP(nil, 'Game starts now! You have 5 minutes to build!')
    Timer.add(5 * 60 * 1000, StartWave)
    Timer.add(4 * 60 * 1000, function() SayCP(nil, '60 seconds before 1st wave!') end)
end

function SetAvailableEquipment(equip)
    local e = Cvar.get('g_disabledEquipment')
    local tarr = str.split(e, ',')
    local t = {}
    for _, p in ipairs(tarr) do
        print('tarr', p)
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
    cvars.set('g_disabledEquipment', val)
end

function EnableBuilding()
    Say(nil, '-- Building Allowed!')
    SetAvailableEquipment({ckit=true})
end

function DisableBuilding()
    Say(nil, '-- Building Not Allowed!')
    SetAvailableEquipment({ckit=false})
    for i=0,sgame.level.max_clients do
        ent = sgame.entity[i]
        if ent and ent.client and ent.client.weapon == 'ckit' then
            ent.client:forceweapon('rifle')
        end
    end
end

function ForceBotEvo(level)
    local classes = {
        level1 = false,
        level2 = true,
        level3 = true,
        level4 = false,
    }
    for k, v in pairs(classes) do
        local enable = level == k and '1' or '0'
        print(k, v, level, enable)
        local cvar = 'g_bot_' .. k
        cvars.set(cvar, enable)
        CVAR_RESET[cvar] = true
        if v then
            cvars.set(cvar..'upg', enable)
            CVAR_RESET[cvar .. 'upg'] = true
        end
    end
end

function SetupAlienBase()
    local eggs = {}
    for _, ent in pairs(sgame.entity) do
        if ent.team == 'alien' and ent.buildable ~= nil then
            ent.buildable.god = true
            if ent.buildable.name == 'eggpod' then
                eggs[#eggs+1] = ent
            end
        end
    end
    local num_eggs = 16
    local eggs_per_egg = math.floor(num_eggs / #eggs)
    print('Using ' .. eggs_per_egg .. ' eggs per egg')
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
end

function CountDeaths(self, inflictor, attacker, mod)
    if self == nil then
        return
    end

    if self.team == 'alien' then
        WAVE_DEATHS = WAVE_DEATHS + 1
    end

    if WAVE_DEATHS % 5 == 0 then
        Say(nil, 'Kills: ' .. WAVE_DEATHS .. ' / ' .. TARGET_KILLS)
    end

    if WAVE_DEATHS == TARGET_KILLS then
        NextWave()
    end
end

function PlayerSpawn(ent)
    if not ent then
        return
    end

    if ent.team == 'alien' then
        ent.client.evos = 20
        ent.die = CountDeaths
    end
end

function DeleteAlienBots()
    local cmd = ''
    for i=0,sgame.level.max_clients do
        local ent = sgame.entity[i]
        if ent and ent.bot and ent.team == 'alien' then
            cmd = cmd .. 'bot del ' .. i .. '\n'
        end
    end
    Cmd.exec(cmd)
end

function NextWave()
    DeleteAlienBots()
    if MAX_WAVE == WAVE then
        Cmd.exec('humanWin')
        return
    end

    WAVE = WAVE + 1
    WAVE_DEATHS = 0
    EnableBuilding()
    SayCP(nil, 'Wave ' .. WAVE .. ' starts in 60s!')
    Timer.add(60 * 1000, StartWave)
    Timer.add(50 * 1000, function() SayCP(nil, 'Wave ' .. WAVE .. ' starts in 10s!') end)
end

function StartWave()
    DisableBuilding()
    ForceBotEvo('level' .. WAVE)
    local cmd = ''
    for i=0,16 do
        cmd = cmd .. 'bot add * a 5 towerdefense\n'
    end
    Cmd.exec(cmd)
    sgame.level.aliens.momentum = 300
end

function init()
    sgame.hooks.RegisterClientConnectHook(WelcomeClient)
    sgame.hooks.RegisterPlayerSpawnHook(PlayerSpawn)
    sgame.hooks.RegisterTeamChangeHook(StartGame)
    SetupAlienBase()
    LockTeam('a')
    cvars.set('g_instantBuilding', '1')
    cvars.set('g_BPInitialBudgetHumans', '9999')
    SetAvailableEquipment({jetpack=false, firebomb=false})
    cvars.set('g_disabledBuildables', 'reactor,telenode')
    cvars.set('g_evolveAroundHumans', '-1')
    print('Loaded lua...')
end

Timer.add(1, init)
