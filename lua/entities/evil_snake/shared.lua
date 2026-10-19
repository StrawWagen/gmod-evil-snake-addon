ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Evil snake"
ENT.Category = "Syhgma's Evil Entities"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Segments")
	self:NetworkVar("Float", 0, "Girth")
end

function ENT:Radius()
	return EvilSnake.Setting("radius") * math.max(self:GetGirth(), 1)
end
