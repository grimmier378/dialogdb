local mq = require('mq')
local ImGui = require('ImGui')
Icons = require('mq.ICONS')
local gIcon = Icons.MD_SETTINGS
local Running = false
local hasDialog = false
local Dialog = require('npc_dialog')
local curZone = mq.TLO.Zone.ShortName() or 'None'
local serverName = mq.TLO.EverQuest.Server()
local ShowDialog, ConfUI, editGUI = false, false, false
local cmdGroup = '/dgae'
local cmdZone = '/dgza'
local cmdChar = '/dex'
local cmdSelf = '/say'
local tmpDesc = ''
local autoAdd = false
local DEBUG, newTarget = false, false
local tmpTarget = 'None'
local eZone, eTar, eDes, eCmd, newCmd, newDesc = '', '', '', '', '', ''
local CurrTarget = mq.TLO.Target.DisplayName() or 'None'
local dialogData = mq.configDir ..'/npc_dialog.lua'
local dialogConfig = mq.configDir ..'/DialogDB_Config.lua'
local entries = {}
local showCmds = true
local Config = {
	cmdGroup = cmdGroup,
	cmdZone = cmdZone,
	cmdChar = cmdChar,
	cmdSelf = cmdSelf,
	autoAdd = false
}

local winFlags = bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.AlwaysAutoResize)
local delay = 1

---comment Check to see if the file we want to work on exists.
---@param name string -- Full Path to file
---@return boolean -- returns true if the file exists and false otherwise
local function File_Exists(name)
	local f=io.open(name,"r")
	if f~=nil then io.close(f) return true else return false end
end

local function fixEnding(var)
	var = var or "" -- ensure var is not nil

	-- Check if var ends with '/' or ' '
	if not var:match("[/ ]$") then
		var = var .. " "
	end

	return var
end

local function loadSettings()
	-- Check if the dialog data file exists
	if not File_Exists(dialogData) then
		mq.pickle(dialogData, Dialog)
	else
		local tmpDialog = dofile(dialogData)
		for server, sData in pairs(Dialog) do
			tmpDialog[server] = tmpDialog[server] or {}
			for target, tData in pairs(sData) do
				tmpDialog[server][target] = tmpDialog[server][target] or {}
				for zone, zData in pairs(tData) do
					tmpDialog[server][target][zone] = tmpDialog[server][target][zone] or {}
					for desc, cmd in pairs(zData) do
						-- Only add default entries if they do not exist in the saved data
						if not tmpDialog[server][target][zone][desc] then
							tmpDialog[server][target][zone][desc] = cmd
						end
					end
				end
			end
		end
		Dialog = tmpDialog
	end
	if not File_Exists(dialogConfig) then
		mq.pickle(dialogConfig, {cmdGroup = cmdGroup, cmdZone = cmdZone, cmdChar = cmdChar, autoAdd = autoAdd, cmdSelf = cmdSelf})
		ConfUI = true
		tmpTarget = 'None'
	else
		Config = dofile(dialogConfig)
		cmdGroup = Config.cmdGroup
		cmdZone = Config.cmdZone
		cmdChar = Config.cmdChar
		cmdSelf = Config.cmdSelf
		autoAdd = Config.autoAdd
	end

	--- Ensure that the command is a '/'' command otherwise add '/say ' to the front of it
	for server,sData in pairs(Dialog) do
		for target,tData in pairs(sData) do
			for zone,zData in pairs(tData) do
				for desc,cmd in pairs(zData) do
					if not cmd:match("^/") then
						Dialog[server][target][zone][desc] = string.format("/say %s",cmd)
					end
				end
			end
		end
	end
	mq.pickle(dialogData, Dialog)
	printf("Dialog Data Loaded for %s",serverName)
end

local function printHelp()
	local msgPref = string.format("\aw[\at%s\aw] ",mq.TLO.Time.Time24())
	printf("\aw[\at%s\aw] \agNPC Dialog DB \aoCommands:",msgPref)
	printf("%s\agNPC Dialog DB \aoCurrent Zone:",msgPref)
	printf("%s\ay/dialogdb add \aw[\at\"description\"\aw] [\at\"command\"\aw] \aoAdds to Current Zone description and command",msgPref)
	printf("%s\ay/dialogdb add \aw[\at\"Value\"\aw] \aoAdds to Current Zone description and command = Value ",msgPref)
	printf("%s\agNPC Dialog DB \aoAll Zones:",msgPref)
	printf("%s\ay/dialogdb addall \aw[\at\"description\"\aw] [\at\"command\"\aw] \aoAdds to All Zones description and command",msgPref)
	printf("%s\ay/dialogdb addall \aw[\at\"Value\"\aw] \aoAdds to All Zones description and command = Value ",msgPref)
	printf("%s\agNPC Dialog DB \aoCommon:",msgPref)
	printf("%s\ay/dialogdb help \aoDisplay Help",msgPref)
	printf("%s\ay/dialogdb config \aoDisplay Config Window",msgPref)
	printf("%s\ay/dialogdb debug \aoToggles Debugging, Turns off Commands and Prints them out so you can verify them",msgPref)
end	

local function eventNPC(line,who)
	if not autoAdd then return end
	local check = string.format("npc= %s",who)
	if mq.TLO.SpawnCount(check) == nil then return end
	local found = false
	if Dialog[serverName][who] == nil then
		Dialog[serverName][who] = {}
		Dialog[serverName][who][curZone] = {}
		Dialog[serverName][who]['allzones'] = {}
	end
	for w in string.gmatch(line, "%[(.-)%].") do
		if Dialog[serverName][who][curZone][w] == nil then
			Dialog[serverName][who][curZone][w] =  w
			found = true
		end
	end
	if found then
		mq.pickle(dialogData, Dialog)
		loadSettings()
	end
end

local function setEvents()
	if autoAdd then
		mq.event("npc_say1", '#1# say#*#[#*#]#*#', eventNPC)
		mq.event("npc_whisper2", '#1# whisper#*#[#*#]#*#', eventNPC)
	else
		mq.unevent("npc_say1")
		mq.unevent("npc_whisper2")
	end
end

local function checkDialog()
	hasDialog = false
	if mq.TLO.Target() ~= nil then
		curZone = mq.TLO.Zone.ShortName() or 'None'
		CurrTarget = mq.TLO.Target.DisplayName()
		-- printf("Server: %s  Zone: %s Target: %s",serverName,curZone,target)
		if Dialog[serverName] == nil then
			return hasDialog
		elseif Dialog[serverName][CurrTarget] == nil then
			return hasDialog
		elseif Dialog[serverName][CurrTarget][curZone] == nil and Dialog[serverName][CurrTarget]['allzones'] == nil then
			return hasDialog
		elseif Dialog[serverName][CurrTarget][curZone] ~= nil or Dialog[serverName][CurrTarget]['allzones'] ~= nil then
			hasDialog = true
			return hasDialog
		end
	end
	return hasDialog
end

local function sortedKeys(tableToSort)
	local keys = {}
	for key in pairs(tableToSort) do
		table.insert(keys, key)
	end
	table.sort(keys)  -- Sorts alphabetically by default
	return keys
end

local function bind(...)
	local args = {...}
	local key = args[1]
	local valueChanged = false
	if #args == 1 then
		if args[1] == 'config' then
			ConfUI = not ConfUI
			return
		elseif args[1] == 'debug' then
			DEBUG = not DEBUG
			local msgPref = string.format("\aw[\at%s\aw] ",mq.TLO.Time.Time24())
			if DEBUG then
				printf("%s \ayDEBUGGING \agEnabled \ayALL COMMANDS WILL BE PRINTED TO CONSOLE",msgPref)
			else
				printf("%s \ayDEBUGGING \arDisabled \ayALL COMMANDS WILL BE EXECUTED",msgPref)
			end
			return
		elseif args[1] == 'help' then
			printHelp()
			return
		else
			printHelp()
			print("No String Supplied try again~")
			return
		end
	end
	local name = mq.TLO.Target.DisplayName() or 'None'
	if key ~= nil then
		local value = args[2]
		if key == 'add' and #args >= 2 then
			local name = mq.TLO.Target.DisplayName() or 'None'
			if name ~= 'None' then
				if Dialog[serverName] == nil then
					Dialog[serverName] = {}
				end
				if Dialog[serverName][name] == nil then
					Dialog[serverName][name] = {}
				end
				if Dialog[serverName][name][curZone] == nil then
					Dialog[serverName][name][curZone] = {}
				end
				if #args == 2 then
					if Dialog[serverName][name][curZone][value] == nil then
						local cmdValue = value
						if not cmdValue:match("^/") then cmdValue = string.format("/say %s",cmdValue) end
						Dialog[serverName][name][curZone][value] = cmdValue
						-- printf("Server: %s  Zone: %s Target: %s Dialog: %s",serverName,curZone,name, value)
					end
				elseif #args == 3 then
					if Dialog[serverName][name][curZone][args[2]] == nil then
						if not args[3]:match("^/") then args[3] = string.format("/say %s",args[3]) end
						Dialog[serverName][name][curZone][args[2]] = args[3]
					end
				end
				valueChanged = true
			end
		elseif key == "addall" and #args >= 2 then
			if name ~= 'None' then
				if Dialog[serverName] == nil then
					Dialog[serverName] = {}
				end
				if Dialog[serverName][name] == nil then
					Dialog[serverName][name] = {}
				end
				if Dialog[serverName][name]['allzones'] == nil then
					Dialog[serverName][name]['allzones'] = {}
				end
				if #args == 2 then
					if Dialog[serverName][name]['allzones'][value] == nil then
						local cmdValue = value
						if not cmdValue:match("^/") then cmdValue = string.format("/say %s",cmdValue) end
						Dialog[serverName][name]['allzones'][value] = cmdValue
					end
				elseif #args == 3 then
					if Dialog[serverName][name]['allzones'][args[2]] == nil then
						if not args[3]:match("^/") then args[3] = string.format("/say %s",args[3]) end
						Dialog[serverName][name]['allzones'][args[2]] = args[3]
					end
				end
				valueChanged = true
			end
		end
		if valueChanged then
			mq.pickle(dialogData, Dialog)
		end
	end
end

-- Function to merge dialogues and handle Dialog display
local function handleCombinedDialog()
	local allZonesTable = Dialog[serverName][CurrTarget]['allzones'] or {}
	local curZoneTable = Dialog[serverName][CurrTarget][curZone] or {}
	local combinedTable = {}
	
	-- First, fill combinedTable with all zones data
	for k, v in pairs(allZonesTable) do
		combinedTable[k] = v
	end
	-- Then, override or add with current zone data
	for k, v in pairs(curZoneTable) do
		combinedTable[k] = v
	end

	return combinedTable
end

local function EditGUI(server, target, zone, desc, cmd)
	if #entries == 0 then
		table.insert(entries, {desc = desc, cmd = cmd})
	end
	
	ImGui.Text("Edit Dialog")
	ImGui.Separator()
	ImGui.Text(string.format("Target: %s", target))
	ImGui.Text(string.format("Zone: %s", zone))
	ImGui.SameLine()

	local aZones = (zone == 'allzones')
	aZones, _ = ImGui.Checkbox("All Zones##EditDialogAllZones", aZones)
	eZone = aZones and 'allzones' or curZone
	if zone ~= eZone then
		zone = eZone
	end
	if ImGui.Button("Save All##SaveAllButton") then
		for _, entry in ipairs(entries) do
			if entry.desc ~= "" and entry.desc ~= "NEW" then
				if not entry.cmd:match("^/") then entry.cmd = string.format("/say %s", entry.cmd) end
				Dialog[server][target] = Dialog[server][target] or {}
				Dialog[server][target][eZone] = Dialog[server][target][eZone] or {}
				Dialog[server][target][eZone][entry.desc] = entry.cmd
			end
		end
		mq.pickle(dialogData, Dialog)
		newTarget = false
		editGUI = false
	end
	ImGui.SameLine()
	if ImGui.Button("Add Row##AddRowButton") then
		table.insert(entries, {desc = "NEW", cmd = "NEW"})
	end
	ImGui.SameLine()
	if ImGui.Button("Clear##ClearRowsButton") then
		entries = {}
		table.insert(entries, {desc = "NEW", cmd = "NEW"})
	end
	ImGui.Separator()
	ImGui.Text("Description:")
	ImGui.SameLine(160)
	ImGui.Text("Command:")
	ImGui.BeginChild("##EditDialogChild", 0.0, 0.0, ImGuiChildFlags.Border)
	for i, entry in ipairs(entries) do

		ImGui.SetNextItemWidth(150)
		entry.desc, _ = ImGui.InputText("##EditDialogDesc" .. i, entry.desc)
		ImGui.SameLine()
		ImGui.SetNextItemWidth(150)
		entry.cmd, _ = ImGui.InputText("##EditDialogCmd" .. i, entry.cmd)
		ImGui.SameLine()
		if ImGui.Button("Remove##" .. i) then
			table.remove(entries, i)
		end

		ImGui.Separator()
	end
	ImGui.EndChild()

end

local function GUI_Main()
	--- Dialog Main Window
	if ShowDialog then
		local open, show = ImGui.Begin("NPC Dialog##Dialog_Main", true, winFlags)
		if not show then
			ImGui.End()
		end

		if checkDialog() then
			ImGui.Text(gIcon)
			if ImGui.IsItemHovered() then
				if ImGui.IsMouseReleased(0) then
					ConfUI = not ConfUI
					tmpTarget = CurrTarget
				end
			end
			ImGui.SameLine()
			ImGui.Text("%s's Dialog", CurrTarget)
			local dialogCombined = handleCombinedDialog()
			if next(dialogCombined) ~= nil then

				local sortedKeyList = sortedKeys(dialogCombined)
				if dialogCombined[tmpDesc] == nil then
					tmpDesc = 'None'
				end
				ImGui.SetNextItemWidth(200)
				if ImGui.BeginCombo("##DialogDBCombined", tmpDesc) then
					for _, desc in pairs(sortedKeyList) do
						local isSelected = (desc == tmpDesc)
						if ImGui.Selectable(desc, isSelected) then
							tmpDesc = desc
							_G["cmdString"] = dialogCombined[desc] -- Global to maintain state outside of this function
						end
						if isSelected then
							ImGui.SetItemDefaultFocus()
						end
					end
					ImGui.EndCombo()
				end
				ImGui.SameLine()
				local eyeCon = showCmds and Icons.FA_CARET_UP or Icons.FA_CARET_DOWN
				
				if ImGui.Button(eyeCon) then showCmds = not showCmds end
				if showCmds then
					if _G["cmdString"] and _G["cmdString"] ~= '' then
						ImGui.Separator()
						if ImGui.Button('Say ##DialogDBCombined') then
							if not DEBUG then
								mq.cmdf("%s",  _G["cmdString"])
							else
								printf("%s",  _G["cmdString"])
							end
												end
						if mq.TLO.Me.GroupSize() > 1 then
							ImGui.SameLine()
							if ImGui.Button('Group Say ##DialogDBCombined') then
								if cmdGroup:find("^/d") then
									cmdGroup = cmdGroup.." "
								end
								if not DEBUG then
									mq.cmdf("/multiline ; %s/target %s; /timed 5, %s%s",cmdGroup, CurrTarget,cmdGroup,_G["cmdString"])
								else
									printf("/multiline ; %s/target %s; /timed 5, %s%s",cmdGroup, CurrTarget,cmdGroup,_G["cmdString"])
								end
							end
							ImGui.SameLine()
							local tmpDelay = delay
							ImGui.SetNextItemWidth(75)
							tmpDelay = ImGui.InputInt("Delay##DialogDBCombined", tmpDelay, 1, 1)
							if tmpDelay ~= delay then
								delay = tmpDelay
							end
							if ImGui.Button('Group Say Delayed ##DialogDBCombined') then
								local cDelay = delay * 10
								for i = 1, mq.TLO.Me.GroupSize() - 1 do
									local pName = mq.TLO.Group.Member(i).DisplayName()
									if cmdChar:find("/bct") then
										pName = pName.." /"
									else
										pName = pName.." "
									end
									if not DEBUG then
										mq.cmdf("/multiline ; %s %s/target %s; %s %s/timed %s, %s",cmdChar,pName, CurrTarget,cmdChar,pName ,cDelay, _G["cmdString"])
									else
										printf("/multiline ; %s %s/target %s; %s %s/timed %s, %s",cmdChar,pName, CurrTarget,cmdChar,pName ,cDelay,  _G["cmdString"])
									end
									cDelay = cDelay + (delay * 10)
								end
								if not DEBUG then
									mq.cmdf("/timed %s, %s",cDelay, _G["cmdString"])
								else
									printf("/timed %s, %s",cDelay, _G["cmdString"])
								end
							end
							ImGui.SameLine()
							if ImGui.Button('Zone Members ##DialogDBCombined') then
								if cmdZone:find("^/d") then
									cmdZone = cmdZone.." "
								end
								if not DEBUG then
									mq.cmdf("/multiline ; %s/target %s; /timed 5, %s%s",cmdZone, CurrTarget,cmdZone, _G["cmdString"])
								else
									printf("/multiline ; %s/target %s; /timed 5, %s%s",cmdZone, CurrTarget,cmdZone, _G["cmdString"])
								end
							end
						end
					end
				end
			end
		end
		ImGui.End()
	end
	
	--- Dialog Config Window
	if ConfUI then
		if tmpTarget == 'None' then
			tmpTarget = CurrTarget
		end
		ImGui.SetNextWindowSize(580,350, ImGuiCond.Appearing)
		local openC, showC = ImGui.Begin("NPC Dialog Config##Dialog_Config", true, ImGuiWindowFlags.NoCollapse)
		if not openC then
			if newTarget then
				Dialog[serverName][tmpTarget] = nil
				newTarget = false
			end
			ConfUI = false
			tmpTarget = 'None'
		end
		if not showC then
			ImGui.End()
		end
		local tmpGpCmd = cmdGroup:gsub(" $","") or ''
		local tmpZnCmd = cmdZone:gsub(" $","") or ''
		local tmpChCmd = cmdChar:gsub(" $","") or ''
		local tmpSlCmd = cmdSelf:gsub(" $","") or ''

		ImGui.SeparatorText("Command's Config")

		ImGui.BeginTable("Command Config##DialogConfigTable", 2, ImGuiTableFlags.Borders)
		ImGui.TableSetupColumn("##DialogConfigCol1", ImGuiTableColumnFlags.WidthFixed, 380)
		ImGui.TableSetupColumn("##DialogConfigCol2", ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableNextRow()
		ImGui.TableNextColumn()
		tmpGpCmd, _ = ImGui.InputText("Group Command##DialogConfig", tmpGpCmd)
		if tmpGpCmd ~= cmdGroup then
			cmdGroup = tmpGpCmd:gsub(" $","")
		end
		ImGui.TableNextColumn()
		if ImGui.Button("Set Group Command##DialogConfig") then
			Config.cmdGroup = tmpGpCmd:gsub(" $","")
			mq.pickle(dialogConfig, Config)
		end
		ImGui.TableNextRow()
		ImGui.TableNextColumn()
		tmpZnCmd, _ = ImGui.InputText("Zone Command##DialogConfig", tmpZnCmd)	
		if tmpZnCmd ~= cmdZone then
			cmdZone = tmpZnCmd:gsub(" $","")
		end
		ImGui.TableNextColumn()
		if ImGui.Button("Set Zone Command##DialogConfig") then
			Config.cmdZone = tmpZnCmd:gsub(" $","")
			mq.pickle(dialogConfig, Config)
		end
		ImGui.TableNextRow()
		ImGui.TableNextColumn()
		tmpChCmd, _ = ImGui.InputText("Character Command##DialogConfig", tmpChCmd)
		if tmpChCmd ~= cmdChar then
			cmdChar = tmpChCmd:gsub(" $","")
		end
		ImGui.TableNextColumn()
		if ImGui.Button("Set Character Command##DialogConfig") then
			Config.cmdChar = tmpChCmd:gsub(" $","")
			mq.pickle(dialogConfig, Config)
		end
		-- ImGui.TableNextRow()
		-- ImGui.TableNextColumn()
		-- tmpSlCmd, _ = ImGui.InputText("Self Command##DialogConfig", tmpSlCmd)
		-- if tmpSlCmd ~= cmdSelf then
		-- 	cmdSelf = tmpSlCmd:gsub(" $","")
		-- end
		-- ImGui.TableNextColumn()
		-- if ImGui.Button("Set Single Command##DialogConfig") then
		-- 	Config.cmdSelf = tmpSlCmd:gsub(" $","")
		-- 	mq.pickle(dialogConfig, Config)
		-- end
		ImGui.EndTable()
		ImGui.Separator()
		--- Dialog Config Table
		if tmpTarget ~= nil and tmpTarget ~= 'None' then
			local sizeX, sizeY = ImGui.GetContentRegionAvail()
			ImGui.SeparatorText(tmpTarget.."'s Dialogs")
			-- ImGui.BeginChild("DialogConfigChild", sizeX, sizeY -30, bit32.bor(ImGuiChildFlags.Border))
			ImGui.BeginTable("NPC Dialogs##DialogConfigTable2", 5, bit32.bor(ImGuiTableFlags.Borders,ImGuiTableFlags.ScrollY),ImVec2(sizeX,sizeY-80))
			ImGui.TableSetupScrollFreeze(0, 1)
			ImGui.TableSetupColumn("NPC##DialogDB_Config", ImGuiTableColumnFlags.WidthFixed, 100)
			ImGui.TableSetupColumn("Zone##DialogDB_Config", ImGuiTableColumnFlags.WidthFixed, 100)
			ImGui.TableSetupColumn("Description##DialogDB_Config", ImGuiTableColumnFlags.WidthStretch, 100)
			ImGui.TableSetupColumn("Trigger##DialogDB_Config", ImGuiTableColumnFlags.WidthStretch, 100)
			ImGui.TableSetupColumn("##DialogDB_Config_Save", ImGuiTableColumnFlags.WidthFixed, 120)
			ImGui.TableHeadersRow()
			local id = 1
			if Dialog[serverName][tmpTarget] == nil then
				Dialog[serverName][tmpTarget] = {allzones = {}, [curZone] = {}}
				newTarget = true
			else
				-- Use sortedKeys to sort zones and then descriptions within zones
				local sortedZones = sortedKeys(Dialog[serverName][tmpTarget])
				for _, z in ipairs(sortedZones) do
					local sortedDescriptions = sortedKeys(Dialog[serverName][tmpTarget][z])
					for _, d in ipairs(sortedDescriptions) do
						local c = Dialog[serverName][tmpTarget][z][d]
						ImGui.TableNextRow()
						ImGui.TableNextColumn()
						ImGui.Text(tmpTarget)
						ImGui.TableNextColumn()
						ImGui.Text(z)
						ImGui.TableNextColumn()
						ImGui.Text(d)
						ImGui.TableNextColumn()
						ImGui.Text(c)
						ImGui.TableNextColumn()
						if ImGui.Button("Edit##DialogDB_Config_Edit_"..id) then
							eZone = z
							eTar = tmpTarget
							eDes = d
							eCmd = c
							newCmd = c
							newDesc = d
							editGUI = true
						end
						ImGui.SameLine()
						if ImGui.Button("Delete##DialogDB_Config_"..id) then
							Dialog[serverName][tmpTarget][z][d] = nil
							mq.pickle(dialogData, Dialog)
						end
						id = id + 1
					end
				end
			end
			ImGui.EndTable()
			if ImGui.Button("Delete NPC##DialogConfig") then
				Dialog[serverName][tmpTarget] = nil
				mq.pickle(dialogData, Dialog)
				ConfUI = false
			end
			-- ImGui.EndChild()
		end
		local tmpTxtAuto = autoAdd and "Disable Auto Add" or "Enable Auto Add"
		if ImGui.Button(tmpTxtAuto.."##DialogConfigAutoAdd") then
			autoAdd = not autoAdd
			Config.autoAdd = autoAdd
			mq.pickle(dialogConfig, Config)
			setEvents()
		end
		ImGui.SameLine()
		if ImGui.Button("Add Dialog##DialogConfig") then
			if Dialog[serverName][tmpTarget] == nil then
				Dialog[serverName][tmpTarget] = {allzones = {}, [curZone] = {}}
			end
			eZone = curZone
			eTar = tmpTarget
			eDes = "NEW"
			eCmd = "NEW"
			newCmd = "NEW"
			newDesc = "NEW"
			editGUI = true
		end
		ImGui.SameLine()
		if ImGui.Button("Refresh Target##DialogConf_Refresh") then
			tmpTarget = mq.TLO.Target.DisplayName()
		end
		ImGui.SameLine()
		if ImGui.Button("Cancel##DialogConf_Cancel") then
			if newTarget then
				Dialog[serverName][tmpTarget] = nil
				newTarget = false
			end
			ConfUI = false
		end
		ImGui.End()
	end

	--- Dialog Edit Window
	if editGUI then
		local openE, showE = ImGui.Begin("Edit Dialog##Dialog_Edit", true, ImGuiWindowFlags.NoCollapse)
		if not openE then
			editGUI = false
			entries = {}
		end
		if not showE then
			ImGui.End()
		end
		EditGUI(serverName,eTar,eZone,eDes,eCmd)
		ImGui.End()
	end
end

local function init()
	if mq.TLO.MacroQuest.BuildName() ~= 'Emu' then serverName = 'Live' end -- really only care about server name for EMU as the dialogs may vary from serever to server to server
	loadSettings()
	Running = true
	setEvents()
	mq.bind('/dialogdb', bind)
	mq.imgui.init("Npc Dialog", GUI_Main)
	printHelp()
end

local function mainLoop()
	while Running do
		if mq.TLO.Me.Zoning() then
			tmpDesc = ''
			CurrTarget = 'None'
			hasDialog = false
			ShowDialog = false
			ConfUI = false
			editGUI = false
			while mq.TLO.Me.Zoning() do
				mq.delay(1000)
			end
		end
		if checkDialog() then
			ShowDialog = true
		else
			ShowDialog = false
			if CurrTarget ~= mq.TLO.Target.DisplayName() then tmpDesc = '' end
		end
		mq.doevents()
		mq.delay(10)
	end
	mq.exit()
end

init()
mainLoop()