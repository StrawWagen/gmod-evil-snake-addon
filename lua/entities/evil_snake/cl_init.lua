include("shared.lua")

language.Add("evil_snake", "Evil snake")

local REBUILD = 0.25

function ENT:Think()
	local now = RealTime()
	if now < (self.NextLayout or 0) then return end
	self.NextLayout = now + REBUILD
	local ground, normals = EvilSnake.Body.Layout(self:GetPos(), self:GetAngles().y, function(e)
		return e ~= self and not e:IsPlayer() and not e:IsNPC()
	end)
	self.Ground, self.Normals, self.Dirty = ground, normals, true
	self:SetRenderBoundsWS(EvilSnake.Body.Bounds(ground))
end

function ENT:Draw()
	if not self.Ground then return end
	if self.Dirty or not self.BodyMesh then
		self.Dirty = false
		if self.BodyMesh then self.BodyMesh:Destroy() end
		self.BodyMesh, self.Eyes, self.Head = EvilSnake.Body.Build(self.Ground, self.Normals)
	end
	EvilSnake.Body.Draw(self.BodyMesh, self.Eyes)
	if not IsValid(self.Crab) then self.Crab = EvilSnake.Mouth.Create() end
	EvilSnake.Mouth.Draw(self.Crab, self.Head)
end

function ENT:OnRemove()
	if self.BodyMesh then self.BodyMesh:Destroy() end
	self.BodyMesh = nil
	if IsValid(self.Crab) then self.Crab:Remove() end
end
