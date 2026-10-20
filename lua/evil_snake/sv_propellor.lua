EvilSnake = EvilSnake or {}

local Setting = EvilSnake.Setting

local CLASS = "evil_crawler"
local LOOK = 0.5
local RANGE = 400
local HOP = 0.6
local HOP_HEIGHT = 90
local SEAT = 0.3
local SPINUP = EvilSnake.SPINUP
local REST = 8
local THROW = 250
local THROW_UP = 200
local ROTOR = "npc/attack_helicopter/aheli_rotor_loop1.wav"
local ROTOR_LEVEL = 85
local PITCH = { 30, 120 }
local LAND = "npc/antlion/foot4.wav"

local function Seat(snake, crawler)
	local c = snake.Chain
	local up, r = c.up, snake:Radius()
	local head, neck = EvilSnake.HeadPoints(c.x[1], c.x[2], r, up)
	local fwd = head - neck
	fwd = fwd - up * fwd:Dot(up)
	if fwd:LengthSqr() < 1e-4 then fwd = up:Angle():Up() end
	return head + up * (EvilSnake.HeadRadius(r) + crawler.BodyHeight * SEAT), up, fwd:GetNormalized()
end

local function Free(crawler, now)
	return not crawler.EvilSnakeRide and now >= (crawler.EvilSnakeRest or 0) and crawler:Awake()
		and crawler:GetAct() == EvilCrawler.ACT_NONE and not crawler:Piloted() and not crawler.Puppeting
		and not crawler.Falling and not crawler:GetSwimming()
end

local function Seen(crawler, head)
	return not util.TraceLine({ start = crawler:GetPos(), endpos = head, mask = MASK_SOLID_BRUSHONLY }).Hit
end

local function Dismount(crawler)
	local ride = crawler.EvilSnakeRide
	local now = CurTime()
	if ride then crawler.Think = ride.think end
	crawler.EvilSnakeRide = nil
	crawler.EvilSnakeRest = now + REST
	crawler:SetNW2Entity("EvilSnakeRide", NULL)
	if ride and ride.sound then ride.sound:FadeOut(0.5) end
	local away = VectorRand()
	away.z = 0
	away:Normalize()
	crawler.Vel = (ride and ride.vel or Vector()) + away * THROW + Vector(0, 0, THROW_UP)
	crawler.LetGoUntil = math.max(crawler.LetGoUntil or 0, now + HOP)
	crawler.Falling = true
end

local function Ride(self)
	local now = CurTime()
	local ride = self.EvilSnakeRide
	local snake = ride and ride.snake
	if not ride or not IsValid(snake) or snake.Rotor ~= self or snake.Dead or not self:Awake() or self:Piloted() then
		if IsValid(snake) and snake.Rotor == self then EvilSnake.Unrotor(snake) else Dismount(self) end
		return self:Think()
	end
	self:Resize()
	local seat, up, fwd = Seat(snake, self)
	local f = (now - ride.at) / HOP
	if f < 1 then
		seat = LerpVector(f, ride.from, seat) + vector_up * (math.sin(f * math.pi) * HOP_HEIGHT)
	elseif not ride.sound then
		self:EmitSound(LAND, 75, math.random(80, 95))
		ride.sound = CreateSound(self, ROTOR)
		ride.sound:SetSoundLevel(ROTOR_LEVEL)
		ride.sound:PlayEx(Setting("slither_volume"), PITCH[1])
		ride.sound:ChangePitch(PITCH[2], SPINUP)
	end
	local dt = now - (ride.last or now)
	if dt > 0 then ride.vel = (seat - self:GetPos()) / dt end
	ride.last = now
	self.BodyUp, self.Facing = up, fwd
	self:SetPos(seat)
	self:SetAngles(fwd:AngleEx(up))
	self:NextThink(now)
	return true
end

local function Mount(snake, crawler, now)
	snake.Rotor = crawler
	crawler.EvilSnakeRide = { snake = snake, from = crawler:GetPos(), at = now, think = crawler.Think }
	crawler:SetNW2Entity("EvilSnakeRide", snake)
	crawler:SetNW2Float("EvilSnakeRideAt", now + HOP)
	crawler:SetPrey(NULL)
	crawler:SetMood(0)
	crawler.Goal, crawler.Way, crawler.DetourUntil = nil, nil, nil
	crawler.Think = Ride
	crawler:NextThink(now)
	hook.Run("EvilSnakeMounted", snake, crawler)
end

function EvilSnake.Unrotor(snake)
	local crawler = snake.Rotor
	snake.Rotor = nil
	if snake.Chain.fly then
		snake.Chain.fly = false
		snake.Chain.awake, snake.Chain.still = true, 0
	end
	if IsValid(crawler) and crawler.EvilSnakeRide and crawler.EvilSnakeRide.snake == snake then
		Dismount(crawler)
		hook.Run("EvilSnakeDismounted", snake, crawler)
	end
end

function EvilSnake.Propellor(snake, now)
	local crawler = snake.Rotor
	if crawler and (Setting("propellor") == 0 or not IsValid(crawler) or not crawler.EvilSnakeRide) then
		EvilSnake.Unrotor(snake)
		crawler = nil
	end
	local c = snake.Chain
	local fly = crawler ~= nil and now >= crawler.EvilSnakeRide.at + HOP + SPINUP
	if fly ~= (c.fly or false) then
		c.fly = fly
		c.awake, c.still = true, 0
	end
	if crawler or not EvilCrawler or Setting("propellor") == 0 or now < (snake.NextRotorLook or 0) then return end
	snake.NextRotorLook = now + LOOK
	local head = c.x[1]
	for _, ent in ipairs(ents.FindInSphere(head, RANGE)) do
		if ent:GetClass() == CLASS and Free(ent, now) and Seen(ent, head) then return Mount(snake, ent, now) end
	end
end
