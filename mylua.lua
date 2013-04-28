#!/usr/bin/env lua
-- load libs.
string = require("mystring")

for i,v in ipairs{...} do
    print(i,v)
end

local lua_keywords = {
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for',
    'function', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat',
    'return', 'then', 'true', 'until', 'while'
}

local function key_cmp(a, b)
    local at = type(a)
    local bt = type(b)
    if at == "number" then
        if bt == "number" then
            return a < b
        else
            return true
        end
    elseif at == "string" then
        if bt == "string" then
            return a < b
        elseif bt == "number" then
            return false
        else
            return true
        end
    else
        if bt == "string" or bt == "number" then
            return false
        else
            return tostring(a) < tostring(b)
        end
    end
end

-- v: the value to str
-- l: depth
-- p: parents
function tbl2str(v, l, p)
    l = l or 1/0
    p = p or {}
    for i,x in ipairs(p) do
        if v == x then
            return string.format("{#%d...}", #p + 1 - i)
        end
    end

    if l <= 0 then
        return string.format("{<%s>...}", tostring(v))
    end

    local keys = {}
    for k in pairs(v) do keys[#keys+1] = k end
    table.sort(keys, key_cmp)

    p[#p + 1] = v
    local res = {}
    for i,k in ipairs(keys) do
        local t = type(k)
        local kstr = ""
        local vstr = val2str(v[k], l-1, p)
        local pattern = "[%s]= %s"
        if t == "number" and k >= 1 then
            pattern = "%s%s"
        elseif t == "string" then
            kstr = k
            pattern = "%s= %s"
        else
            kstr = val2str(k, l-1, p)
        end
        res[#res + 1] = string.format(pattern, kstr, vstr)
    end
    p[#p] = nil

    local res_str = "{"..table.concat(res, ", ").."}"
    if #res_str > 80 then
        res_str = "{"..table.concat(res, ",\n").."}"
    end
    return res_str
end

-- v: the value to str
-- l: depth
function val2str(v, l)
    local t = type(v)
    if t == 'table' then
        return tbl2str(v,l)
    elseif t == 'string' then
        return '"'..v..'"'
    elseif t == 'number' or t == 'boolean' or t == 'nil' then
        return tostring(v)
    else
        return '<'..tostring(v)..'>'
    end
end

local function loadvalue(line)
    return load("return "..line)
end

function pt(v, l)
    print(val2str(v, l))
end

local myrl = require("myreadline")

myrl._set(function (word, line, startpos, endpos)
    -- Helper function registering possible completion words, verifying matches.
    local matches = {}
    local function add(value)
        value = tostring(value)
        if value:match("^" .. word) then
            table.insert(matches, value)
        end
    end

    -- This function does the same job as the default completion of readline,
    -- completing paths and filenames. Rewritten because
    -- rl_basic_word_break_characters is different.
    -- Uses LuaFileSystem (lfs) module for this task.
    local function filename_list(str)
        local path, name = str:match("(.*)[\\/]+(.*)")
        path = (path or ".") .. "/"
        name = name or str
        for f in lfs.dir(path) do
            if (lfs.attributes(path .. f) or {}).mode == 'directory' then
                add(f .. "/")
            else
                add(f)
            end
        end
    end

    -- This function is called in a context where a keyword or a global
    -- variable can be inserted. Local variables cannot be listed!
    local function add_globals()
        if #word == 0 then return end
        for _, k in ipairs(lua_keywords) do
            add(k)
        end
        for k in pairs(_G) do
            add(k)
            if startpos == 1 and type(_G[k]) == "function" then
                add("/"..k)
            end
        end
    end

    -- Main completion function. It evaluates the current sub-expression
    -- to determine its type. Currently supports tables fields, global
    -- variables and function prototype completion.
    local function contextual_list(expr, sep, str)
        if str then
            return filename_list(str)
        end
        if expr and expr ~= "" then
            local v = loadvalue(expr)
            if v then
                v = v()
                local t = type(v)
                if sep == '.' or sep == ':' then
                    if t == 'table' then
                        for k, v in pairs(v) do
                            if type(k) == 'string' and (sep ~= ':' or type(v) == "function") then
                                add(expr..sep..k)
                            end
                        end
                    end
                elseif sep == '[' then
                    if t == 'table' then
                        for k in pairs(v) do
                            if type(k) == 'number' then
                                add(k .. "]")
                            end
                        end
                    end
                end
            end
        end
        if #matches == 0 then
            --filename_list("")
            add_globals()
        end
    end

    -- This complex function tries to simplify the input line, by removing
    -- literal strings, full table constructors and balanced groups of
    -- parentheses. Returns the sub-expression preceding the word, the
    -- separator item ( '.', ':', '[', '(' ) and the current string in case
    -- of an unfinished string literal.
    local function simplify_expression(expr)
        -- Replace annoying sequences \' and \" inside literal strings
        expr = expr:gsub("\\(['\"])", function (c)
            return string.format("\\%03d", string.byte(c))
        end)
        local curstring
        -- Remove (finished and unfinished) literal strings
        while true do
            local idx1, _, equals = expr:find("%[(=*)%[")
            local idx2, _, sign = expr:find("(['\"])")
            if idx1 == nil and idx2 == nil then
                break
            end
            local idx, startpat, endpat
            if (idx1 or math.huge) < (idx2 or math.huge) then
                idx, startpat, endpat = idx1, "%[" .. equals .. "%[", "%]" .. equals .. "%]"
            else
                idx, startpat, endpat = idx2, sign, sign
            end
            if expr:sub(idx):find("^" .. startpat .. ".-" .. endpat) then
                expr = expr:gsub(startpat .. "(.-)" .. endpat, " STRING ")
            else
                expr = expr:gsub(startpat .. "(.*)", function (str)
                    curstring = str
                    return "(CURSTRING "
                end)
            end
        end
        expr = expr:gsub("%b()"," PAREN ") -- Remove groups of parentheses
        expr = expr:gsub("%b{}"," TABLE ") -- Remove table constructors
        -- Avoid two consecutive words without operator
        expr = expr:gsub("(%w)%s+(%w)","%1|%2")
        expr = expr:gsub("%s+", "") -- Remove now useless spaces
        -- This main regular expression looks for table indexes and function calls.
        return curstring, expr:match("([%.%w%[%]_]-)([:%.%[%(])" .. word .. "$")
    end

    -- Now call the processing functions and return the list of results.
    local str, expr, sep = simplify_expression(line:sub(1, endpos))
    contextual_list(expr, sep, str)
    return matches
end
)

local function cmd_func(cmd)
    return function(str)
        local cmds = {cmd, str}
        os.execute(table.concat(cmds, " "))
    end
end
-- globals
_G.In = {}
_G.Out = {}
_G._DEBUG = false
_G.myrl = myrl
_G.quit = function() myrl.writehistory();os.exit(0) end
_G.q = _G.quit
_G.pwd = cmd_func("pwd")
_G.ls = cmd_func("ls")
_G.cat = cmd_func("cat")
_G.cd = function(d) d = d or os.getenv("HOME"); myrl.chdir(d);pwd() end

local sc = require("strColor")
local prompt_in_pattern = sc.green("In [")..sc.green("%s",1)..sc.green("]: ", 0, 1)
local prompt_out_pattern = sc.red("Out[")..sc.red("%s",1)..sc.red("]: ", 0, 1)


local function get_out_prompt(res)
    Out[#In] = res
    return string.format(prompt_out_pattern, #In)
end

local function get_prompt(linenum)
    local raw_prompt = string.format("In [%d]: ", #In + 1)
    if linenum == 1 then
        return string.format(prompt_in_pattern, #In + 1)
    else
        local prompt = string.format("   %s ", string.rep(".", (#raw_prompt)-3-1))
        return sc.green(prompt, 0, 1)
    end
end

local function incomplete(msg)
    local EOFMARK = "<eof>"
    if #msg < #EOFMARK then return false end

    if EOFMARK == string.sub(msg, 1 + #msg - #EOFMARK, #msg) then
        return true
    end
    return false
end

local function loadfunction(line)
    if string.sub(line, 1, 1) == "," then
        local tokens = string.split(string.sub(line, 2, #line))
        local f = table.remove(tokens, 1)
        line = string.format("%s(%s)", f, table.concat(tokens, ","))
    elseif string.sub(line, 1, 1) == "/" then
        local tokens = string.split(string.sub(line, 2, #line))
        local f = table.remove(tokens, 1)
        if #tokens > 0 then
            line = string.format("%s('%s')", f, table.concat(tokens, " "))
        else
            line = string.format("%s()", f)
        end
    end
    return line
end

local function loadline()
    local oline, line, f, msg1, msg2
    local linenum = 1
    while true do
        local input = myrl.readline(get_prompt(linenum)) 
        --local input = myrl.readline(string.rep("#", linenum).." ") 
        if not input then
            return nil
        end
        if line then
            line = line.."\n"..input
        else
            line = input
        end
        oline = line
        -- check function call
        line = loadfunction(line)
        -- check value
        f, msg1 = loadvalue(line)
        if f then break end
        -- check statement
        f, msg2 = load(line)
        if f then break end

        -- check complete
        if not (incomplete(msg1) or incomplete(msg2)) then
            break
        end

        linenum = linenum + 1
    end
    myrl.addhistory(oline or line)
    In[#In+1] = oline or line
    return f,msg2
end


local function xxpcall(f, eh)
    res = {xpcall(f, eh)}
    status = table.remove(res, 1)
    if #res > 1 then
        return status, res
    else
        return status, res[1]
    end
end

local function eof_quit()
    io.write("\n")
    while true do
        io.write("Quit([y]/n)?")
        local r = io.read()
        if r == "y" then
            quit()
            break
        elseif r == 'n' then
            break
        end
    end
end

myrl.readhistory()
while true do
    local f,msg = loadline()
    if not f then
        if msg then print(msg)
        else
            eof_quit()
        end
    else
        local status, ret = xxpcall(f, debug.traceback)
        if status then
            if ret ~= nil then
                _G._ = ret
                print(string.format("%s%s", get_out_prompt(ret), val2str(ret)))
            end
        else
            print(ret)
        end
    end
    print()
end

