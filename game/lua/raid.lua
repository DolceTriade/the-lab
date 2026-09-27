local chat = require('lua/chat.lua')
local cvars = require('lua/cvars.lua')
local difficulty = require('lua/difficulty.lua')
local str = require('lua/str.lua')
local math = require('math')
local lib = require('lua/lib.lua')
local boss = require('bots/boss.lua')

local Raid = {}
Raid.__index = Raid

local wf = sgame.workflow
local max = math.max
local floor = math.floor
local random = math.random

local TEAM_BOT_COUNT = 3
local BOT_COUNTS = {
    [difficulty.EASY] = 6,
    [difficulty.MEDIUM] = 9,
    [difficulty.HARD] = 14,
}
local BOSS_INTERVAL_MS = 10 * 60 * 1000
local BOSS_POOLS = {
    human = { 'flamer' },
    alien = { 'granger' },
}

local BASELINE_CVARS = {
    human = {
        g_BPInitialBudgetAliens = '2000',
        g_bot_buildCooldown = '4000',
        g_bot_defaultBehaviorAlien = 'pve',
    },
    alien = {
        g_BPInitialBudgetHumans = '2000',
        g_bot_buildCooldown = '4000',
        g_bot_defaultBehaviorHuman = 'pve',
    },
}

function Raid.new(options)
    options = options or {}
    assert(options.team == 'human' or options.team == 'alien', 'raid requires a player team')
    return setmetatable({
        team = options.team,
        pveTeam = options.team == 'alien' and 'human' or 'alien',
        difficulty = options.difficulty,
    }, Raid)
end

function Raid:waitFor()
    local match_time = sgame.level.match_time
    local start_time = 3 * 60 * 1000
    local target_time = 30 * 60 * 1000
    local target_wait = 30 * 1000
    local min_wait = 1000
    local target_ratio = target_wait / start_time
    local progress = match_time / target_time
    local calculated_wait = start_time * (target_ratio ^ progress)
    return floor(max(calculated_wait, min_wait))
end

function Raid:upgradesWorkflow()
    local function giveMoneyH(ent, amount)
        ent.client.credits = ent.client.credits + amount
    end

    local function giveMoneyA(ent, amount)
        ent.client.evos = ent.client.evos + amount / 200
    end

    local giveMoney = self.pveTeam == 'alien' and giveMoneyA or giveMoneyH
    while true do
        wf.wait_ms(self:waitFor())
        for ent in lib.AllPlayers() do
            if ent ~= nil and ent.client ~= nil and ent.team == self.pveTeam then
                giveMoney(ent, 600)
            end
        end
    end
end

function Raid:randomBoss()
    local pool = BOSS_POOLS[self.pveTeam]
    assert(pool ~= nil and #pool > 0)
    return pool[random(#pool)]
end

function Raid:bossesWorkflow()
    for _ = 1, 3 do
        wf.wait_ms(BOSS_INTERVAL_MS)
        chat.GlobalCP(str.ucfirst(self.pveTeam) .. ' boss incoming!')
        boss.add(self:randomBoss())
    end
end

function Raid:start()
    chat.GlobalCP('Starting ' .. str.ucfirst(self.team) .. ' raid mode!')
    local configs = BASELINE_CVARS[self.team]
    local inactiveTeam = self.pveTeam
    local minimumBots = BOT_COUNTS[self.difficulty or difficulty.MEDIUM]
    self.balanceBots = lib.RegisterBotBalanceHook(inactiveTeam, minimumBots)

    Cmd.exec(('lock %s;bot del all'):format(inactiveTeam))
    for i = 0, sgame.level.max_clients do
        local ent = sgame.entity[i]
        if ent and ent.client and ent.team == inactiveTeam then
            ent.client:forceteam(self.team)
        end
    end

    Cmd.exec(('bot fill %d %s'):format(TEAM_BOT_COUNT, self.team))
    for k, v in pairs(configs) do
        cvars.set(k, v)
    end
    Cmd.exec(('bot fill %d %s'):format(minimumBots, inactiveTeam))
    self.balanceBots()

    wf.run(function() self:upgradesWorkflow() end)
    wf.run(function() self:bossesWorkflow() end)
end

return Raid
