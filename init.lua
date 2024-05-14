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
local DEBUG = false
local tmpTarget = 'None'
local eZone, eTar, eDes, eCmd, newCmd, newDesc = '', '', '', '', '', ''
local CurrTarget = mq.TLO.Target.DisplayName() or 'None'
local dialogData = mq.configDir ..'/npc_dialog.lua'
local dialogConfig = mq.configDir ..'/DialogDB_Config.lua'
local entries = {}
local Config = {
	cmdGroup = cmdGroup,
	cmdZone = cmdZone,
	cmdChar = cmdChar,
	cmdSelf = cmdSelf,
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
	if not File_Exists(dialogData) then
		mq.pickle(dialogData, Dialog)
	else
		Dialog = dofile(dialogData)
	end
	if not File_Exists(dialogConfig) then
		mq.pickle(dialogConfig, {cmdGroup = cmdGroup, cmdZone = cmdZone, cmdChar = cmdChar, cmdSelf = cmdSelf})
		ConfUI = true
		tmpTarget = 'None'
	else
		Config = dofile(dialogConfig)
		cmdGroup = fixEnding(Config.cmdGroup)
		cmdZone = fixEnding(Config.cmdZone)
		cmdChar = Config.cmdChar
		cmdSelf = Config.cmdSelf
	end
	

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
		if key == 'add' then
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
						Dialog[serverName][name][curZone][value] = value
						-- printf("Server: %s  Zone: %s Target: %s Dialog: %s",serverName,curZone,name, value)
					end
				elseif #args == 3 then
					if Dialog[serverName][name][curZone][args[2]] == nil then
						Dialog[serverName][name][curZone][args[2]] = args[3]
					end
				end
				valueChanged = true
			end
		elseif key == "addall" then
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
						Dialog[serverName][name]['allzones'][value] = value
					end
				elseif #args == 3 then
					if Dialog[serverName][name]['allzones'][args[2]] == nil then
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
	local eZone = aZones and 'allzones' or curZone

	ImGui.Separator()
	ImGui.Text("Description:")
	ImGui.SameLine(160)
	ImGui.Text("Command:")
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

	if ImGui.Button("Add Row##AddRowButton") then
		table.insert(entries, {desc = "NEW", cmd = "NEW"})
	end
	ImGui.SameLine()
	if ImGui.Button("Save All##SaveAllButton") then
		for _, entry in ipairs(entries) do
			if entry.desc ~= "" and entry.desc ~= "NEW" then
				Dialog[server][target] = Dialog[server][target] or {}
				Dialog[server][target][eZone] = Dialog[server][target][eZone] or {}
				Dialog[server][target][eZone][entry.desc] = entry.cmd
			end
		end
		mq.pickle(dialogData, Dialog)
		editGUI = false
	end

	ImGui.SameLine()
	if ImGui.Button("Cancel##EditDialogCancel") then
		editGUI = false
	end
end

local newTarget = false

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
				if _G["cmdString"] and _G["cmdString"] ~= '' then
					ImGui.Separator()
					if ImGui.Button('Say ##DialogDBCombined') then
						if not DEBUG then
							mq.cmdf("%s %s", cmdSelf, _G["cmdString"])
						else
							 printf("%s %s", cmdSelf, _G["cmdString"])
						end
											end
					if mq.TLO.Me.GroupSize() > 1 then
						ImGui.SameLine()
						if ImGui.Button('Group Say ##DialogDBCombined') then
							if not DEBUG then
								mq.cmdf("/multiline ; %s/target %s; /timed 5, %s%s %s",cmdGroup, CurrTarget,cmdGroup,cmdSelf,_G["cmdString"])
							else
								 printf("/multiline ; %s/target %s; /timed 5, %s%s %s",cmdGroup, CurrTarget,cmdGroup,cmdSelf,_G["cmdString"])
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
									mq.cmdf("/multiline ; %s %s/target %s; %s %s/timed %s, %s %s",cmdChar,pName, CurrTarget,cmdChar,pName ,cDelay, cmdSelf, _G["cmdString"])
								else
									 printf("/multiline ; %s %s/target %s; %s %s/timed %s, %s %s",cmdChar,pName, CurrTarget,cmdChar,pName ,cDelay, cmdSelf, _G["cmdString"])
								end
								cDelay = cDelay + (delay * 10)
							end
							if not DEBUG then
								mq.cmdf("/timed %s, %s %s",cDelay,cmdSelf, _G["cmdString"])
							else
								 printf("/timed %s, %s %s",cDelay,cmdSelf, _G["cmdString"])
							end
						end
						ImGui.SameLine()
						if ImGui.Button('Zone Members ##DialogDBCombined') then
							if not DEBUG then
								mq.cmdf("/multiline ; %s/target %s; /timed 5, %s%s %s",cmdZone, CurrTarget,cmdZone,cmdSelf, _G["cmdString"])
							else
								 printf("/multiline ; %s/target %s; /timed 5, %s%s %s",cmdZone, CurrTarget,cmdZone,cmdSelf, _G["cmdString"])
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
		local openC, showC = ImGui.Begin("NPC Dialog Config##Dialog_Config", true, ImGuiWindowFlags.None)
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
		local tmpGpCmd = cmdGroup or ''
		local tmpZnCmd = cmdZone or ''
		local tmpChCmd = cmdChar or ''
		local tmpSlCmd = cmdSelf or ''

		ImGui.SeparatorText("Command's Config")

		ImGui.BeginTable("Command Config##DialogConfigTable", 2, ImGuiTableFlags.Borders)
		ImGui.TableSetupColumn("##DialogConfigCol1", ImGuiTableColumnFlags.WidthFixed, 380)
		ImGui.TableSetupColumn("##DialogConfigCol2", ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableNextRow()
		ImGui.TableNextColumn()
		tmpGpCmd, _ = ImGui.InputText("Group Command##DialogConfig", tmpGpCmd)
		if tmpGpCmd ~= cmdGroup then
			cmdGroup = tmpGpCmd
		end
		ImGui.TableNextColumn()
		if ImGui.Button("Set Group Command##DialogConfig") then
			Config.cmdGroup = tmpGpCmd
			mq.pickle(dialogConfig, Config)
		end
		ImGui.TableNextRow()
		ImGui.TableNextColumn()
		tmpZnCmd, _ = ImGui.InputText("Zone Command##DialogConfig", tmpZnCmd)	
		if tmpZnCmd ~= cmdZone then
			cmdZone = tmpZnCmd
		end
		ImGui.TableNextColumn()
		if ImGui.Button("Set Zone Command##DialogConfig") then
			Config.cmdZone = tmpZnCmd
			mq.pickle(dialogConfig, Config)
		end
		ImGui.TableNextRow()
		ImGui.TableNextColumn()
		tmpChCmd, _ = ImGui.InputText("Character Command##DialogConfig", tmpChCmd)
		if tmpChCmd ~= cmdChar then
			cmdChar = tmpChCmd
		end
		ImGui.TableNextColumn()
		if ImGui.Button("Set Character Command##DialogConfig") then
			Config.cmdChar = tmpChCmd
			mq.pickle(dialogConfig, Config)
		end
		ImGui.TableNextRow()
		ImGui.TableNextColumn()
		tmpSlCmd, _ = ImGui.InputText("Self Command##DialogConfig", tmpSlCmd)
		if tmpSlCmd ~= cmdSelf then
			cmdSelf = tmpSlCmd
		end
		ImGui.TableNextColumn()
		if ImGui.Button("Set Single Command##DialogConfig") then
			Config.cmdSelf = tmpSlCmd
			mq.pickle(dialogConfig, Config)
		end
		ImGui.EndTable()
		ImGui.Separator()
		--- Dialog Config Table
		if tmpTarget ~= nil and tmpTarget ~= 'None' then
			local sizeX, sizeY = ImGui.GetContentRegionAvail()
			ImGui.BeginChild("DialogConfigChild", sizeX,sizeY -30,bit32.bor(ImGuiChildFlags.Border, ImGuiChildFlags.AutoResizeY))
			ImGui.SeparatorText(tmpTarget.."'s Dialogs")
			ImGui.BeginTable("NPC Dialogs##DialogConfigTable2", 5, ImGuiTableFlags.Borders)
			ImGui.TableSetupScrollFreeze(0, 1)
			ImGui.TableSetupColumn("NPC##DialogDB_Config", ImGuiTableColumnFlags.WidthFixed, 100)
			ImGui.TableSetupColumn("Zone##DialogDB_Config", ImGuiTableColumnFlags.WidthFixed, 100)
			ImGui.TableSetupColumn("Description##DialogDB_Config", ImGuiTableColumnFlags.WidthFixed, 100)
			ImGui.TableSetupColumn("Trigger##DialogDB_Config", ImGuiTableColumnFlags.WidthFixed, 100)
			ImGui.TableSetupColumn("##DialogDB_Config_Save", ImGuiTableColumnFlags.WidthStretch)
			ImGui.TableHeadersRow()
			local id = 1
			if Dialog[serverName][tmpTarget] == nil then
				Dialog[serverName][tmpTarget] = {allzones = {}, [curZone] = {}}
				newTarget = true
			else
				for z, zData in pairs(Dialog[serverName][tmpTarget]) do
					for d, c in pairs(zData) do
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
						if ImGui.Button("Delete##DialogDB_Config_"..id) then
							Dialog[serverName][tmpTarget][z][d] = nil
							mq.pickle(dialogData, Dialog)
						end
						ImGui.SameLine()
						if ImGui.Button("Edit##DialogDB_Config_Edit_"..id) then
							eZone = z
							eTar = tmpTarget
							eDes = d
							eCmd = c
							newCmd = c
							newDesc = d
							editGUI = true
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
			ImGui.EndChild()
		end

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
		end
		if checkDialog() then
			ShowDialog = true
		else
			ShowDialog = false
			if CurrTarget ~= mq.TLO.Target.DisplayName() then tmpDesc = '' end
		end
		mq.delay(1000)
	end
	mq.exit()
end

init()
mainLoop()