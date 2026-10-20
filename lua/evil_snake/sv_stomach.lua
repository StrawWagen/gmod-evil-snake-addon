EvilSnake = EvilSnake or {}
local Stomach = {}
Stomach.__index = Stomach
EvilSnake.Stomach = Stomach

local Setting = EvilSnake.Setting

local PREY_SIZE = 40
local PREY_SCALE = { 0.6, 1.6 }
local MAX_TRANSIT = 32
local DIGESTED_HOLD = 1.5

function Stomach.New()
	return setmetatable({ victims = {}, transit = {}, rev = 0 }, Stomach)
end

function Stomach:Add(v)
	v.n = #self.victims + 1
	v.at = v.at or CurTime()
	v.kind = v.kind or "thing"
	v.size = v.size or 1
	v.mass = v.mass or v.size
	v.brain = v.brain or EvilSnake.Brainpower(v.kind)
	v.digested = v.digested or false
	self.victims[v.n] = v
	return v
end

function EvilSnake.PreySize(ent)
	return math.Clamp(ent:BoundingRadius() / PREY_SIZE, PREY_SCALE[1], PREY_SCALE[2])
end

function EvilSnake.BulgeSize(size)
	return 1 + (Setting("bulge_size") - 1) * size
end

local function Weapon(ent)
	local wep = ent.GetActiveWeapon and ent:GetActiveWeapon()
	return IsValid(wep) and wep:GetClass() or nil
end

local function Name(ent)
	if ent:IsPlayer() then return ent:Nick() end
	local name = ent:GetName()
	return name ~= "" and name or ent:GetClass()
end

function Stomach:Record(ent)
	local player = ent:IsPlayer()
	return self:Add({
		class = ent:GetClass(),
		name = Name(ent),
		model = ent:GetModel(),
		player = player,
		steamid = player and ent:SteamID64() or nil,
		kind = EvilSnake.Kind(ent),
		weapon = Weapon(ent),
		health = ent:GetMaxHealth(),
		size = EvilSnake.PreySize(ent),
	})
end

function Stomach:Settle(v)
	if v.digested then return end
	v.digested = CurTime()
	if self.onDigest then self.onDigest(v) end
end

local function Leave(ply)
	if ply.EvilSnakeMeal then ply.EvilSnakeMeal.ply = nil end
	ply.EvilSnakeMeal, ply.EvilSnakeSkip, ply.EvilSnakeSkipReady, ply.EvilSnakeDone = nil, nil, nil, nil
	ply:SetNW2Bool("EvilSnakeInside", false)
	ply:SetNW2Bool("EvilSnakeDone", false)
	ply:SetNW2Float("EvilSnakeSkip", 0)
end

local function Out(m)
	local ply = m.ply
	if IsValid(ply) and ply.EvilSnakeMeal == m then Leave(ply) end
	m.ply = nil
end

local function Done(m)
	local ply = m.ply
	m.ply = nil
	if not IsValid(ply) or ply.EvilSnakeMeal ~= m then return end
	ply.EvilSnakeDone = CurTime() + DIGESTED_HOLD
	ply.EvilSnakeSkip = nil
	ply:SetNW2Float("EvilSnakeSkip", 0)
	ply:SetNW2Bool("EvilSnakeDone", true)
end

function Stomach:Pass(m)
	Done(m)
	self:Settle(m.victim)
end

function Stomach:Vacate()
	for _, m in ipairs(self.transit) do Out(m) end
end

function Stomach:Swallow(ent, at)
	local v = self:Record(ent)
	if #self.transit >= MAX_TRANSIT then self:Pass(table.remove(self.transit, 1)) end
	local m = { victim = v, at = at or 0, size = EvilSnake.BulgeSize(v.size), ply = ent:IsPlayer() and ent or nil }
	self.transit[#self.transit + 1] = m
	if m.ply then
		if ent.EvilSnakeMeal then Leave(ent) end
		ent.EvilSnakeMeal = m
		ent:SetNW2Bool("EvilSnakeInside", true)
	end
	return v
end

hook.Add("PlayerSpawn", "EvilSnakeInside", function(ply)
	if ply.EvilSnakeMeal then Leave(ply) end
end)

local function Unskip(ply)
	if not ply.EvilSnakeSkip then return end
	ply.EvilSnakeSkip = nil
	ply:SetNW2Float("EvilSnakeSkip", 0)
end

hook.Add("PlayerDeathThink", "EvilSnakeInside", function(ply)
	if not ply.EvilSnakeMeal then return end
	local now = CurTime()
	if ply.EvilSnakeDone then
		if now >= ply.EvilSnakeDone then ply:Spawn() end
		return false
	end
	local down = ply:KeyDown(IN_JUMP)
	if not down then ply.EvilSnakeSkipReady = true end
	if Setting("skip_swallow") == 0 or not down or not ply.EvilSnakeSkipReady then
		Unskip(ply)
		return false
	end
	if not ply.EvilSnakeSkip then
		ply.EvilSnakeSkip = now
		ply:SetNW2Float("EvilSnakeSkip", now)
	end
	if now - ply.EvilSnakeSkip >= EvilSnake.SKIP_HOLD then ply:Spawn() end
	return false
end)

function Stomach:Digest(dt, links, link)
	local transit = self.transit
	if #transit == 0 then return false end
	local rate = Setting("bulge_speed") / link * dt
	for i = #transit, 1, -1 do
		local m = transit[i]
		m.at = m.at + rate
		if m.at >= links then self:Pass(table.remove(transit, i)) end
	end
	return true
end

function Stomach:Count()
	return #self.victims
end

function Stomach:Mass()
	local mass = 0
	for _, v in ipairs(self.victims) do
		if v.digested then mass = mass + v.mass end
	end
	return mass
end

function Stomach:Eating(links)
	local mass = 0
	for _, m in ipairs(self.transit) do
		mass = mass + m.victim.mass * math.Clamp(m.at / links, 0, 1)
	end
	return mass
end

function Stomach:Length(base, mass)
	return EvilSnake.GrownLength(base, mass or self:Mass())
end

function Stomach:Girth(mass)
	return EvilSnake.GrownGirth(mass or self:Mass())
end
