require("LuaXml")
local prettyString = require("prettystring")
local xml2lua = {} --api
local function fileName2luaFileName(xmlFilePath, addString) --addString mean 'fimeName .. addStrinng..".lua"'
    addString = addString or ""
    local subName = xmlFilePath:match("([^/]+).xml$")
    local luaName = {subName , addString, ".lua"}
    if subName == nil then
        return nil
    end
    return table.concat(luaName)
end
local function fileExists(path)
    local file = io.open(path,"r")
    if file then file:close() end
    return file ~= nil
end
local function getTargetChild(xmlFormatData, targetSet)    --get target_set children
	local target = {}
	for _, v in ipairs(targetSet) do
		target[v] = true	--相比==会快多了
	end
	local findResult = {}
	for _, child in ipairs(xmlFormatData) do
		if child[0] and target[child[0]] then
			table.insert(findResult, child)
		end
	end
	return findResult
end
local function getColumnCount(cells)    --read a blank column to stop
    local columnCount = 0
    if cells[0] == 'Row' then
     for _, cell in ipairs(cells) do
            columnCount = columnCount + 1
            if cell[1] == nil or cell[1][0] ~= "Data" then	-- ~= > or, use "ss:Index" maybe miss blank columnCount
				return columnCount - 1
            end
      end
    end
    return tonumber(columnCount)
end
local function parse(cell)    --get data from cell
    if cell == nil  or cell[1] == nil then
        return ''
    else
        return cell[1][1]
    end
end
local function handleUsedRow(xmlRows)   --filter useless row
    local retTable = {}
    retTable["columnCount"] = getColumnCount(xmlRows[1])  --columnCount based on first row
    local rowCount = 0
    for _, cells in pairs(xmlRows) do
        local cellsTable = {}
        rowCount = rowCount + 1
        for i=1,retTable.columnCount do --handle cell[i]
            if type(cells[i]) ~= 'table' then
                break
            end
            if cells[i][1] ~= nil or cells[i]["ss:Index"] ~= nil then   --handle blank data
                if cells[i]["ss:Index"] ~= nil and tonumber(cells[i]["ss:Index"]) <= retTable["columnCount"] then
                    for _ = #cellsTable,cells[i]["ss:Index"]-2 do --start from 0,so -2
                        table.insert(cellsTable,"")
                    end
                end
                table.insert(cellsTable,parse(cells[i]))
            else
                table.insert(cellsTable,"")
            end
        end
        table.insert(retTable,cellsTable)
    end
    retTable["rowCount"] = rowCount
    return retTable
end
local function handleBlankRows(Rows)
    local function isBlankRow(Row)
        local ret = true
        for _, value in pairs(Row) do
            if value ~= "" then
                ret = false
                break
            end
        end
        return ret
    end

    for i=Rows["rowCount"], 1, -1 do
        if not isBlankRow(Rows[i]) then
            break
        end
        Rows[i] = nil
        Rows["rowCount"] = Rows["rowCount"] - 1
    end
    return Rows
end
local function parseTable(str,strType)
    local tinser = table.insert
    local function parseComma(sstr)  --parse ,
        local retTable = {}
        for s in string.gmatch(sstr,"([^,]-),") do
            tinser(retTable,tonumber(s))
        end
        tinser(retTable,tonumber(string.match(sstr,",([^,]-)$")))
        return retTable
    end
    --function start
    local retTable = {}
    if strType == 'Table' then
        for s in string.gmatch(str,"{(.-)}") do
            tinser(retTable,parseComma(s))
        end
    elseif strType == 'TupleTable' then
        for s in string.gmatch(str,"{(.-)}") do --parse {}
            local tmpTable = {}
            for k in string.gmatch(s,"%((.-)%)") do
                tinser(tmpTable,parseComma(k))
            end
            tinser(retTable,tmpTable)
        end
    elseif strType == 'Tuple' then
        for k in string.gmatch(str,"%((.-)%)") do
            tinser(retTable,parseComma(k))
        end
    elseif strType == 'Int' then
        tinser(retTable,parseComma(str))
    end
    return retTable
end
local function handleTableData(xmlRows)
    for cloumn = 1, xmlRows["columnCount"] do
        if xmlRows[3][cloumn] == 'Tuple' or
        xmlRows[3][cloumn] == 'TupleTable' or
        xmlRows[3][cloumn] == 'Table' or
        xmlRows[3][cloumn] == 'Int' and xmlRows[2][cloumn] == 'Array' then
            for row = 9, xmlRows["rowCount"] do
                xmlRows[row][cloumn] = parseTable(xmlRows[row][cloumn],xmlRows[3][cloumn])
            end
        end
    end
    return xmlRows
end
xml2lua.megaXmlLoder = function(path)   --load xml file,handle excel 2003 xml ,filter useless data
    if not fileExists(path) then
        print("File don't exist \n")
        return nil
    end
    local retTable = {}
    local XMLTABLE = xml.load(path)
    local worksheetTable = getTargetChild(XMLTABLE,{"Worksheet"})
    for _, singleWorksheet in pairs(worksheetTable) do  --handle worksheetTable
        local singleWorkName = singleWorksheet["ss:Name"]
        retTable[singleWorkName] = {}
        local xmlTables = getTargetChild(singleWorksheet, {"Table"})
		local singleTable = xmlTables[1]
        local xmlRows = getTargetChild(singleTable, {"Row"})    --get all Rows data
        xmlRows = handleUsedRow(xmlRows)    --filter useless rows
        xmlRows = handleBlankRows(xmlRows)
        xmlRows = handleTableData(xmlRows)  --handle table data,such as {1,0};{2,0};{3,2}
        retTable[singleWorkName] = xmlRows
    end
    return retTable
end
xml2lua.xml2luaTable = function(path, headLength, Stype)    --Stype = nil | ‘C' | ’S‘
    local xmlTable = xml2lua.megaXmlLoder(path)
    local retTable = {}
    for worksheetName, worksheetTable in pairs(xmlTable) do --handle format
        local keyTable = {}
        for i=1, headLength do
            keyTable[i] = worksheetTable[i]
            if i == 4
            and(keyTable[4][1] ~= 'CS'
            or keyTable[4][1] ~= 'C'
            or keyTable[4][1] ~= 'S'
            )
            then
                Stype = nil -- some time ,Table dont exsit 'CS'
            end
        end
        local tmpTable = {}
        for i= headLength+1, worksheetTable["rowCount"] do  --data start from 9 cow 
            local tmpCow = {}
            for j=1, worksheetTable["columnCount"] do
                repeat
                    if Stype == nil then
                        --blank
                    elseif keyTable[4][j] == 'CS' or keyTable[4][j] ==  Stype then
                        --blank
                    else
                        break
                    end

                    if keyTable[3][j] == 'Int' or keyTable[3][j] == 'Float'then --handle int or float
                        tmpCow[keyTable[1][j]] = tonumber(worksheetTable[i][j])
                    elseif keyTable[3][j] == 'Bool' then    --handle bool
                        tmpCow[keyTable[1][j]] = (worksheetTable[i][j] == '1')
                    else
                        tmpCow[keyTable[1][j]] = worksheetTable[i][j]   --handle string
                    end
                    break
                until true
            end
            if keyTable[1][1] == 'id' then  --keyTable[1][1] may be 'id'
                local id = worksheetTable[i][1]
                tmpTable[id] = tmpCow
            else
                tmpTable[i - headLength] = tmpCow
            end
        end
        retTable[worksheetName] = tmpTable
    end
    --prettyString(retTable)
    return retTable
end
xml2lua.writeFile = function(path, data)
    local file = io.open(path,"w")
    file:write("return")
    file:write(prettyString(data))
    file:close()
end

return xml2lua


