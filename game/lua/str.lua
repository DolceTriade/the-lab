local str = {}

function str.split(input, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for s in string.gmatch(input, '([^' .. sep .. ']+)') do
        table.insert(t, s)
    end
    return t
end

function str.join(input, sep)
    local s = ''
    local first = true
    for _, v in ipairs(input) do
        if first then
           first = false
        else
            s = s .. sep
        end
        s = s .. v
    end
end

return str
