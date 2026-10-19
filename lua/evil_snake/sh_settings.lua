EvilSnake = EvilSnake or {}

EvilSnake.SETTINGS = {
	{ name = "segments", default = 28, min = 4, max = 80, decimals = 0, label = "Body segments",
		help = "Each segment adds 17 units of body. Applies to snakes spawned after the change" },
}

local convars, byConVar = {}, {}
for _, s in ipairs(EvilSnake.SETTINGS) do
	s.convar = "evil_snake_" .. s.name
	convars[s.name] = CreateConVar(s.convar, tostring(s.default), bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), s.help, s.min, s.max)
	byConVar[s.convar] = s
end

function EvilSnake.Setting(name)
	return convars[name]:GetFloat()
end

if CLIENT then return end

util.AddNetworkString("EvilSnakeSetting")

net.Receive("EvilSnakeSetting", function(_, ply)
	local s = byConVar[net.ReadString()]
	local value = tonumber(net.ReadString())
	if not s or not value or not IsValid(ply) or not ply:IsSuperAdmin() then return end
	RunConsoleCommand(s.convar, tostring(math.Clamp(value, s.min, s.max)))
end)
