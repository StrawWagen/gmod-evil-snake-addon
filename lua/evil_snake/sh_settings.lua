EvilSnake = EvilSnake or {}

EvilSnake.SETTINGS = {
	{ name = "hunt_npcs", default = 1, min = 0, max = 1, label = "Hunts NPCs",
		help = "Goes after NPCs and swallows them. At 0 it leaves them alone" },
	{ name = "sight_range", default = 3000, min = 0, max = 10000, decimals = 0, label = "Sight range",
		help = "How far away it notices NPCs" },
	{ name = "bite_reach", default = 24, min = 0, max = 200, decimals = 0, label = "Bite reach",
		help = "How close its mouth has to get to someone to swallow them" },
	{ name = "bulge_size", default = 1.8, min = 1, max = 4, decimals = 2, label = "Bulge size",
		help = "How fat a swallowed victim makes the body, in body thicknesses. Bigger victims bulge more" },
	{ name = "bulge_speed", default = 80, min = 5, max = 1000, decimals = 0, label = "Bulge speed",
		help = "How fast a swallowed victim travels down to the tail" },
	{ name = "growth", default = 2, min = 0, max = 20, decimals = 0, label = "Growth per meal",
		help = "Segments it gains from each victim, bit by bit as they travel down. Bigger victims add more" },
	{ name = "fattening", default = 0.15, min = 0, max = 1, decimals = 2, label = "Fattening",
		help = "How much thicker it gets from everyone it has eaten. Each meal adds less than the last" },
	{ name = "girth_max", default = 3, min = 1, max = 8, decimals = 2, label = "Max fattening",
		help = "Thickest eating can make it, in starting thicknesses" },
	{ name = "learning", default = 1, min = 0, max = 5, decimals = 2, label = "Learning",
		help = "How much it takes from the minds of what it eats" },
	{ name = "habituation", default = 0.5, min = 0, max = 5, decimals = 2, label = "Habituation",
		help = "How fast eating the same kind of thing over and over stops teaching it anything" },
	{ name = "wander", default = 1, min = 0, max = 1, label = "Wanders",
		help = "Crawls around on its own when there is nothing to hunt" },
	{ name = "hunt_speed", default = 170, min = 0, max = 1000, decimals = 0, label = "Hunting speed",
		help = "How fast the head moves when it is going after someone" },
	{ name = "wander_speed", default = 60, min = 0, max = 1000, decimals = 0, label = "Wander speed",
		help = "How fast the head moves when it is just crawling around" },
	{ name = "turn_rate", default = 120, min = 10, max = 720, decimals = 0, label = "Turn rate",
		help = "Degrees a second the head can turn" },
	{ name = "sway", default = 35, min = 0, max = 80, decimals = 0, label = "Sway",
		help = "Degrees the head swings either side of where it is going. At 0 it slides along in a straight line" },
	{ name = "wavelength", default = 150, min = 40, max = 600, decimals = 0, label = "Wave length",
		help = "Distance the head covers in one full swing left and right" },
	{ name = "follow", default = 0.5, min = 0, max = 1, decimals = 2, label = "Path following",
		help = "How tightly the body sticks to the path the head took. At 0 it gets dragged like a rope" },
	{ name = "step_height", default = 18, min = 0, max = 64, decimals = 0, label = "Step height",
		help = "Tallest ledge it climbs straight over" },
	{ name = "segments", default = 28, min = 4, max = 80, decimals = 0, label = "Body segments",
		help = "Segments new snakes spawn with. Each one adds a segment length of body" },
	{ name = "segment_length", default = 17, min = 4, max = 64, decimals = 0, label = "Segment length" },
	{ name = "radius", default = 14, min = 2, max = 64, decimals = 0, label = "Thickness" },
	{ name = "head_size", default = 1.2, min = 1, max = 2, decimals = 2, label = "Head size",
		help = "How many times thicker the head is than the body" },
	{ name = "tail_length", default = 0.3, min = 0.05, max = 1, decimals = 2, label = "Tail length",
		help = "How much of the body tapers down to the tail tip" },
	{ name = "color", default = 9858664, min = 0, max = 16777215, color = true, label = "Colour" },
	{ name = "gravity", default = 600, min = 0, max = 3000, decimals = 0, label = "Gravity" },
	{ name = "grip_along", default = 0.3, min = 0, max = 5, decimals = 2, label = "Lengthwise grip",
		help = "Ground friction against the body sliding along its length" },
	{ name = "grip_side", default = 1.2, min = 0, max = 5, decimals = 2, label = "Sideways grip",
		help = "Ground friction against the body sliding sideways" },
	{ name = "bend", default = 1.3, min = 0, max = 2, decimals = 2, label = "Bend limit",
		help = "Closest every other joint can get, in segment lengths. Lower lets it coil tighter" },
	{ name = "solver_passes", default = 8, min = 1, max = 32, decimals = 0, label = "Solver passes",
		help = "Physics passes per step. More keeps the body from stretching but costs more" },
}

local convars, byConVar = {}, {}
for _, s in ipairs(EvilSnake.SETTINGS) do
	s.convar = "evil_snake_" .. s.name
	convars[s.name] = CreateConVar(s.convar, tostring(s.default), bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), s.help or "", s.min, s.max)
	byConVar[s.convar] = s
end

function EvilSnake.Setting(name)
	return convars[name]:GetFloat()
end

function EvilSnake.Color()
	local v = convars.color:GetInt()
	return bit.rshift(v, 16), bit.band(bit.rshift(v, 8), 255), bit.band(v, 255)
end

if CLIENT then return end

util.AddNetworkString("EvilSnakeSetting")

net.Receive("EvilSnakeSetting", function(_, ply)
	local s = byConVar[net.ReadString()]
	local value = tonumber(net.ReadString())
	if not s or not value or not IsValid(ply) or not ply:IsSuperAdmin() then return end
	RunConsoleCommand(s.convar, tostring(math.Clamp(value, s.min, s.max)))
end)
