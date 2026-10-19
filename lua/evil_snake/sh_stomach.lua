EvilSnake = EvilSnake or {}

local Setting = EvilSnake.Setting

EvilSnake.MAX_SEGMENTS = 254

function EvilSnake.GrownLength(base, mass)
	return math.Clamp(base + Setting("growth") * mass, 1, EvilSnake.MAX_SEGMENTS)
end

function EvilSnake.GrownGirth(mass)
	local girth = 1 + Setting("fattening") * math.log(1 + mass)
	return math.min(girth, math.max(1, Setting("girth_max")))
end
