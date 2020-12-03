local function prettystring(...)
    local tinsert = table.insert
    local uniqueTable = {}
    local retTable  = {}    --存储最后的结果
    local function prettyOneString(data,tab,path)
        tab = tab or 0
        path = path or "@/"

        if type(data) ~= 'table'  then   --处理非table
            if type(data) == 'string' then
                tinsert(retTable,string.format('"%s"',tostring(data)))
            else
                tinsert(retTable ,tostring(data))
            end
            if tab ~= 0 then
                tinsert(retTable,",")
            end
        else    --处理table
            if uniqueTable[tostring(data)] == nil then
                tinsert(retTable,"{\n")
            end
            if next(data) ~= nil and uniqueTable[tostring(data)] == nil then
                uniqueTable[tostring(data)] = path
                for key, value in pairs(data) do
                    tinsert(retTable,string.rep("\t",tab))
                    if type(key)  == 'string' then
                        local tmpString = string.format('["%s"] = ',tostring(key))    --string.format可读性会比较好点，性能略微损失
                        tinsert(retTable,tmpString)
                    else
                        local tmpString = string.format("[%s] = ",tostring(key))
                        tinsert(retTable,tmpString)
                    end
                    prettyOneString(value,tab+1,path..tostring(key)..'/' )
                    tinsert(retTable,"\n")
                end
                local tmpString = string.format("%s},",string.rep("\t",tab))
                tinsert(retTable,tmpString)
            else
                local tmpString
                if next(data) ~= nil then
                    tmpString = string.format("%s",uniqueTable[tostring(data)])
                else
                    tmpString = '""'
                end
                tinsert(retTable,tmpString)
            end
        end
        --return table.concat(retTable)
    end
    --start
    local argv = {...}
    local argSize = select("#",{...})
    for i=1,argSize do --遍历参数
        local argcType = type(argv[i])
        if argcType == 'table' and i ~= 1 then
            tinsert(retTable,"\n")
        end
        prettyOneString(argv[i])
        retTable[#retTable] = "}"   --remove final ,
        if argcType ~= 'table' and i ~= argv.n then
            tinsert(retTable,"\t")  --模拟print行为
        end
    end
    return table.concat(retTable)
end

return prettystring