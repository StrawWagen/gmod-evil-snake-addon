AddCSLuaFile("evil_snake/sh_settings.lua")
AddCSLuaFile("evil_snake/sh_body.lua")
AddCSLuaFile("evil_snake/cl_settings.lua")
AddCSLuaFile("evil_snake/cl_util.lua")
AddCSLuaFile("evil_snake/cl_body.lua")
include("evil_snake/sh_settings.lua")
include("evil_snake/sh_body.lua")
if SERVER then
	include("evil_snake/sv_chain.lua")
else
	include("evil_snake/cl_settings.lua")
	include("evil_snake/cl_util.lua")
	include("evil_snake/cl_body.lua")
end
