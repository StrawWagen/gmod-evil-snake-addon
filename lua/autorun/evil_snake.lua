AddCSLuaFile("evil_snake/sh_settings.lua")
AddCSLuaFile("evil_snake/cl_settings.lua")
include("evil_snake/sh_settings.lua")
if CLIENT then
	include("evil_snake/cl_settings.lua")
end
