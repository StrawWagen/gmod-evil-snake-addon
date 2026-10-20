EvilSnake = EvilSnake or {}
local Brain = {}
Brain.__index = Brain
EvilSnake.Brain = Brain

local Setting = EvilSnake.Setting

local OPEN = 0.35
local ARMED = 0.3
local BULK = 0.5

EvilSnake.ASPECTS = { "cunning", "tactics", "firearms", "strength", "agility", "resilience", "hunger", "energy", "fear" }

local KINDS = {}
for name, kind in pairs({
	CLASS_PLAYER_ALLY = "rebel", CLASS_PLAYER_ALLY_VITAL = "rebel", CLASS_CITIZEN_REBEL = "rebel",
	CLASS_CITIZEN_PASSIVE = "citizen", CLASS_HUMAN_PASSIVE = "citizen",
	CLASS_COMBINE = "soldier", CLASS_METROPOLICE = "soldier", CLASS_MILITARY = "soldier", CLASS_CONSCRIPT = "soldier",
	CLASS_HUMAN_MILITARY = "soldier",
	CLASS_COMBINE_GUNSHIP = "machine", CLASS_COMBINE_HUNTER = "machine", CLASS_MANHACK = "machine", CLASS_SCANNER = "machine",
	CLASS_MACHINE = "machine", CLASS_PROTOSNIPER = "machine",
	CLASS_STALKER = "stalker",
	CLASS_VORTIGAUNT = "vortigaunt",
	CLASS_ZOMBIE = "zombie",
	CLASS_HEADCRAB = "headcrab",
	CLASS_ANTLION = "antlion",
	CLASS_BARNACLE = "beast", CLASS_BULLSQUID = "beast", CLASS_HOUNDEYE = "beast", CLASS_EARTH_FAUNA = "beast",
	CLASS_ALIEN_MONSTER = "beast", CLASS_ALIEN_PREY = "beast", CLASS_ALIEN_PREDATOR = "beast", CLASS_ALIEN_MILITARY = "beast",
}) do
	if _G[name] then KINDS[_G[name]] = kind end
end

local KINDS_INFO = {
	player = { brain = 1, teach = { cunning = 1, agility = 0.6, tactics = 0.4 } },
	rebel = { brain = 0.3, teach = { tactics = 0.5, firearms = 0.4, fear = 0.2 } },
	citizen = { brain = 0.3, teach = { fear = 1, cunning = 0.2 } },
	soldier = { brain = 0.3, teach = { tactics = 1, firearms = 0.5, resilience = 0.2 } },
	machine = { brain = 0.1, teach = { resilience = 0.6, energy = 0.4, tactics = 0.2 } },
	stalker = { brain = 0.15, teach = { energy = 0.4, resilience = 0.4, cunning = -0.2 } },
	vortigaunt = { brain = 0.5, teach = { energy = 1, cunning = 0.5 } },
	zombie = { brain = 0.1, teach = { hunger = 1, resilience = 0.6, cunning = -0.3 } },
	headcrab = { brain = 0.03, teach = { agility = 0.8, hunger = 0.4 } },
	antlion = { brain = 0.05, teach = { strength = 0.6, agility = 0.4, hunger = 0.3 } },
	beast = { brain = 0.02, teach = { hunger = 0.5, strength = 0.3 } },
	thing = { brain = 0.05, teach = { hunger = 0.2 } },
}
EvilSnake.KINDS = KINDS_INFO

local RESONANCE = {
	firearms = { tactics = 0.5 },
	tactics = { cunning = 0.5, fear = -0.3 },
	cunning = { energy = 0.3, hunger = -0.4 },
	energy = { cunning = 0.3 },
	agility = { strength = 0.2, fear = 0.3 },
	strength = { hunger = 0.3 },
	resilience = { hunger = 0.3, energy = 0.2 },
	hunger = { cunning = -0.3 },
	fear = { cunning = 0.3 },
}

local TRICKS = {
	slipped = { full = 3, teach = { strength = 0.6, resilience = 0.4 } },
	outran = { full = 3, teach = { energy = 0.6, tactics = 0.4 } },
	dodged = { full = 3, teach = { agility = 0.6, cunning = 0.3 } },
}
EvilSnake.TRICKS = TRICKS

local full = {}
for trick, t in pairs(TRICKS) do full[trick] = t.full end
EvilSnake.Souls = Evil.SoulDigestion({ id = "evil_snake", tricks = full })

function EvilSnake.Watch(ply, trick)
	EvilSnake.Souls:Watch(ply, trick)
end

function EvilSnake.Kind(ent)
	if ent:IsPlayer() then return "player" end
	return ent:IsNPC() and KINDS[ent:Classify()] or "thing"
end

function EvilSnake.Brainpower(kind, tricks)
	local base = (KINDS_INFO[kind] or KINDS_INFO.thing).brain
	local brain = base
	for _, k in pairs(tricks or {}) do brain = brain + base * k end
	return brain
end

function EvilSnake.Worth(ent)
	return EvilSnake.Brainpower(EvilSnake.Kind(ent), ent:IsPlayer() and EvilSnake.Souls:Skills(ent) or nil)
end

function Brain.New()
	return setmetatable({ power = 0, know = {}, seen = {} }, Brain)
end

function Brain:Total()
	return self.power * Setting("learning")
end

function Brain:Level()
	return math.log(1 + self:Total()) / math.log(2)
end

function Brain:Grasp()
	return 1 - 1 / (1 + self:Total())
end

function Brain:Knows(aspect)
	return 1 - 1 / (1 + (self.know[aspect] or 0))
end

local function Teaches(v)
	local teach = table.Copy((KINDS_INFO[v.kind] or KINDS_INFO.thing).teach)
	if v.weapon then teach.firearms = (teach.firearms or 0) + ARMED end
	if v.size > 1 then teach.strength = (teach.strength or 0) + (v.size - 1) * BULK end
	for trick, k in pairs(v.tricks or {}) do
		for aspect, w in pairs(TRICKS[trick] and TRICKS[trick].teach or {}) do teach[aspect] = (teach[aspect] or 0) + w * k end
	end
	return teach
end

function Brain:Edge(aspect)
	return self:Knows(aspect) * Setting("wits")
end

function Brain:Resonance(aspect)
	local r = 1
	for from, w in pairs(RESONANCE[aspect] or {}) do r = r + w * self:Knows(from) end
	return math.max(0, r)
end

function Brain:Learn(v)
	local seen = self.seen[v.kind] or 0
	local novelty = 1 / (1 + seen * Setting("habituation"))
	local grasp = OPEN + (1 - OPEN) * self:Grasp()
	local scale = v.brain * novelty * grasp * Setting("learning")
	local lessons = {}
	for aspect, w in pairs(Teaches(v)) do
		local gain = w * scale * self:Resonance(aspect)
		lessons[aspect] = math.max(gain, -(self.know[aspect] or 0))
	end
	for aspect, gain in pairs(lessons) do self.know[aspect] = (self.know[aspect] or 0) + gain end
	self.seen[v.kind] = seen + 1
	self.power = self.power + v.brain
	v.lessons = lessons
	return lessons
end

function Brain.Rebuild(victims)
	local brain = Brain.New()
	for _, v in ipairs(victims) do
		if v.digested then brain:Learn(v) end
	end
	return brain
end
