ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Evil snake"
ENT.Category = "Syhgma's Evil Entities"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "Girth")
	self:NetworkVar("Float", 1, "Length")
	self:NetworkVar("Float", 2, "Slide")
	self:NetworkVar("Entity", 0, "Prey")
end

local WEIGHT = 14 * 14 * 28 * 17

function ENT:Radius()
	return EvilSnake.Setting("radius") * math.max(self:GetGirth(), 1)
end

function ENT:Weight()
	local r = self:Radius()
	return r * r * math.max(self:GetLength(), 1) * EvilSnake.Setting("segment_length") / WEIGHT
end
