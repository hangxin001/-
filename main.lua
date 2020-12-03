local xml2lua = require("xml2lua")
local xml2txt = require("xml2txt")
local json = require("json")
--[[
    xml2txt.write_txt = function(dstPath, xmlPath)
    xml2lua.writeFile = function(dstPath, data)    --data is table
    xml2json = function(dstPath, data)  --data is table
    xml2lua.xml2luaTable = function(path, headLength, Stype)    --Stype = nil | ‘C' | ’S‘
]]
local srcDir
local dstDir
local handle = {}
local xml2json = function(dstPath, data)
    local file = io.open(dstPath,'w')
    file:write(json.encode(data))
    file:close()
end
handle.txt = function (srcFilePath, dstFilePath, data)
    xml2txt.write_txt(dstFilePath, srcFilePath)
end
handle.lua = function (srcFilePath, dstFilePath, data)   --data is table
    xml2lua.writeFile(dstFilePath,data)
end
handle.json = function (srcFilePath, dstFilePath, data)  --data is table
    xml2json(dstFilePath, data)
end
local loadRule = function (rulePath, headLength)
    headLength = headLength or 3
    local valueTable = xml2lua.megaXmlLoder(rulePath)
    local headTable = {}
    for _, worksheet in pairs(valueTable) do
        for i=1,worksheet["rowCount"] do --rule.xml is singal worksheet
            if i <= headLength then
                headTable[i] = worksheet[i]
                worksheet[i] = nil
            end
            if i > headLength then
                worksheet[i-headLength] = worksheet[i]
                worksheet[i] = nil
            end
        end
    end
    return headTable, valueTable
end

local selectStypeHanlde = function(sType, headTable, valuetable)
    local selectHandle = {}
    selectHandle.Server = function (srcFilePath, headLength, singalRow)
        local srcTable = xml2lua.xml2luaTable(srcFilePath,headLength,"S")
        local dstFileType = singalRow[3]:match(".([^.]+)$")
        local dstFilePath = dstDir .. singalRow[3]
        handle[dstFileType](srcFilePath, dstFilePath, srcTable)
    end
    selectHandle.Client =function (srcFilePath, headLength, singalRow)
        local srcTable = xml2lua.xml2luaTable(srcFilePath,headLength,"C")
        local dstFileType = singalRow[4]:match(".([^.]+)$")
        local dstFilePath = dstDir .. singalRow[4]
        handle[dstFileType](srcFilePath, dstFilePath, srcTable)
    end
    selectHandle.All = function (srcFilePath, headLength, singalRow)
        selectHandle.Server(srcFilePath,headLength,"S")
        selectHandle.Client(srcFilePath,headLength,"C")
    end
    ---start
    os.execute('mkdir dst') --create dir
    for _, row in pairs(valuetable) do
        for _, singalRow in ipairs(row) do
            local srcFilePath = srcDir .. singalRow[1]
            local headLength = tonumber(singalRow[2]:match("H(.+)")) + 1
            selectHandle[sType](srcFilePath, headLength, singalRow)
        end
    end
end

local main = function (sType, src, dst)
    srcDir = src
    dstDir = dst
    local headTable, valueTable = loadRule(srcDir.."rule.xml",3) --3 is head length
    selectStypeHanlde(sType, headTable, valueTable)
end

assert(arg[1] ~= 'Server' or arg[1] ~= 'Client' or arg[1] ~= 'All')
main(arg[1],arg[2]..'/',arg[3]..'/')


