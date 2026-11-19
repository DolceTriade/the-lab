local chat = require('lua/chat.lua')
local cvars = require('lua/cvars.lua')
local difficulty = require('lua/difficulty.lua')
local highscores = require('lua/highscores.lua')
local lib = require('lua/lib.lua')
local math = require('math')
local bestTime = highscores.BestTime.new()

local PVE = {}
PVE.__index = PVE

local PLAYER_BOT_COUNT = 3
local wf = sgame.workflow
local max = math.max
local floor = math.floor
local BOT_COUNTS = {
    [difficulty.EASY] = 6,
    [difficulty.MEDIUM] = 9,
    [difficulty.HARD] = 14,
}
local FREE_MONEY_INTERVALS = {
    [difficulty.EASY] = { start = 60 * 1000, target = 60 * 1000, money = 200 },
    [difficulty.MEDIUM] = { start = 60 * 1000, target = 60 * 1000, money = 400 },
    [difficulty.HARD] = { start = 60 * 1000, target = 60 * 1000, money = 600 },
}

local CONFIGS = {
    alien = {
        playerTeam = 'alien',
        botTeam = 'human',
        budgetCvar = 'g_BPInitialBudgetHumans',
        behaviorCvar = 'g_bot_defaultBehaviorHuman',
        message = 'Starting Alien PVE mode!',
    },
    human = {
        playerTeam = 'human',
        botTeam = 'alien',
        budgetCvar = 'g_BPInitialBudgetAliens',
        behaviorCvar = 'g_bot_defaultBehaviorAlien',
        message = 'Starting Human PVE mode!',
    },
}

function PVE.new(options)
    options = options or {}
    assert(CONFIGS[options.team] ~= nil, 'pve requires a player team')
    return setmetatable({
        team = options.team,
        difficulty = options.difficulty,
    }, PVE)
end

function PVE:movePlayers()
    local config = CONFIGS[self.team]
    for i = 0, sgame.level.max_clients do
        local ent = sgame.entity[i]
        if ent and ent.client and ent.team ~= config.playerTeam and ent.team ~= 'spectator' then
            ent.client:forceteam(config.playerTeam)
        end
    end
end

function PVE:waitFor()
    local match_time = sgame.level.match_time
    local interval = FREE_MONEY_INTERVALS[self.difficulty or difficulty.MEDIUM]
        or FREE_MONEY_INTERVALS[difficulty.MEDIUM]
    local start_time = interval.start
    local target_time = 30 * 60 * 1000
    local target_wait = interval.target
    local min_wait = 1000
    local target_ratio = target_wait / start_time
    local progress = match_time / target_time
    local calculated_wait = start_time * (target_ratio ^ progress)
    return floor(max(calculated_wait, min_wait))
end

function PVE:upgradesWorkflow()
    local function giveMoneyH(ent, amount)
        ent.client.credits = ent.client.credits + amount
    end

    local function giveMoneyA(ent, amount)
        ent.client.evos = ent.client.evos + amount / 200
    end

    local botTeam = CONFIGS[self.team].botTeam
    local giveMoney = botTeam == 'alien' and giveMoneyA or giveMoneyH
    local interval = FREE_MONEY_INTERVALS[self.difficulty or difficulty.MEDIUM]
        or FREE_MONEY_INTERVALS[difficulty.MEDIUM]

    while true do
        wf.wait_ms(self:waitFor())
        for ent in lib.AllPlayers() do
            if ent ~= nil and ent.client ~= nil and ent.team == botTeam then
                giveMoney(ent, interval.money)
            end
        end
    end
end

function PVE:start()
    local config = CONFIGS[self.team]
    local minimumBots = BOT_COUNTS[self.difficulty or difficulty.MEDIUM]
    cvars.set('lua_pve_max_builders', self.difficulty == difficulty.EASY and '2' or '3')
    self.balanceBots = lib.RegisterBotBalanceHook(config.botTeam, minimumBots)

    self:movePlayers()

    Cmd.exec('time 300')
    cvars.set(config.budgetCvar, '1000')
    cvars.set(config.behaviorCvar, 'pve')
    cvars.set('g_bot_buildCooldown', '4000')

    Cmd.exec(('lock %s;bot del all'):format(config.botTeam))
    Cmd.exec(('bot fill %d %s'):format(PLAYER_BOT_COUNT, config.playerTeam))
    Cmd.exec(('bot fill %d %s'):format(minimumBots, config.botTeam))
    Cmd.exec('lock ' .. config.botTeam)
    self.balanceBots()
    wf.run(function() self:upgradesWorkflow() end)
    local modeName = self.team == 'human' and 'Human PVE' or 'Alien PVE'
    self.publishScoreboard = highscores.RegisterScoreboard(modeName, config.playerTeam, bestTime)
    chat.GlobalCP(config.message)
    sgame.hooks.RegisterGameEndNotificationHook(function(team)
        if team == config.playerTeam or team == config.playerTeam .. 's' then
            local elapsed = sgame.level.match_time
            local report = highscores.Record(team, elapsed, bestTime)
            local message = highscores.FormatReport(report)
            if message then chat.GlobalSay(message) end
            self.publishScoreboard('all')
        end
    end)
end

return PVE
