local chat = {}

function chat.Say(ent, txt)
    local num = -2
    if ent then
        num = ent.number
    end
    sgame.SendServerCommand(num, 'print "' .. txt .. '"')
end

function chat.GlobalSay(txt)
    sgame.SendServerCommand(-1, 'print "' .. txt .. '"')
end

function chat.CP(ent, txt)
    local num = -2
    if ent then
        num = ent.number
    end
    sgame.SendServerCommand(num, 'cp ' .. '"' .. txt .. '"')
end

function chat.GlobalCP(txt)
    sgame.SendServerCommand(-1, 'cp ' .. '"' .. txt .. '"')
end


function chat.SayCP(ent, txt)
    chat.CP(ent, txt)
    chat.Say(ent, txt)
end

return chat
