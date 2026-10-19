AddCSLuaFile("evil_snake/sh_settings.lua")
AddCSLuaFile("evil_snake/cl_settings.lua")
AddCSLuaFile("evil_snake/cl_tube.lua")
AddCSLuaFile("evil_snake/cl_body.lua")
AddCSLuaFile("evil_snake/cl_mouth.lua")
include("evil_snake/sh_settings.lua")
if CLIENT then
	include("evil_snake/cl_settings.lua")
	include("evil_snake/cl_tube.lua")
	include("evil_snake/cl_body.lua")
	include("evil_snake/cl_mouth.lua")
end
