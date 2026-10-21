if SERVER then resource.AddWorkshop("3823740816") end
if not file.Exists("evil_api/init.lua", "LUA") then
	EvilNeedsAPI = EvilNeedsAPI or {}
	EvilNeedsAPI[#EvilNeedsAPI + 1] = "Evil snake"
	if #EvilNeedsAPI > 1 then return end

	local API = "3823740816"
	local URL = "https://steamcommunity.com/sharedfiles/filedetails/?id=" .. API
	local RED = Color(255, 90, 90)

	local function Needs()
		return table.concat(EvilNeedsAPI, ", ") .. (#EvilNeedsAPI > 1 and " need" or " needs") .. " Syhgma's Evil API now."
	end

	hook.Add("Initialize", "EvilNeedsAPI", function()
		local fix = SERVER and game.IsDedicated() and "Add it to the server's workshop collection, then restart." or "Subscribe to it, then restart the game."
		MsgC(RED, Needs() .. " " .. fix .. " " .. URL .. "\n")
	end)
	if SERVER then return end

	hook.Add("InitPostEntity", "EvilNeedsAPI", function()
		chat.AddText(RED, Needs() .. " Subscribe to it, then restart the game.")

		local frame = vgui.Create("DFrame")
		frame:SetTitle("Syhgma's Evil API")
		frame:SetSize(420, 140)
		frame:Center()
		frame:MakePopup()

		local open = vgui.Create("DButton", frame)
		open:Dock(BOTTOM)
		open:SetTall(30)
		open:SetText("Open it on the Workshop")
		function open:DoClick()
			if steamworks and steamworks.ViewFile then
				steamworks.ViewFile(API)
			else
				gui.OpenURL(URL)
			end
		end

		local text = vgui.Create("DLabel", frame)
		text:Dock(FILL)
		text:DockMargin(4, 4, 4, 8)
		text:SetWrap(true)
		text:SetText(Needs() .. " Subscribe to it, then restart the game.")
	end)
	return
end
include("evil_api/init.lua")

AddCSLuaFile("evil_snake/sh_settings.lua")
AddCSLuaFile("evil_snake/sh_body.lua")
AddCSLuaFile("evil_snake/sh_stomach.lua")
AddCSLuaFile("evil_snake/cl_util.lua")
AddCSLuaFile("evil_snake/cl_skin.lua")
AddCSLuaFile("evil_snake/cl_eyes.lua")
AddCSLuaFile("evil_snake/cl_head.lua")
AddCSLuaFile("evil_snake/cl_body.lua")
AddCSLuaFile("evil_snake/cl_stomach.lua")
AddCSLuaFile("evil_snake/cl_tongue.lua")
AddCSLuaFile("evil_snake/cl_inside.lua")
AddCSLuaFile("evil_snake/cl_thrash.lua")
AddCSLuaFile("evil_snake/cl_propellor.lua")
include("evil_snake/sh_settings.lua")
include("evil_snake/sh_body.lua")
include("evil_snake/sh_stomach.lua")
if SERVER then
	resource.AddFile("materials/killicons/evil_snake.png")
	include("evil_snake/sv_chain.lua")
	include("evil_snake/sv_path.lua")
	include("evil_snake/sv_brain.lua")
	include("evil_snake/sv_stomach.lua")
	include("evil_snake/sv_tongue.lua")
	include("evil_snake/sv_fungus.lua")
	include("evil_snake/sv_propellor.lua")
	include("evil_snake/sv_debug.lua")
	include("evil_snake/sv_enemy.lua")
else
	include("evil_snake/cl_util.lua")
	include("evil_snake/cl_skin.lua")
	include("evil_snake/cl_eyes.lua")
	include("evil_snake/cl_head.lua")
	include("evil_snake/cl_body.lua")
	include("evil_snake/cl_tongue.lua")
	include("evil_snake/cl_stomach.lua")
	include("evil_snake/cl_inside.lua")
	include("evil_snake/cl_thrash.lua")
	include("evil_snake/cl_propellor.lua")
end
