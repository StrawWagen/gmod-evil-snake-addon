AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("EvilSnakeBody")

local Setting = EvilSnake.Setting

local ASK_GAP = 0.2
local DECIDE = 0.2
local LOSE = 1.25
local STUCK = 0.3
local STUCK_TIME = 1
local DETOUR = 1.5
local WANDER_TURN = 90
local WANDER_TIME = { 3, 7 }
local BITE = "npc/ichthyosaur/snap.wav"
local CRUNCH = { "npc/barnacle/barnacle_crunch2.wav", "npc/barnacle/barnacle_crunch3.wav" }
local SQUISH = {
	"physics/flesh/flesh_squishy_impact_hard1.wav", "physics/flesh/flesh_squishy_impact_hard2.wav",
	"physics/flesh/flesh_squishy_impact_hard3.wav", "physics/flesh/flesh_squishy_impact_hard4.wav",
}
local GULP = { "npc/barnacle/barnacle_gulp1.wav", "npc/barnacle/barnacle_gulp2.wav" }
local GULP_DELAY = 0.35
local BITE_GAP = 0.15
local EAT_LEVEL = 80
local MIN_REACH = 4

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end
	local ent = ents.Create(class)
	ent:SetPos(tr.HitPos)
	ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
	ent:Spawn()
	ent:Activate()
	return ent
end

function ENT:Initialize()
	self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:SetGirth(1)
	self:Bounds()
	self.BaseSegments = math.Round(Setting("segments"))
	self:SetLength(self.BaseSegments)
	local filter = function(e)
		return e ~= self and not e:IsPlayer() and not e:IsNPC() and not e:IsNextBot() and e:GetClass() ~= "evil_snake"
	end
	local joints = EvilSnake.Layout(self:GetPos(), self:GetAngles().y, self.BaseSegments, filter)
	self.Chain = EvilSnake.Chain.New(joints, filter)
	self:SetPos(joints[1])
	self.LastThink = CurTime()
	self.Dirty = true
	self.WanderYaw = self:GetAngles().y
	self.Stomach = EvilSnake.Stomach.New()
	self.Stomach.onDigest = function(v) self:Absorb(v) end
	self.Mind = EvilSnake.Brain.New()
end

function ENT:Bounds()
	local r = self:Radius()
	self:SetCollisionBounds(Vector(-r, -r, -r), Vector(r, r, r))
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:SendBody(ply)
	local x = self.Chain.x
	net.Start("EvilSnakeBody")
	net.WriteEntity(self)
	net.WriteDouble(CurTime() - self.Chain.acc)
	net.WriteUInt(#x, 8)
	for _, p in ipairs(x) do net.WriteVector(p) end
	local transit = self.Stomach.transit
	net.WriteUInt(#transit, 6)
	for _, m in ipairs(transit) do
		net.WriteFloat(m.at)
		net.WriteFloat(m.size)
	end
	if ply then net.Send(ply) else net.Broadcast() end
end

local function Edible(ent)
	return IsValid(ent) and ent:IsNPC() and ent:GetClass() ~= "npc_bullseye" and ent:Health() > 0
end

function ENT:Mouth()
	local x = self.Chain.x
	return x[1] + (x[1] - x[2]):GetNormalized() * self:Radius()
end

function ENT:FindPrey(from)
	local best, bestDist = nil, Setting("sight_range") ^ 2
	for _, ent in ipairs(ents.FindInSphere(from, Setting("sight_range"))) do
		if Edible(ent) then
			local d = from:DistToSqr(ent:WorldSpaceCenter())
			if d < bestDist then best, bestDist = ent, d end
		end
	end
	return best
end

function ENT:Grow()
	local st = self.Stomach
	local mass = st:Mass() + st:Eating(#self.Chain.x - 1)
	self:SetLength(st:Length(self.BaseSegments, mass))
	local girth = st:Girth(mass)
	if math.abs(girth - self.Chain.girth) < 1e-3 then return end
	self:SetGirth(girth)
	EvilSnake.Chain.Swell(self.Chain, girth)
	self:Bounds()
	self.Dirty = true
end

function ENT:Absorb(v)
	local lessons = self.Mind:Learn(v)
	self:Grow()
	hook.Run("EvilSnakeAbsorbed", self, v, lessons)
end

function ENT:Rethink()
	self.Mind = EvilSnake.Brain.Rebuild(self.Stomach.victims)
	self.Stomach.rev = (self.Stomach.rev + 1) % 65536
	self:Grow()
end

function ENT:Chomp(v, now)
	if now < (self.NextBite or 0) then return end
	self.NextBite = now + BITE_GAP
	local volume = EvilSnake.Setting("eat_volume")
	if volume <= 0 then return end
	local mass = math.max(self:Weight(), 1e-3)
	local pitch = math.Clamp(105 / mass ^ 0.1 / v.size ^ 0.25, 50, 160)
	local level = EAT_LEVEL + math.Clamp(math.log(mass, 2) * 2, 0, 10)
	local loud = math.min(volume * (0.7 + 0.3 * v.size), 1)
	self:EmitSound(BITE, level, pitch * math.Rand(0.95, 1.05), loud)
	self:EmitSound(table.Random(CRUNCH), level, pitch * math.Rand(0.9, 1.1), loud)
	self:EmitSound(table.Random(SQUISH), level, pitch * math.Rand(0.9, 1.1), loud * 0.8)
	timer.Simple(GULP_DELAY * v.size, function()
		if IsValid(self) then self:EmitSound(table.Random(GULP), level, pitch * 0.9, loud) end
	end)
end

local function Reaches(ent, from, to, steps, reach)
	for k = 0, steps do
		local at = LerpVector(k / steps, from, to)
		if ent:NearestPoint(at):Distance(at) <= reach then return true end
	end
	return false
end

function ENT:Swallow(now)
	local mouth = self:Mouth()
	local from = self.LastMouth or mouth
	self.LastMouth = mouth
	if Setting("hunt_npcs") == 0 then return end
	local reach = Setting("bite_reach")
	local travel = from:Distance(mouth)
	local steps = math.ceil(travel / math.max(reach, MIN_REACH))
	for _, ent in ipairs(ents.FindInSphere((from + mouth) * 0.5, reach + travel * 0.5)) do
		if Edible(ent) and Reaches(ent, from, mouth, steps, reach) then
			local v = self.Stomach:Swallow(ent)
			self:Chomp(v, now)
			self.Dirty = true
			hook.Run("EvilSnakeSwallowed", self, v, ent)
			ent:Remove()
			if ent == self.Prey then
				self.Prey = nil
				self.NextDecide = now
			end
		end
	end
end

function ENT:Decide(now)
	local c = self.Chain
	local head = c.x[1]
	local yaw = EvilSnake.Chain.HeadYaw(c)
	if self.LastHead and c.speed > 0 then
		local moved = self.LastHead:Distance(head)
		if moved < c.speed * DECIDE * STUCK then
			self.Stuck = (self.Stuck or 0) + DECIDE
		else
			self.Stuck = 0
		end
		if self.Stuck >= STUCK_TIME then
			self.Stuck = 0
			self.WanderYaw = yaw + 180 + math.Rand(-60, 60)
			self.NextWander = now + math.Rand(WANDER_TIME[1], WANDER_TIME[2])
			self.DetourUntil = now + DETOUR
		end
	end
	self.LastHead = Vector(head)

	local prey = self.Prey
	local range = Setting("sight_range")
	if Setting("hunt_npcs") == 0 then
		prey = nil
	elseif not Edible(prey) or head:Distance(prey:WorldSpaceCenter()) > range * LOSE then
		prey = self:FindPrey(head)
	end
	self.Prey = prey

	if prey and now >= (self.DetourUntil or 0) then
		local to = prey:WorldSpaceCenter() - head
		EvilSnake.Chain.Drive(c, math.deg(math.atan2(to.y, to.x)), Setting("hunt_speed"), prey:WorldSpaceCenter())
	elseif prey or Setting("wander") ~= 0 then
		if now >= (self.NextWander or 0) then
			self.WanderYaw = self.WanderYaw + math.Rand(-WANDER_TURN, WANDER_TURN)
			self.NextWander = now + math.Rand(WANDER_TIME[1], WANDER_TIME[2])
		end
		EvilSnake.Chain.Drive(c, self.WanderYaw, Setting("wander_speed"))
	else
		EvilSnake.Chain.Drive(c, yaw, 0)
	end
end

function ENT:Think()
	local now = CurTime()
	local dt = now - self.LastThink
	self.LastThink = now
	local c = self.Chain
	if now >= (self.NextDecide or 0) then
		self.NextDecide = now + DECIDE
		self:Grow()
		self:Decide(now)
	elseif #self.Stomach.transit > 0 then
		self:Grow()
	end
	EvilSnake.Chain.Fit(c, self:GetLength())
	if EvilSnake.Chain.Update(c, dt) then
		self:SetPos(c.x[1])
		self.Dirty = true
	end
	local slide = math.Round(c.slide or 0)
	if slide ~= self:GetSlide() then self:SetSlide(slide) end
	self:Swallow(now)
	if self.Stomach:Digest(dt, #c.x - 1, EvilSnake.Chain.Link(c)) then self.Dirty = true end
	if self.Dirty and now >= (self.NextSend or 0) then
		self.Dirty = false
		self.NextSend = now + EvilSnake.SEND
		self:SendBody()
	end
	self:NextThink(now)
	return true
end

net.Receive("EvilSnakeBody", function(_, ply)
	local ent = net.ReadEntity()
	if not IsValid(ent) or ent:GetClass() ~= "evil_snake" or not ent.Chain then return end
	local now = RealTime()
	if now < (ply.EvilSnakeAsk or 0) then return end
	ply.EvilSnakeAsk = now + ASK_GAP
	ent:SendBody(ply)
end)
