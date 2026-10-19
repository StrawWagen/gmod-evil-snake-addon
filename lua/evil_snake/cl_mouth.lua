EvilSnake = EvilSnake or {}
local Mouth = {}
EvilSnake.Mouth = Mouth

local MODEL = "models/headcrabclassic.mdl"
local PREFIX = "HeadcrabClassic."
local SCALE = 0.6
local OUT = 0.6
local ROLL = 0
local SINK_FWD = 5.6
local SINK_DOWN = 6.5
local IDLE_RATE = 0.35
local PERIOD = 3.4
local CURL = 38
local UPPER = 0.45
local WRIGGLE = 7
local WRIGGLE_SPEED = 6.5
local GAPE = 1.8
local FANG = 28
local CHATTER = 4
local CHATTER_SPEED = 22

local FEELERS = {
	{ "UpperArmL_Bone", -0.80, -0.60, "ForeArmL_Bone", -0.37, -0.93, 0 },
	{ "UpperArmR_Bone", -0.79, 0.62, "ForeArmR_Bone", -0.37, 0.93, 0.18 },
	{ "ThighL_Bone", 0.72, -0.69, "CalfL_Bone", 0.94, -0.34, 0.41 },
	{ "ThighR_Bone", -0.72, -0.69, "CalfR_Bone", -0.94, -0.34, 0.57 },
}

local function Smooth(x)
	x = math.Clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function Curl(t)
	if t < 0.6 then return Lerp(Smooth(t / 0.6), 1, -1) end
	if t < 0.72 then return Lerp(Smooth((t - 0.6) / 0.12), -1, 1.2) end
	return Lerp(Smooth((t - 0.72) / 0.28), 1.2, 1)
end

local function Bone(crab, name)
	crab.Bones = crab.Bones or {}
	local id = crab.Bones[name]
	if id == nil then
		id = crab:LookupBone(PREFIX .. name) or false
		crab.Bones[name] = id
	end
	return id or nil
end

local function Basis(crab)
	crab:InvalidateBoneCache()
	crab:SetupBones()
	local function At(name)
		local id = Bone(crab, name)
		local m = id and crab:GetBoneMatrix(id)
		return m and crab:WorldToLocal(m:GetTranslation())
	end
	local head, hip, l, r = At("HeadControl"), At("HipControl"), At("UpperArmL_Bone"), At("UpperArmR_Bone")
	if not (head and hip and l and r) then return end
	local fwd = (head - hip):GetNormalized()
	local side = (l - r):GetNormalized()
	local up = fwd:Cross(side):GetNormalized()
	fwd = side:Cross(up):GetNormalized()
	return { fwd = fwd, side = side, up = up, mouth = hip + fwd * SINK_FWD - up * SINK_DOWN }
end

function Mouth.Create()
	local crab = ClientsideModel(MODEL, RENDERGROUP_OPAQUE)
	if not IsValid(crab) then return end
	crab:SetNoDraw(true)
	local seq = crab:LookupSequence("Idle01")
	if seq and seq >= 0 then crab:ResetSequence(seq) end
	return crab
end

local function Bend(crab, name, pitch, yaw, amount, wriggle)
	local id = Bone(crab, name)
	if not id then return end
	crab:ManipulateBoneAngles(id, Angle(pitch * amount - yaw * wriggle, yaw * amount + pitch * wriggle, 0))
end

local function Animate(crab, now)
	crab:SetCycle((now * IDLE_RATE) % 1)
	for i, f in ipairs(FEELERS) do
		local curl = Curl((now / PERIOD + f[7]) % 1) * CURL
		local wriggle = math.sin(now * WRIGGLE_SPEED + i * 1.7) * WRIGGLE
		Bend(crab, f[1], f[2], f[3], curl * UPPER, wriggle * 0.5)
		Bend(crab, f[4], f[5], f[6], curl, wriggle)
	end
	local open = math.Clamp((1 - Curl((now / PERIOD + 0.1) % 1)) * 0.5, 0, 1)
	local l, r = Bone(crab, "HoleControlL"), Bone(crab, "HoleControlR")
	if l then crab:ManipulateBonePosition(l, Vector(0, 0, -GAPE * open)) end
	if r then crab:ManipulateBonePosition(r, Vector(0, 0, GAPE * open)) end
	local chatter = math.sin(now * CHATTER_SPEED) * CHATTER * open
	Bend(crab, "FangL_Bone1", 0.33, -0.94, -(FANG * open + chatter), 0)
	Bend(crab, "FangR_Bone1", 0.58, 0.81, -(FANG * open + chatter), 0)
end

function Mouth.Draw(crab, head)
	if not IsValid(crab) or not head then return end
	if not crab.Basis then
		crab.Basis = Basis(crab)
		if not crab.Basis then return end
		crab:SetModelScale(SCALE)
	end
	local b = crab.Basis
	local f = head.fwd
	local u = Vector(head.up)
	local s = Vector(head.side)
	if ROLL ~= 0 then
		local a = math.rad(ROLL)
		u, s = u * math.cos(a) + s * math.sin(a), s * math.cos(a) - u * math.sin(a)
	end
	local t = u:Cross(f)
	local function Map(v)
		return u * v:Dot(b.fwd) - f * v:Dot(b.up) + t * v:Dot(b.side)
	end
	local x, z = Map(Vector(1, 0, 0)), Map(Vector(0, 0, 1))
	crab:SetPos(head.pos + f * OUT - Map(b.mouth) * SCALE)
	crab:SetAngles(x:AngleEx(z))
	Animate(crab, RealTime())
	crab:DrawModel()
end
