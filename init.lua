local mq = require('mq')
local ImGui = require('ImGui')
Icons = require('mq.ICONS')
local hIcon = Icons.MD_HIGHLIGHT_OFF
local Running = false
local hasDialog = false
local Dialog = require('npc_dialog')
local curZone = mq.TLO.Zone.ShortName() or 'None'
local serverName = mq.TLO.EverQuest.Server()
local ShowDialog = false
local tmpName = ''
local target = mq.TLO.Target.DisplayName() or 'None'
local dialogData = mq.configDir ..'/npc_dialog.lua'
local winFlags = bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.AlwaysAutoResize)
local delay = 1

---comment Check to see if the file we want to work on exists.
---@param name string -- Full Path to file
---@return boolean -- returns true if the file exists and false otherwise
local function File_Exists(name)
	local f=io.open(name,"r")
	if f~=nil then io.close(f) return true else return false end
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
end	

local function checkDialog()
	hasDialog = false
	
	if mq.TLO.Target() ~= nil then
		curZone = mq.TLO.Zone.ShortName() or 'None'
		target = mq.TLO.Target.DisplayName()
		-- printf("Server: %s  Zone: %s Target: %s",serverName,curZone,target)
		if Dialog[serverName] == nil then
			hasDialog = false
			
		elseif Dialog[serverName][target] == nil then
			hasDialog = false
		
		elseif Dialog[serverName][target][curZone] == nil and Dialog[serverName][target]['allzones'] == nil then
			hasDialog = false
			
		elseif Dialog[serverName][target][curZone] ~= nil or Dialog[serverName][target]['allzones'] ~= nil then
			hasDialog = true
		else
			hasDialog = false
		end
	else
		hasDialog = false
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
		printHelp()
		print("No String Supplied try again~")
		return
	end
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
			local name = mq.TLO.Target.DisplayName() or 'None'
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
local tmpName = tmpName or ''
local function GUI_Main()
	if not ShowDialog then return end
	local open, show = ImGui.Begin("NPC Dialog##Dialog_Main", true, winFlags)
	if not show then
		ImGui.End()
		return
	end
	if checkDialog() then
		if hasDialog then
			ImGui.Text(string.format("%s's Dialog", target))

			-- Function to merge dialogues and handle Dialog display
			local function handleCombinedDialog()
				local allZonesTable = Dialog[serverName][target]['allzones'] or {}
				local curZoneTable = Dialog[serverName][target][curZone] or {}
				local combinedTable = {}

				-- First, fill combinedTable with all zones data
				for k, v in pairs(allZonesTable) do
					combinedTable[k] = v
				end
				-- Then, override or add with current zone data
				for k, v in pairs(curZoneTable) do
					combinedTable[k] = v
				end

				if next(combinedTable) ~= nil then

					local sortedKeyList = sortedKeys(combinedTable)
					if combinedTable[tmpName] == nil then
						tmpName = 'None'
					end
					ImGui.SetNextItemWidth(200)
					if ImGui.BeginCombo("##DialogDBCombined", tmpName) then
						for _, name in pairs(sortedKeyList) do
							local isSelected = (name == tmpName)
							if ImGui.Selectable(name, isSelected) then
								tmpName = name
								_G["cmdString"] = combinedTable[name] -- Global to maintain state outside of this function
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
							mq.cmdf("/say %s", _G["cmdString"])
						end
						ImGui.SameLine()
						if ImGui.Button('Group Say ##DialogDBCombined') then
							local cDelay = delay * 10
							for i = 1, mq.TLO.Me.GroupSize() - 1 do
								local pName = mq.TLO.Group.Member(i).DisplayName()
								mq.cmdf("/multiline ; /dex %s /target %s; /dex %s /timed %s, /say %s",pName, target,pName ,cDelay, _G["cmdString"])
								printf("/multiline ; /dex %s /target %s; /dex %s /timed %s, /say %s",pName, target,pName ,cDelay, _G["cmdString"])
								cDelay = cDelay + (delay * 10)

							end
							mq.cmdf("/timed %s, /say %s",cDelay, _G["cmdString"])
							printf("/timed %s, /say %s",cDelay, _G["cmdString"])

						end
						ImGui.SameLine()
						local tmpDelay = delay
						ImGui.SetNextItemWidth(75)
						tmpDelay = ImGui.InputInt("Delay##DialogDBCombined", tmpDelay, 1, 1)
						if tmpDelay ~= delay then
							delay = tmpDelay
						end
					end
				end
			end

			-- Handle Dialogues with combined data
			handleCombinedDialog()


		end
	end
	ImGui.End()
end

local function init()
	if mq.TLO.MacroQuest.BuildName() ~= 'Emu' then serverName = 'Live' end -- really only care about server name for EMU as the dialogs may vary from serever to server to server
	if not File_Exists(dialogData) then
		mq.pickle(dialogData, Dialog)
	else
		Dialog = dofile(dialogData)
	end
	Running = true
	mq.bind('/dialogdb', bind)
	mq.imgui.init("Npc Dialog", GUI_Main)
	printHelp()
end

local function mainLoop()
	while Running do
		if mq.TLO.Me.Zoning() then
			tmpName = ''
			target = 'None'
			hasDialog = false
			ShowDialog = false
		end
		if checkDialog() then
			ShowDialog = true
		else
			ShowDialog = false
			if target ~= mq.TLO.Target.DisplayName() then tmpName = '' end
		end
		mq.delay(1000)
	end
	mq.exit()
end

init()
mainLoop()