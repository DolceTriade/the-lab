local chat = require('lua/chat.lua')
local cvars = require('lua/cvars.lua')
local str = require('lua/str.lua')
local math = require('math')
local lib = require('lua/lib.lua')
local boss = require('bots/boss.lua')
local max = math.max
local floor = math.floor
local random = math.random

local M = {}
local wf = sgame.workflow
local overload = sgame.overload
local level = sgame.level

local TEAM_BOT_COUNT = 3
local PVE_BOT_COUNT = 9
local BOSS_INTERVAL_MS = 10 * 60 * 1000
local BOSS_POOLS = {
    ['human'] = { 'flamer' },
    ['alien'] = { 'granger' },
}

local BASELINE_CVARS = {
    ['human'] = {
        g_BPInitialBudgetAliens = '2000',
        g_bot_buildCooldown = '4000',
        g_bot_defaultBehaviorAlien = 'pve',
    },
    ['alien'] = {
        g_BPInitialBudgetHumans = '2000',
        g_bot_buildCooldown = '4000',
        g_bot_defaultBehaviorHuman = 'pve',
    }
}

local STATE = {
    ['team'] = '',
    ['pveTeam'] = '',
}

local function wait_for()
    local match_time = sgame.level.match_time

    -- Define configuration constants in milliseconds
    local START_TIME  = 3 * 60 * 1000   -- 3 minutes (180,000 ms)
    local TARGET_TIME = 30 * 60 * 1000  -- 20 minutes (1,200,000 ms)
    local TARGET_WAIT = 30 * 1000       -- 30 seconds (30,000 ms)
    local MIN_WAIT    = 1000            -- 1 second floor (stops division by zero / lag)

    -- Calculate the ratio between what we want at target time vs start time
    -- 30,000 / 180,000 = 0.1666...
    local target_ratio = TARGET_WAIT / START_TIME

    -- Calculate how far along we are relative to the 20-minute mark
    local progress = match_time / TARGET_TIME

    -- Exponential decay calculation
    local calculated_wait = START_TIME * (target_ratio ^ progress)

    -- Enforce a minimum floor so the loop never freezes with a 0ms wait
    return floor(max(calculated_wait, MIN_WAIT))
end

local function upgrades_wf()
    function giveMoneyH(ent, amt)
        local client = ent.client
        client.credits = client.credits + amt
    end

    function giveMoneyA(ent, amt)
        amt = amt / 200
        local client = ent.client
        client.evos = client.evos + amt
    end

    local team = STATE['pveTeam']
    local giveMoney = team == 'alien' and giveMoneyA or giveMoneyH

    while true do
        local wait_time = wait_for()
        wf.wait_ms(wait_time)
        for ent in lib.AllPlayers() do
            if ent ~= nil and ent.client ~= nil and ent.team == team then
                giveMoney(ent, 600)
            end
        end

    end
end

local function random_boss(team)
    local pool = BOSS_POOLS[team]
    assert(pool ~= nil and #pool > 0)
    return pool[random(#pool)]
end

local function bosses_wf()
    local team = STATE['pveTeam']

    for _ = 1, 3 do
        wf.wait_ms(BOSS_INTERVAL_MS)
        chat.GlobalCP(str.ucfirst(team) .. ' boss incoming!')
        boss.add(random_boss(team))
    end
end

function M.start(team)
    chat.GlobalCP('Starting ' .. str.ucfirst(team) .. ' raid mode!')
    local configs = BASELINE_CVARS[team]
    assert(configs ~= nil)
    local inactiveTeam = team == 'alien' and 'human' or 'alien'
    Cmd.exec(('lock %s;bot del all'):format(inactiveTeam))

    for i = 0, sgame.level.max_clients do
        local ent = sgame.entity[i]
        if ent and ent.client and ent.team == inactiveTeam then
            ent.client:forceteam(team)
        end
    end

    Cmd.exec(('bot fill %d %s'):format(TEAM_BOT_COUNT, team))

    for k, v in pairs(configs) do
        cvars.set(k, v)
    end

    Cmd.exec(('bot fill %d %s'):format(PVE_BOT_COUNT, inactiveTeam))
    STATE['team'] = team
    STATE['pveTeam'] = inactiveTeam

    wf.run(upgrades_wf)
    wf.run(bosses_wf)
end

return M
