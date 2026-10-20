util.AddNetworkString("EvilSnakeStomach")

local GAP = 0.1
local CHUNK = 64

local function Round(x)
	return math.Round(x, 4)
end

local function Lessons(v)
	if not v.lessons then return nil end
	local out = {}
	for aspect, gain in pairs(v.lessons) do out[aspect] = Round(gain) end
	return out
end

local function Record(v)
	return {
		n = v.n, name = v.name, class = v.class, model = v.model, steamid = v.steamid, kind = v.kind,
		weapon = v.weapon, health = v.health, size = Round(v.size), mass = Round(v.mass), brain = v.brain,
		at = v.at, digested = v.digested or nil, lessons = Lessons(v), tricks = v.tricks,
	}
end

local function Summary(ent)
	local mind = ent.Mind
	local knows = {}
	for i, aspect in ipairs(EvilSnake.ASPECTS) do knows[i] = { aspect, Round(mind:Knows(aspect)) } end
	knows[#knows + 1] = { "untenable", Round(ent.Steadied or 0) }
	return {
		base = ent.BaseSegments, length = Round(ent:GetLength()), girth = Round(ent:GetGirth()),
		power = Round(mind.power), level = Round(mind:Level()), knows = knows,
	}
end

net.Receive("EvilSnakeStomach", function(_, ply)
	local ent = net.ReadEntity()
	local rev = net.ReadUInt(16)
	local have = net.ReadUInt(16)
	local pending = {}
	for i = 1, net.ReadUInt(8) do pending[i] = net.ReadUInt(16) end
	if not IsValid(ent) or ent:GetClass() ~= "evil_snake" or not ent.Stomach or not ent.Mind then return end
	local now = RealTime()
	if now < (ply.EvilSnakeStomachAsk or 0) then return end
	ply.EvilSnakeStomachAsk = now + GAP

	local st = ent.Stomach
	local victims = st.victims
	if rev ~= st.rev then have, pending = 0, {} end
	have = math.min(have, #victims)

	local fresh = {}
	for n = have + 1, math.min(#victims, have + CHUNK) do fresh[#fresh + 1] = Record(victims[n]) end
	local updates = {}
	for _, n in ipairs(pending) do
		local v = n <= have and victims[n]
		if v and v.digested then updates[#updates + 1] = { n = n, digested = v.digested, lessons = Lessons(v) } end
	end
	local links = math.max(#ent.Chain.x - 1, 1)
	local transit = {}
	for _, m in ipairs(st.transit) do transit[#transit + 1] = { m.victim.n, Round(math.Clamp(m.at / links, 0, 1)) } end

	local data = util.Compress(util.TableToJSON({
		rev = st.rev, count = #victims, summary = Summary(ent), victims = fresh, updates = updates, transit = transit,
	}))
	net.Start("EvilSnakeStomach")
	net.WriteEntity(ent)
	net.WriteUInt(#data, 16)
	net.WriteData(data, #data)
	net.Send(ply)
end)
