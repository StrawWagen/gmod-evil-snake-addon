ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Evil snake"
ENT.Category = "Syhgma's Evil Entities"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Seed")
end
