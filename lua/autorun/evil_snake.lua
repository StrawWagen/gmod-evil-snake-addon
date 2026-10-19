if not file.Exists("evil_api/init.lua", "LUA") then return ErrorNoHalt("Evil snake needs Syhgma's Evil API\n") end
include("evil_api/init.lua")

AddCSLuaFile("evil_snake/sh_settings.lua")
AddCSLuaFile("evil_snake/sh_body.lua")
AddCSLuaFile("evil_snake/sh_stomach.lua")
AddCSLuaFile("evil_snake/sh_knock.lua")
AddCSLuaFile("evil_snake/cl_util.lua")
AddCSLuaFile("evil_snake/cl_body.lua")
AddCSLuaFile("evil_snake/cl_stomach.lua")
AddCSLuaFile("evil_snake/cl_knock.lua")
include("evil_snake/sh_settings.lua")
include("evil_snake/sh_body.lua")
include("evil_snake/sh_stomach.lua")
include("evil_snake/sh_knock.lua")
if SERVER then
	include("evil_snake/sv_chain.lua")
	include("evil_snake/sv_brain.lua")
	include("evil_snake/sv_stomach.lua")
	include("evil_snake/sv_knock.lua")
	include("evil_snake/sv_debug.lua")
	include("evil_snake/sv_stomach_view.lua")
else
	include("evil_snake/cl_util.lua")
	include("evil_snake/cl_body.lua")
	include("evil_snake/cl_stomach.lua")
	include("evil_snake/cl_knock.lua")
end
