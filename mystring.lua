local mystring = string

function mystring.trim(str)
    return str:gsub("^%s*(.-)%s*$", "%1")
end


function mystring.find_iter(str, sep, start)
    local start = start or 1
    return function ()
        local s, e = string.find(str, sep, start)
        if s and e then
            start = e + 1
            return s, e
        end
    end
end


function mystring.split(str, sep)
    if not sep then
        sep = "%s+"
        str = mystring.trim(str)
    end
    local res = {}

    local start = 1
    for s, e in mystring.find_iter(str, sep) do
        table.insert(res, string.sub(str, start, s-1))
        start = e + 1
    end
    table.insert(res, string.sub(str, start, #str))
    return res
end

return mystring
