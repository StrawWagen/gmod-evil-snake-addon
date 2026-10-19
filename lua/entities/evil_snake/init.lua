AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("EvilSnakeBody")

local ASK_GAP = 0.2

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
	local r = EvilSnake.RADIUS
	self:SetCollisionBounds(Vector(-r, -r, -r), Vector(r, r, r))
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:SetSegments(math.Round(EvilSnake.Setting("segments")))
	local filter = function(e)
		return e ~= self and not e:IsPlayer() and not e:IsNPC() and e:GetClass() ~= "evil_snake"
	end
	local joints = EvilSnake.Layout(self:GetPos(), self:GetAngles().y, self:GetSegments(), filter)
	self.Chain = EvilSnake.Chain.New(joints, filter)
	self:SetPos(joints[1])
	self.LastThink = CurTime()
	self.Dirty = true
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

function ENT:Think()
	local now = CurTime()
	local dt = now - self.LastThink
	self.LastThink = now
	local c = self.Chain
	if #c.x ~= self:GetSegments() + 1 then EvilSnake.Chain.Resize(c, self:GetSegments()) end
	if EvilSnake.Chain.Update(c, dt) then
		self:SetPos(c.x[1])
		self.Dirty = true
	end
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
