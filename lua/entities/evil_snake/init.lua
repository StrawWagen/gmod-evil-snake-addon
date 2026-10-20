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
local GULP_AT = 1
local EAT_LEVEL = 80
local MIN_REACH = 4
local PRESENCE_REACH = 450
local DREAD = 4
local GRAB_FEAR = 30
local GRAB_FEAR_RANGE = 900
local FAST = 4
local ESCAPE_PUSH = 350
local ESCAPE_UP = 220
local ESCAPE_GRACE = 4
local SPLASH = { "ambient/water/water_splash1.wav", "ambient/water/water_splash2.wav", "ambient/water/water_splash3.wav" }
local SPLASH_GAP = 0.5
local SPLASH_LEVEL = 75

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
			and not e.EvilDowned
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
	self.Tongue = EvilSnake.Tongue.New()
	Evil.Presence(self, { reach = PRESENCE_REACH, dread = DREAD, near = self.Nearest })
end

function ENT:Nearest(pos)
	local best, bestDist
	for _, p in ipairs(self.Chain.x) do
		local d = p:DistToSqr(pos)
		if not bestDist or d < bestDist then best, bestDist = p, d end
	end
	return best
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
		net.WriteEntity(m.ply or NULL)
	end
	local held = self.Held
	net.WriteBool(held ~= nil)
	if held then
		net.WriteEntity(held.ent)
		net.WriteDouble(held.at)
		net.WriteFloat(held.hold)
		net.WriteFloat(held.pace)
		net.WriteFloat(held.size)
	end
	self.Tongue:Write()
	if ply then net.Send(ply) else net.Broadcast() end
end

local function Unseen(ply)
	local f = ply.EvilFrozen
	if f then return f.notarget end
	return ply:IsFlagSet(FL_NOTARGET) or GetConVar("ai_ignoreplayers"):GetBool()
end

function EvilSnake.Edible(ent, snake)
	if not IsValid(ent) or CurTime() < (ent.EvilSnakeFree or 0) or not Evil.Claimable(ent, snake) then return false end
	if ent:IsPlayer() then return Setting("hunt_players") ~= 0 and ent:Alive() and not Unseen(ent) end
	return Setting("hunt_npcs") ~= 0 and ent:IsNPC() and ent:GetClass() ~= "npc_bullseye" and ent:Health() > 0
end

local Edible = EvilSnake.Edible

function ENT:Mouth()
	local x = self.Chain.x
	local r = self:Radius()
	local head, neck = EvilSnake.HeadPoints(x[1], x[2], r)
	return head + (head - neck):GetNormalized() * EvilSnake.HeadRadius(r)
end

function ENT:FindPrey(from)
	local best, bestDist = nil, Setting("sight_range") ^ 2
	for _, ent in ipairs(ents.FindInSphere(from, Setting("sight_range"))) do
		if Edible(ent, self) then
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

function ENT:Voice(size)
	local volume = Setting("eat_volume")
	if volume <= 0 then return end
	local mass = math.max(self:Weight(), 1e-3)
	local pitch = math.Clamp(105 / mass ^ 0.1 / size ^ 0.25, 50, 160)
	local level = EAT_LEVEL + math.Clamp(math.log(mass, 2) * 2, 0, 10)
	return pitch, level, math.min(volume * (0.7 + 0.3 * size), 1)
end

function ENT:Bite(size)
	local pitch, level, loud = self:Voice(size)
	if not pitch then return end
	self:EmitSound(BITE, level, pitch * math.Rand(0.95, 1.05), loud)
	self:EmitSound(table.Random(SQUISH), level, pitch * math.Rand(0.9, 1.1), loud * 0.8)
end

function ENT:Splash(now)
	local wet = (self.Chain.wet[1] or 0) > 0
	if wet == (self.Wet or false) or now < (self.NextSplash or 0) then return end
	self.Wet, self.NextSplash = wet, now + SPLASH_GAP
	local volume = Setting("slither_volume")
	if volume <= 0 then return end
	local pitch = math.Clamp(110 / math.max(self:Weight(), 1e-3) ^ 0.12, 60, 140)
	self:EmitSound(table.Random(SPLASH), SPLASH_LEVEL, pitch * math.Rand(0.9, 1.1), volume)
end

function ENT:Chomp(size)
	local pitch, level, loud = self:Voice(size)
	if not pitch then return end
	self:EmitSound(table.Random(CRUNCH), level, pitch * math.Rand(0.9, 1.1), loud)
	self:EmitSound(table.Random(SQUISH), level, pitch * math.Rand(0.9, 1.1), loud * 0.8)
	timer.Simple(GULP_DELAY * size, function()
		if IsValid(self) then self:EmitSound(table.Random(GULP), level, pitch * 0.9, loud) end
	end)
end

function ENT:EvilPose(victim)
	local tongued = self.Tongue:Pose(victim)
	if tongued then return tongued end
	local held = self.Held
	if not held or held.ent ~= victim then return end
	local x = self.Chain.x
	local depth = EvilSnake.Hold((CurTime() - held.at) * held.pace, held.hold)
	local head, neck = EvilSnake.HeadPoints(x[1], x[2], self:Radius())
	local pos, ang = EvilSnake.HeldPlace(head, neck, victim:OBBMaxs().z * depth)
	return pos, ang
end

function ENT:Grab(ent, now)
	local size = EvilSnake.PreySize(ent)
	local fast = not ent:IsPlayer() and Setting("instant_npcs") ~= 0
	self.Held = {
		ent = ent, at = now, hold = fast and 0 or Setting("hold_time"), pace = fast and FAST or 1,
		size = EvilSnake.BulgeSize(size), prey = size, from = ent:GetPos(),
	}
	if not Evil.Pose(ent, self, { act = ACT_BARNACLE_PULL }) then
		self.Held = nil
		self:Unstruggle(ent)
		return
	end
	self:Struggle(ent, EvilSnake.HoldLength(self.Held.hold) / self.Held.pace)
	self.Prey = nil
	self:Bite(size)
	Evil.Frighten(self:Mouth(), GRAB_FEAR_RANGE, GRAB_FEAR, true)
	self.Dirty = true
	hook.Run("EvilSnakeGrabbed", self, ent)
end

function ENT:Struggle(ent, time)
	local presses = Setting("escape_presses")
	if not ent:IsPlayer() or presses <= 0 then return end
	local m = Evil.Mashing(ent)
	Evil.Mash(ent, self, {
		gain = 1 / presses, time = time, start = m and m.source == self and m.progress or 0,
		done = function() self:Escape(ent) end,
	})
end

function ENT:Unstruggle(ent)
	local m = IsValid(ent) and ent:IsPlayer() and Evil.Mashing(ent)
	if m and m.source == self then Evil.StopMash(ent) end
end

function ENT:Escape(ent)
	ent.EvilSnakeFree = CurTime() + ESCAPE_GRACE
	if self.Tongue.ent == ent then return self.Tongue:Drop(self) end
	local held = self.Held
	if not held or held.ent ~= ent then return end
	self:Release()
	ent:SetVelocity(self.Tongue.fwd * ESCAPE_PUSH + Vector(0, 0, ESCAPE_UP))
	hook.Run("EvilSnakeEscaped", self, ent)
end

local function Free(ent, pos, snake)
	return not util.TraceHull({
		start = pos, endpos = pos, mins = ent:OBBMins(), maxs = ent:OBBMaxs(),
		mask = ent:IsPlayer() and MASK_PLAYERSOLID or MASK_NPCSOLID, filter = { ent, snake },
	}).StartSolid
end

function ENT:Release()
	local held = self.Held
	self.Held = nil
	self.Dirty = true
	if not held then return end
	local ent = held.ent
	self:Unstruggle(ent)
	if Evil.Owner(ent) ~= self then return end
	Evil.Unpose(ent, self)
	local mouth = self:Mouth()
	ent:SetPos(Free(ent, mouth, self) and mouth or held.from)
	ent:SetAngles(Angle(0, ent:GetAngles().y, 0))
	hook.Run("EvilSnakeReleased", self, ent)
end

function ENT:Hold(now)
	local held = self.Held
	if not held then return end
	local ent = held.ent
	if Evil.Owner(ent) ~= self or (ent:IsPlayer() and not ent:Alive()) then return self:Release() end
	self.Dirty = true
	if (now - held.at) * held.pace < EvilSnake.HoldLength(held.hold) then return end
	self.Held = nil
	local v = self.Stomach:Swallow(ent, GULP_AT)
	self:Chomp(held.prey)
	hook.Run("EvilSnakeSwallowed", self, v, ent)
	if ent:IsPlayer() then
		self:Unstruggle(ent)
		Evil.Unpose(ent, self)
		ent:KillSilent()
	else
		ent:Remove()
	end
	self.NextDecide = now
end

function ENT:OnRemove()
	self.Tongue:Drop(self)
	self:Release()
	self.Stomach:Vacate()
end

function EvilSnake.Reaches(ent, from, to, steps, reach)
	for k = 0, steps do
		local at = LerpVector(k / steps, from, to)
		if ent:NearestPoint(at):Distance(at) <= reach then return true end
	end
	return false
end

local Reaches = EvilSnake.Reaches

function ENT:Catch(now)
	local mouth = self:Mouth()
	local from = self.LastMouth or mouth
	self.LastMouth = mouth
	if self.Held or self.Tongue:Busy() then return end
	local reach = Setting("bite_reach")
	local travel = from:Distance(mouth)
	local steps = math.ceil(travel / math.max(reach, MIN_REACH))
	for _, ent in ipairs(ents.FindInSphere((from + mouth) * 0.5, reach + travel * 0.5)) do
		if Edible(ent, self) and Reaches(ent, from, mouth, steps, reach) then
			self:Grab(ent, now)
			return
		end
	end
end

function ENT:Decide(now)
	local c = self.Chain
	local head = c.x[1]
	local yaw = EvilSnake.Chain.HeadYaw(c)
	if self.Held or self.Tongue:Busy() then
		self.Prey, self.LastHead = nil, nil
		if IsValid(self:GetPrey()) then self:SetPrey(NULL) end
		EvilSnake.Chain.Drive(c, yaw, 0)
		return
	end
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
	if not Edible(prey, self) or head:Distance(prey:WorldSpaceCenter()) > range * LOSE then
		prey = self:FindPrey(head)
	end
	self.Prey = prey
	if self:GetPrey() ~= (prey or NULL) then self:SetPrey(prey or NULL) end

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
	self:Splash(now)
	local slide = math.Round(c.slide or 0)
	if slide ~= self:GetSlide() then self:SetSlide(slide) end
	self:Catch(now)
	if self.Tongue:Think(self, now, dt) then self.Dirty = true end
	self:Hold(now)
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
