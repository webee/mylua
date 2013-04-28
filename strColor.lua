local strColor = {}
local _c = {
    F_BLACK=30,
    F_RED=31,
    F_GREEN=32,
    F_YELLOW=33,
    F_BLUE=34,
    F_MAGENTA=35,
    F_CYAN=36,
    F_WHITE=37,
    B_BLACK=30,
    B_RED=31,
    B_GREEN=32,
    B_YELLOW=33,
    B_BLUE=34,
    B_MAGENTA=35,
    B_CYAN=36,
    B_WHITE=37,

    DEF=0,
    HLT=1,
    UDL=4,
    BLK=5,
    RWC=7,
    NTS=8,
}


local DEFAULT="\001\027[0m\002"
local PATTERN="\001\027[%d;%d;%dm\002"
local PATTERN2=PATTERN.."%s"
local PATTERN3=PATTERN2..DEFAULT

function strColor.fc(fc, str, hl, r)
    fc = _c["F_"..fc] or _c.F_WHITE
    hl = hl or 0
    local pattern = PATTERN2
    if r then pattern = PATTERN3 end
    return string.format(pattern, hl, _c.B_BLACK, fc, str)
end

function strColor.green(str, hl, r)
    return strColor.fc("GREEN", str, hl, r)
end

function strColor.red(str, hl, r)
    return strColor.fc("RED", str, hl, r)
end

return strColor
