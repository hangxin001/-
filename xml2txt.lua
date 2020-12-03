require("LuaXml")
local xml2txt = {}
local function string_split(ps_str, ps_split_char)
	local za_ret = {}

	local s, e = 0, 0
	local ss, ee = ps_str:find(ps_split_char, 1, true)
	while ss and ee and e < ss and ss <= ee do
		table.insert(za_ret, ps_str:sub(e + 1, ss - 1))
		s, e = ss, ee
		ss, ee = ps_str:find(ps_split_char, e + 1, true)
	end

	if e < #ps_str then
		table.insert(za_ret, ps_str:sub(e + 1))
	else -- 尾部匹配到分割字符串, 补空串
		table.insert(za_ret, "")
	end

	return za_ret
end

local function string_split_plus(ps_str, ps_split_char, ps_remove_char)
	if (type(ps_remove_char) == "string") and (ps_remove_char ~= "") then
		ps_str = table.concat(string_split(ps_str, ps_remove_char))
	end
	return string_split(ps_str, ps_split_char)
end

local function parse(cell_content, notRoot)
	-- 传入的cell_content[0] = "Data" or "ss:Data"
	if not cell_content then
		return
	end
	if type(cell_content) ~= "table" then
		return tostring(cell_content)
	end
	local part_tab = {}
	for _, part in ipairs(cell_content) do
		table.insert(part_tab, parse(part, true) or "")
	end
	if (not next(part_tab)) and notRoot then
		return " "
	end
	local zs_result = table.concat(part_tab)
	return notRoot and zs_result or zs_result:gsub("&#10;", "")
end

local function get_max_index(xml_Row)
	local cell_Index = 0
	for _, xml_Cell in ipairs(xml_Row) do
		if xml_Cell[0] == "Cell" then
			cell_Index = cell_Index + 1
			if xml_Cell["ss:Index"] and tonumber(xml_Cell["ss:Index"]) ~= cell_Index then
				return cell_Index - 1
			end
			local find_flag = false
			for _, xml_Data in ipairs(xml_Cell) do
				if xml_Data[0] == "Data" or xml_Data[0] == "ss:Data" then
					if not xml_Data[1] then
						return cell_Index - 1
					end
					local data_cont = parse(xml_Data)
					if not (
						string.find(data_cont, "string") or
						string.find(data_cont, "number") or
						string.find(data_cont, "table") or
						string.find(data_cont, "boolean")
						)
					then
						return cell_Index - 1
					end
					find_flag = true
					break
				end
			end
			if not find_flag then
				return cell_Index - 1
			end
		end
	end
	return cell_Index
end

local function get_target_child(xml_format_data, target_set)
	local target = {}
	for _, v in ipairs(target_set) do
		target[v] = true
	end
	local find_result = {}
	for _, child in ipairs(xml_format_data) do
		if child[0] and target[child[0]] then
			table.insert(find_result, child)
		end
	end
	return find_result
end

local function isBlankRow(Row)
	if Row then
		for _, text in ipairs(Row) do
			if text ~= "" then
				return false
			end
		end
	end
	return true
end

local function mega_xml_loader(XML_Path, flag)
	local test = io.open(XML_Path)
	if not test then
		return nil
	end
	test:close()
	local mega_XML = {}
	local XML_Table = xml.load(XML_Path)
	local xml_Worksheets = get_target_child(XML_Table, {"Worksheet"})
	for _, singleWorksheet in ipairs(xml_Worksheets) do
		local spl_name = string_split_plus(singleWorksheet["ss:Name"], "|", " ")
		local worksheet_Name = spl_name[2]
		if flag then
			worksheet_Name = spl_name[1]
		end
		if worksheet_Name then
			mega_XML[worksheet_Name] = {}
			mega_Worksheet = mega_XML[worksheet_Name]
			local xml_Tables = get_target_child(singleWorksheet, {"Table"})
			local singleTable = xml_Tables[1]
			local xml_Rows = get_target_child(singleTable, {"Row"})
			local row_Index = 0
			for _, singleRow in ipairs(xml_Rows) do
				row_Index = row_Index + 1
				local to_Row_Index = singleRow["ss:Index"] and tonumber(singleRow["ss:Index"]) or row_Index
				for i = row_Index, to_Row_Index do
					if not mega_Worksheet[i] then
						mega_Worksheet[i] = {}
					else
						print("to_Row_Index repeat", XML_Path, worksheet_Name, i)
					end
				end
				row_Index = to_Row_Index
				if row_Index == 1 then
					mega_Worksheet.ColumnCount = get_max_index(singleRow)
				end
				local mega_Row = mega_Worksheet[row_Index]
				local xml_Cells = get_target_child(singleRow, {"Cell"})
				local cell_Index = 0
				for _, singleCell in ipairs(xml_Cells) do
					cell_Index = cell_Index + 1
					local to_Cell_Index = singleCell["ss:Index"] and tonumber(singleCell["ss:Index"]) or cell_Index
					if to_Cell_Index > mega_Worksheet.ColumnCount then
						break
					end
					for i = cell_Index, to_Cell_Index do
						if not mega_Row[i] then
							mega_Row[i] = ""
						else
							print("to_Cell_Index repeat", XML_Path, worksheet_Name, row_Index, i)
						end
					end
					cell_Index = to_Cell_Index
					local xml_Datas = get_target_child(singleCell, {"Data", "ss:Data"})
					if #xml_Datas == 1 then
						local text = parse(xml_Datas[1])
						mega_Row[cell_Index] = text
					elseif #xml_Datas > 1 then
						print("more then one Data or ss:Data")
					end
				end
			end
			mega_Worksheet.RowCount = row_Index
		end
	end
	for _, workSheet in pairs(mega_XML) do
		for i = workSheet.RowCount, 1, -1 do
			if isBlankRow(workSheet[i]) then
				workSheet[i] = nil
			else
				break
			end
		end
	end
	return mega_XML
end

function toRow(row, ColumnCount)
	row = row or {}
	local row_Str = {}
	for i = 1, ColumnCount do
		table.insert(row_Str, (row[i] or ""))
	end
	return table.concat(row_Str, "\t")
end

xml2txt.write_txt = function(result_path, XML_Path)
	--local spl_path = string_split_plus(XML_Path, "/")
	--local filename = table.remove(spl_path)
	--filename = string_split_plus(filename, ".")[1]
	--local result_path = name .. "-" .. filename .. "-"
	result_path = result_path:match("(.+).txt")
	local p_xml = mega_xml_loader(XML_Path)
	for sheetname, worksheet in pairs(p_xml) do
		--print(sheetname)
		local file = io.open(result_path .."-" ..sheetname .. ".txt", "w")
		local table_Str = {}
		local blank_Row = toRow({}, worksheet.ColumnCount)
		local blank_Row_counter = 0
		for row_Index = 1, worksheet.RowCount do
			--print(XML_Path, sheetname, row_Index)
			local cur_Row = toRow(worksheet[row_Index], worksheet.ColumnCount)
			if cur_Row == blank_Row then
				blank_Row_counter = blank_Row_counter + 1
			else
				for i = 1, blank_Row_counter do
					table.insert(table_Str, blank_Row)
				end
				blank_Row_counter = 0
				table.insert(table_Str, cur_Row)
			end
		end
		table.insert(table_Str, "")
		file:write(table.concat(table_Str, "\n"))
		file:close()
	end
end

return xml2txt