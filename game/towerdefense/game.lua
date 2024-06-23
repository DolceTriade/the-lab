-- Globals
MAX_WAVE = 5
WAVE = 1
WAVE_DEATHS = 0

TARGET_KILLS = 100

STARTED = false

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
end

function EnableBuilding()
    Say(nil, '-- Building Allowed!')
    Cvar.set('g_disabledEquipment', '')
end

function DisableBuilding()
    Say(nil, '-- Building Not Allowed!')
    Cvar.set('g_disabledEquipment', 'ckit')
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
        Cvar.set(cvar, enable)
        if v then
            Cvar.set(cvar..'upg', enable)
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

function NextWave()
    if MAX_WAVE == WAVE then
        Cmd.exec('humanWin')
        return
    end

    local cmd = ''
    for i=0,64 do
        local ent = sgame.entity[i]
        if ent and ent.bot and ent.team == 'alien' then
            cmd = cmd .. 'bot del ' .. i .. '\n'
        end
    end
    Cmd.exec(cmd)

    WAVE = WAVE + 1
    WAVE_DEATHS = 0
    EnableBuilding()
    SayCP(nil, 'Wave ' .. WAVE .. ' starts in 60s!')
    Timer.add(60 * 1000, StartWave)
end

function StartWave()
    DisableBuilding()
    ForceBotEvo('level' .. WAVE)
    local cmd = ''
    for i=0,16 do
        cmd = cmd .. 'bot add * a 1 towerdefense\n'
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
    Cvar.set('g_instantBuilding', '1')
    Cvar.set('g_BPInitialBudgetHumans', '9999')
    Cvar.set('g_disabledEquipment', 'jetpack,firebomb')
    Cvar.set('g_disabledBuildables', 'reactor,telenode')
    Cvar.set('g_evolveAroundHumans', '-1')
    print('Loaded lua...')
end

Timer.add(1, init)
