EvilSnake = EvilSnake or {}

local CHECK = 0.25
local STRIDE = 2
local TOUCH = 8
local CLEAR = 24
local REACH = 24
local MASS = 2

local function Live(node)
	return not node.EvilSnakeSmear and not node.dead and not node.burn and not node.heat and node.m > EvilFungus.Mat.EMPTY
end

local function Touching(pos)
	local pad = Vector(TOUCH, TOUCH, TOUCH)
	for colony in pairs(EvilFungus.Colonies) do
		local mat = IsValid(colony) and not colony.Absorbed and colony.Mat
		if mat and mat.mins and pos:WithinAABox(mat.mins - pad, mat.maxs + pad) and mat:Nearest(pos, TOUCH, Live) then return colony end
	end
end

local function Ground(c, i)
	local n = c.cn[i]
	if not n then return end
	local from = c.x[i]
	local tr = util.TraceLine({ start = from, endpos = from - n * ((c.hull[i] or 0) + REACH), mask = MASK_SOLID_BRUSHONLY })
	if not tr.Hit or tr.HitSky or tr.HitNoDraw or tr.StartSolid then return end
	return tr.HitPos, tr.HitNormal
end

local function Mark(pos)
	for colony in pairs(EvilFungus.Colonies) do
		local mat = IsValid(colony) and not colony.Absorbed and colony.Mat
		if mat then mat:Near(pos, CLEAR, function(node) node.EvilSnakeSmear = true end) end
	end
end

function EvilSnake.Smear(snake, now)
	if not EvilFungus or not EvilFungus.Plant or not EvilFungus.Colonies then return end
	local time = EvilSnake.Setting("fungus_smear")
	if time <= 0 or now < (snake.NextSmear or 0) then return end
	snake.NextSmear = now + CHECK
	local c = snake.Chain
	local coat = snake.Coat or {}
	snake.Coat = coat
	local room = EvilFungus.Room()
	for i = 1, #c.x, STRIDE do
		local pos, normal = Ground(c, i)
		if pos then
			local colony = Touching(pos)
			local s = coat[i]
			if colony then
				coat[i] = { till = now + time, mind = colony.Mind, by = colony:GetCreator() }
			elseif s and now >= s.till then
				coat[i] = nil
			elseif s and room and not EvilFungus.Taken(pos, CLEAR) then
				EvilFungus.Plant(pos, normal, MASS * c.girth, s.mind, s.by)
				Mark(pos)
			end
		end
	end
end
