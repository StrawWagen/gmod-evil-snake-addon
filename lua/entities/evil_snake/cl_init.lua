include("shared.lua")

language.Add("evil_snake", "Evil snake")

local ASK = 1
local SLITHER = {
	{ key = "SmoothSlither", path = "physics/body/body_medium_scrape_smooth_loop1.wav", light = 1, heavy = 0.3, pitch = 1 },
	{ key = "RoughSlither", path = "physics/flesh/flesh_scrape_rough_loop.wav", light = 0.25, heavy = 1, pitch = 0.9 },
}
local SLITHER_FULL = 220
local SLITHER_FADE = 0.15
local SLITHER_GAP = 0.1
local SLITHER_REST = 1
local SLITHER_LEVEL = 75
local HEAVIEST = 8

net.Receive("EvilSnakeBody", function()
	local ent = net.ReadEntity()
	local pts, meals = {}, {}
	for i = 1, net.ReadUInt(8) do pts[i] = net.ReadVector() end
	for i = 1, net.ReadUInt(6) do meals[i] = { at = net.ReadFloat(), size = net.ReadFloat() } end
	if IsValid(ent) and ent.Snapshot then ent:Snapshot(pts, meals) end
end)

function ENT:Initialize()
	self.Body = EvilSnake.Body.New()
	self.Bulges = {}
end

function ENT:Snapshot(pts, meals)
	self.From = self.Pose and #self.Pose == #pts and self.Pose or pts
	self.To = pts
	self.Meals = meals
	self.Since = RealTime()
end

function ENT:Slither(now)
	if now < (self.NextSlither or 0) then return end
	self.NextSlither = now + SLITHER_GAP
	local pace = math.Clamp(self:GetSlide() / SLITHER_FULL, 0, 1)
	local mass = math.max(self:Weight(), 1e-3)
	local heavy = math.Clamp(math.log(mass) / math.log(HEAVIEST), 0, 1)
	local volume = pace * (0.6 + 0.4 * heavy) * EvilSnake.Setting("slither_volume")
	local pitch = (80 + 40 * pace) / mass ^ 0.12
	for _, layer in ipairs(SLITHER) do
		local patch = self[layer.key]
		local vol = math.min(volume * Lerp(heavy, layer.light, layer.heavy), 1)
		local p = math.Clamp(pitch * layer.pitch, 40, 180)
		if vol > 0.01 then
			if not patch then
				patch = CreateSound(self, layer.path)
				patch:SetSoundLevel(SLITHER_LEVEL)
				self[layer.key] = patch
			end
			if not patch:IsPlaying() then patch:PlayEx(0, p) end
			patch:ChangeVolume(vol, SLITHER_FADE)
			patch:ChangePitch(p, SLITHER_FADE)
			self[layer.key .. "Quiet"] = nil
		elseif patch and patch:IsPlaying() then
			patch:ChangeVolume(0, SLITHER_FADE)
			local quiet = self[layer.key .. "Quiet"] or now
			self[layer.key .. "Quiet"] = quiet
			if now - quiet > SLITHER_REST then patch:Stop() end
		end
	end
end

function ENT:OnRemove()
	for _, layer in ipairs(SLITHER) do
		if self[layer.key] then self[layer.key]:Stop() end
	end
end

function ENT:Think()
	local now = RealTime()
	self:Slither(now)
	if not self.To then
		if now >= (self.NextAsk or 0) then
			self.NextAsk = now + ASK
			net.Start("EvilSnakeBody")
			net.WriteEntity(self)
			net.SendToServer()
		end
		return
	end
	local t = math.Clamp((now - self.Since) / EvilSnake.SEND, 0, 1)
	local from, to = self.From, self.To
	local pose = {}
	for i, p in ipairs(to) do pose[i] = t >= 1 and p or LerpVector(t, from[i], p) end
	self.Pose = pose
	self.Link = EvilSnake.Setting("segment_length") * math.max(self:GetLength(), 1) / math.max(#pose - 1, 1)
	local ahead = (now - self.Since) * EvilSnake.Setting("bulge_speed") / self.Link
	local bulges, fattest = {}, 1
	for i, m in ipairs(self.Meals) do
		bulges[i] = { at = math.min(m.at + ahead, #pose - 1), size = m.size }
		fattest = math.max(fattest, m.size)
	end
	self.Bulges = bulges
	self:SetRenderBoundsWS(EvilSnake.Body.Bounds(pose, fattest, self:Radius()))
end

function ENT:Draw()
	if self.Pose then EvilSnake.Body.Draw(self.Body, self.Pose, self.Bulges, self:Radius(), self.Link) end
end
