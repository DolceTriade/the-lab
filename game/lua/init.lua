local mode = require('lua/mode.lua')
local difficulty = require('lua/difficulty.lua')

Cmd.exec('lua -f lua/common.lua')
local game = mode.Mode()
if game and game ~= '' then
    Timer.add(1, function()
        local modeClass = require(game)
        local instance = modeClass.new({
            team = mode.Team(),
            difficulty = difficulty.GetDifficulty(),
        })
        instance:start()
    end)
else
    Cmd.exec('bot fill 5')
end
