
Cmd.exec('lua -f lua/common.lua')
local game = Cvar.get('lua_gamemode')
if game and game ~= '' then
    Cvar.set('lua_gamemode', '')
    Cmd.exec('lua -f ' .. game)
else
    Cmd.exec('bot fill 4')
end
