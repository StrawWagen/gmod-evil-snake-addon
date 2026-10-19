AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("EvilSnakeBody")

local Setting = EvilSnake.Setting

local ASK_GAP = 0.2
local BRAIN = 0.2
local LOSE = 1.25
local STUCK = 0.3
local STUCK_TIME = 1
local DETOUR = 1.5
local WANDER_TURN = 90
local WANDER_TIME = { 3, 7 }

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
	local r = Setting("radius")
	self:SetCollisionBounds(Vector(-r, -r, -r), Vector(r, r, r))
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:SetSegments(math.Round(Setting("segments")))
	local filter = function(e)
		return e ~= self and not e:IsPlayer() and not e:IsNPC() and not e:IsNextBot() and e:GetClass() ~= "evil_snake"
	end
	local joints = EvilSnake.Layout(self:GetPos(), self:GetAngles().y, self:GetSegments(), filter)
	self.Chain = EvilSnake.Chain.New(joints, filter)
	self:SetPos(joints[1])
	self.LastThink = CurTime()
	self.Dirty = true
	self.WanderYaw = self:GetAngles().y
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:SendBody(ply)
	local x = self.Chain.x
	net.Start("EvilSnakeBody")
	net.WriteEntity(self)
	net.WriteUInt(#x, 8)
	for _, p in ipairs(x) do net.WriteVector(p) end
	if ply then net.Send(ply) else net.Broadcast() end
end

local function Edible(ent)
	return IsValid(ent) and ent:IsNPC() and ent:GetClass() ~= "npc_bullseye" and ent:Health() > 0
end

function ENT:Mouth()
	local x = self.Chain.x
	return x[1] + (x[1] - x[2]):GetNormalized() * Setting("radius")
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

function ENT:Swallow(now)
	if Setting("hunt_npcs") == 0 or now < (self.SatedUntil or 0) then return end
	local mouth = self:Mouth()
	local reach = Setting("bite_reach")
	for _, ent in ipairs(ents.FindInSphere(mouth, reach)) do
		if Edible(ent) and ent:NearestPoint(mouth):Distance(mouth) <= reach then
			ent:Remove()
			self.Prey = nil
			self.SatedUntil = now + Setting("sated_time")
			EvilSnake.Chain.Drive(self.Chain, EvilSnake.Chain.HeadYaw(self.Chain), 0)
			return
		end
	end
end

function ENT:Brain(now)
	local c = self.Chain
	local head = c.x[1]
	local yaw = EvilSnake.Chain.HeadYaw(c)
	if self.LastHead and c.speed > 0 then
		local moved = self.LastHead:Distance(head)
		if moved < c.speed * BRAIN * STUCK then
			self.Stuck = (self.Stuck or 0) + BRAIN
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

	if now < (self.SatedUntil or 0) then
		EvilSnake.Chain.Drive(c, yaw, 0)
		return
	end

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
		EvilSnake.Chain.Drive(c, math.deg(math.atan2(to.y, to.x)), Setting("hunt_speed"))
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
	if #c.x ~= self:GetSegments() + 1 then EvilSnake.Chain.Resize(c, self:GetSegments()) end
	if now >= (self.NextBrain or 0) then
		self.NextBrain = now + BRAIN
		self:Brain(now)
	end
	if EvilSnake.Chain.Update(c, dt) then
		self:SetPos(c.x[1])
		self.Dirty = true
	end
	self:Swallow(now)
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
