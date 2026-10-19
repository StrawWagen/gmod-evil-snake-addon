include("shared.lua")

language.Add("evil_snake", "Evil snake")

function ENT:Draw()
	self:DrawModel()
end
