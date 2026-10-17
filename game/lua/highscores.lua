local difficulty = require('lua/difficulty.lua')
local json = require('lua/json.lua')
local lib = require('lua/lib.lua')
local mode = require('lua/mode.lua')

local M = {}

local MAX_RESULTS = 3
local playerNames
local formatDateTime
local HighscorePolicy = {}
HighscorePolicy.__index = HighscorePolicy

function HighscorePolicy:Compare(score, other)
    return score > other
end

function HighscorePolicy:Delta(a, b)
    return math.abs(a - b)
end

function HighscorePolicy:FormatHighscore(score)
    return tostring(score)
end

function HighscorePolicy:FormatDelta(delta)
    return tostring(delta)
end

function HighscorePolicy:FormatResult(names, highscore)
    return ('%s scored %s'):format(names, highscore)
end

function HighscorePolicy:FormatAnnouncement(report)
    local names = playerNames(report.players)
    local score = self:FormatHighscore(report.score)
    if report.initial then
        return self:FormatResult(names, score) .. ', setting the first record!'
    elseif report.entered then
        local message = ('%s, ranking #%d'):format(self:FormatResult(names, score), report.rank)
        if report.improvement then
            message = message .. (' (%s improvement)')
                :format(self:FormatDelta(report.improvement))
        end
        if report.rank > 1 then
            message = message .. ('; %s behind #1'):format(self:FormatDelta(report.gapToFirst))
        end
        return message .. '!'
    end
    return ('%s, %s behind #1.'):format(self:FormatResult(names, score),
        self:FormatDelta(report.gapToFirst))
end

local BestPoints = setmetatable({}, { __index = HighscorePolicy })
BestPoints.__index = BestPoints

function BestPoints.new()
    return setmetatable({}, BestPoints)
end

function BestPoints:FormatHighscore(score)
    return tostring(score) .. ' points'
end

function BestPoints:FormatDelta(delta)
    return tostring(delta) .. ' points'
end

local BestTime = setmetatable({}, { __index = HighscorePolicy })
BestTime.__index = BestTime

function BestTime.new()
    return setmetatable({}, BestTime)
end

function BestTime:Compare(score, other)
    return score < other
end

function BestTime:FormatResult(names, highscore)
    return ('%s beat in %s'):format(names, highscore)
end

local function formatTime(milliseconds)
    local totalSeconds = math.floor(math.max(tonumber(milliseconds) or 0, 0) / 1000)
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor(totalSeconds / 60) % 60
    local seconds = totalSeconds % 60
    if hours > 0 then
        return ('%d:%02d:%02d'):format(hours, minutes, seconds)
    end
    return ('%02d:%02d'):format(minutes, seconds)
end

function BestTime:FormatHighscore(milliseconds)
    return formatTime(milliseconds)
end

function BestTime:FormatDelta(milliseconds)
    return formatTime(milliseconds)
end

local BestWaveCount = setmetatable({}, { __index = HighscorePolicy })
BestWaveCount.__index = BestWaveCount

function BestWaveCount.new()
    return setmetatable({}, BestWaveCount)
end

function BestWaveCount:FormatHighscore(waves)
    return ('Wave %s'):format(tostring(waves))
end

function BestWaveCount:FormatResult(names, highscore)
    return ('%s reached %s'):format(names, highscore)
end

function BestWaveCount:FormatDelta(waves)
    return ('%s waves'):format(tostring(waves))
end

M.HighscorePolicy = HighscorePolicy
M.BestPoints = BestPoints
M.BestTime = BestTime
M.BestWaveCount = BestWaveCount

local GAMEMODE_NAMES = {
    ['lua/pve.lua'] = 'PVE',
    ['lua/raid.lua'] = 'Raid',
}

local function teamName(team)
    if team == 'human' or team == 'humans' then
        return 'humans'
    elseif team == 'alien' or team == 'aliens' then
        return 'aliens'
    end
    return nil
end

local function load(map)
    local ok, contents = pcall(File.read, 'highscores/' .. map .. '.json')
    if not ok then return {} end
    local success, result = pcall(json.decode, contents)
    return success and type(result) == 'table' and result or {}
end

local function currentDifficulty()
    return difficulty.DifficultyString(difficulty.GetDifficulty())
end

playerNames = function(players)
    local names = {}
    if type(players) ~= 'table' then return 'No players' end
    for _, player in ipairs(players) do
        if type(player) == 'table' and player.name and player.name ~= '' then
            names[#names + 1] = player.name .. '^*'
        end
    end
    return #names > 0 and table.concat(names, ', ') or 'No players'
end

local function sortedKeys(value)
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

local function safeText(value)
    return tostring(value or ''):gsub('[%z\1-\31"\\]', '')
end

local function safeColorText(value)
    return safeText(value) .. '^*'
end

formatDateTime = function(timestamp)
    if type(timestamp) ~= 'number' then return nil end
    local ok, result = pcall(os.date, '!%Y-%m-%d %H:%M:%S UTC', timestamp)
    return ok and result or nil
end

function M.FormatTime(milliseconds)
    return formatTime(milliseconds)
end

function M.FormatMap(map)
    if type(map) ~= 'string' or not map:match('^[%w_%-]+$') then return nil end
    local data = load(map)
    local lines = { 'High scores on ' .. map .. ':' }
    local found = false
    for _, gamemode in ipairs(sortedKeys(data)) do
        local difficulties = data[gamemode]
        if type(difficulties) == 'table' then
            for _, selectedDifficulty in ipairs(sortedKeys(difficulties)) do
                local teams = difficulties[selectedDifficulty]
                if type(teams) == 'table' then
                    for _, team in ipairs(sortedKeys(teams)) do
                        local layouts = teams[team]
                        if type(layouts) == 'table' then
                            for _, layout in ipairs(sortedKeys(layouts)) do
                                local results = layouts[layout]
                                if type(results) == 'table' then
                                    local validResult = false
                                    for rank, entry in ipairs(results) do
                                        if rank <= MAX_RESULTS and type(entry) == 'table'
                                            and tonumber(entry.highscore) then
                                            validResult = true
                                            break
                                        end
                                    end
                                    if validResult then
                                        lines[#lines + 1] = ('%s / %s / %s / %s')
                                            :format(safeColorText(GAMEMODE_NAMES[gamemode] or gamemode),
                                                safeColorText(selectedDifficulty), safeColorText(team),
                                                safeColorText(layout))
                                        found = true
                                    end
                                    for rank, entry in ipairs(results) do
                                        if rank <= MAX_RESULTS and type(entry) == 'table'
                                            and tonumber(entry.highscore) then
                                            local prettyHighscore = entry.prettyHighscore
                                                or BestPoints.new():FormatHighscore(tonumber(entry.highscore))
                                            local achievedAt = formatDateTime(entry.achievedAt)
                                            local dateSuffix = achievedAt and ('  (' .. achievedAt .. ')') or ''
                                            lines[#lines + 1] = ('  #%d  %s  %s%s')
                                                :format(rank, safeColorText(prettyHighscore),
                                                    playerNames(entry.players):gsub('[%z\1-\31"\\]', ''),
                                                    dateSuffix)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if not found then lines[2] = 'No high scores recorded for this map.' end
    return lines
end

function M.FormatReport(report)
    if type(report) ~= 'table' then return nil end
    local policy = report.policy or BestPoints.new()
    return policy:FormatAnnouncement(report)
end

function M.CapturePlayers(team)
    local normalized = teamName(team)
    if not normalized then return {} end
    local players = {}
    for ent in lib.AllPlayers() do
        if ent and ent.client and not ent.bot and teamName(ent.team) == normalized then
            players[#players + 1] = { name = ent.client.name, guid = ent.client.guid }
        end
    end
    return players
end

function M.Record(team, score, policy)
    local normalized = teamName(team)
    score = tonumber(score)
    if not normalized or not score then return false end
    if type(policy) ~= 'table' or type(policy.Compare) ~= 'function'
        or type(policy.Delta) ~= 'function' or type(policy.FormatHighscore) ~= 'function'
        or type(policy.FormatDelta) ~= 'function' then
        policy = BestPoints.new()
    end
    local map = Cvar.get('mapname')
    local gamemode = mode.Mode()
    local layout = Cvar.get('layout')
    if not map or map == '' or not gamemode or gamemode == '' then return false end
    layout = layout ~= '' and layout or 'builtin'

    local data = load(map)
    if type(data[gamemode]) ~= 'table' then data[gamemode] = {} end
    local selectedDifficulty = currentDifficulty()
    if type(data[gamemode][selectedDifficulty]) ~= 'table' then
        data[gamemode][selectedDifficulty] = {}
    end
    if type(data[gamemode][selectedDifficulty][normalized]) ~= 'table' then
        data[gamemode][selectedDifficulty][normalized] = {}
    end
    local bucket = data[gamemode][selectedDifficulty][normalized]
    if type(bucket[layout]) ~= 'table' then bucket[layout] = {} end
    local results = bucket[layout]
    for index = #results, 1, -1 do
        local entry = results[index]
        if type(entry) ~= 'table' or tonumber(entry.highscore) == nil or type(entry.players) ~= 'table' then
            table.remove(results, index)
        else
            entry.highscore = tonumber(entry.highscore)
        end
    end
    local players = M.CapturePlayers(normalized)
    local previousFirst = results[1] and results[1].highscore or nil
    local achievedAt = os.time()
    local result = {
        highscore = score,
        prettyHighscore = policy:FormatHighscore(score),
        achievedAt = achievedAt,
        players = players,
    }
    local index = #results + 1
    while index > 1 and policy:Compare(score, results[index - 1].highscore) do index = index - 1 end
    local entered = index <= MAX_RESULTS
    local previousRankScore = entered and results[index] and results[index].highscore or nil
    local gapToFirst = previousFirst and (index > 1 and policy:Delta(score, previousFirst) or nil)
        or nil
    local improvement = previousRankScore and policy:Delta(score, previousRankScore) or nil
    if entered then
        table.insert(results, index, result)
        while #results > MAX_RESULTS do table.remove(results) end
        pcall(File.write, 'highscores/' .. map .. '.json', json.encode(data))
    end
    return {
        score = score,
        prettyHighscore = policy:FormatHighscore(score),
        achievedAt = achievedAt,
        players = players,
        policy = policy,
        rank = index,
        entered = entered,
        previousRankScore = previousRankScore,
        improvement = improvement,
        previousFirst = previousFirst,
        gapToFirst = gapToFirst,
        initial = previousFirst == nil,
    }
end

return M
