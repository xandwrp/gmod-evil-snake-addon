EvilSnake = EvilSnake or {}
local Tongue = {}
Tongue.__index = Tongue
EvilSnake.Tongue = Tongue

local Setting = EvilSnake.Setting

local IN, OUT, WRAP, BACK = EvilSnake.TONGUE_IN, EvilSnake.TONGUE_OUT, EvilSnake.TONGUE_WRAP, EvilSnake.TONGUE_BACK
local BONE = EvilSnake.TONGUE_BONE
local OPEN = EvilSnake.TONGUE_OPEN
local LASH = 900
local RETRACT = 700
local TRACK = 6
local WAVE = 0.08
local WAVES = 1.5
local CONE = 0.4
local TRY = 0.1
local REST = 0.6
local LICK = 10
local PUSH = 150
local PUSH_UP = 100
local GRIP_SPEED = 500
local HANG = 0.65
local ARC = 40
local SWAY = 14
local SWALLOW = 40
local LATE = 1
local STUCK = 90
local STUCK_TIME = 3
local LET_GO = 2
local FEAR = 30
local FEAR_RANGE = 900
local WRITHE = { 0.12, 0.4 }
local WRITHE_PUSH = 220
local THRASH_LIMBS = 3
local THRASH_PUSH = 420
local PULL_GAP = { 0.6, 1.2 }
local WHIP = "weapons/iceaxe/iceaxe_swing1.wav"
local SLAP = { "physics/flesh/flesh_impact_hard1.wav", "physics/flesh/flesh_impact_hard2.wav", "physics/flesh/flesh_impact_hard3.wav" }
local PULL = { "npc/barnacle/barnacle_tongue_pull1.wav", "npc/barnacle/barnacle_tongue_pull2.wav", "npc/barnacle/barnacle_tongue_pull3.wav" }
local UP = Vector(0, 0, 1)

local function Smooth(u)
	return u * u * (3 - 2 * u)
end

local function Say(snake, path, pitch, at)
	local p, level, loud = snake:Voice(1)
	if not p then return end
	if at then
		sound.Play(path, at, level, p * pitch * math.Rand(0.9, 1.1), loud)
	else
		snake:EmitSound(path, level, p * pitch * math.Rand(0.9, 1.1), loud)
	end
end

local function Lickable(ent, snake)
	return EvilSnake.Edible(ent, snake) and not ent:IsNextBot() and util.IsValidRagdoll(ent:GetModel() or "")
end

local function Gripped(rag)
	local bone = rag:LookupBone(BONE)
	local n = bone and rag:TranslateBoneToPhysBone(bone) or 0
	local phys = rag:GetPhysicsObjectNum(n >= 0 and n or 0)
	return IsValid(phys) and phys:GetPos() or rag:GetPos()
end

function Tongue.New()
	return setmetatable({
		state = IN, open = 0, len = 0, max = 0, tip = Vector(), dir = Vector(1, 0, 0),
		mouth = Vector(), fwd = Vector(1, 0, 0), up = UP, next = 0,
	}, Tongue)
end

function Tongue:Pose(victim)
	if victim == self.ent then return self.pos end
end

function Tongue:Write()
	net.WriteUInt(self.state, 2)
	if self.state == IN then return end
	net.WriteVector(self.tip)
	net.WriteEntity(self.ent or self.target or NULL)
end

function Tongue:Start(snake, target, max, dir)
	self.state, self.target, self.max, self.dir, self.len = OUT, target, max, dir, 0
	self.tip = Vector(self.mouth)
	self.wave = math.Rand(0, math.pi * 2)
	if target then Say(snake, WHIP, 0.7) end
end

function Tongue:Back()
	self.state, self.target = BACK, nil
	local to = self.tip - self.mouth
	self.len = to:Length()
	if self.len > 1e-3 then self.dir = to / self.len end
end

function Tongue:Reset(now)
	self.state, self.target, self.ent, self.rag, self.pos, self.len = IN, nil, nil, nil, nil, 0
	self.next = now + REST
end

function Tongue:Drop(snake)
	local ent = self.ent
	self.ent, self.rag, self.pos = nil, nil, nil
	snake:Unstruggle(ent)
	if IsValid(ent) and Evil.Owner(ent) == snake then Evil.LetGo(ent, LET_GO) end
	if self.state ~= IN then self:Back() end
end

function Tongue:Try(snake, now)
	self.next = now + TRY
	local mouth, fwd = self.mouth, self.fwd
	local reach = Setting("tongue_reach") * snake.Sharp.lick
	local prey = snake.Prey
	if IsValid(prey) and Lickable(prey, snake) then
		local aim = prey:WorldSpaceCenter()
		local to = aim - mouth
		local dist = to:Length()
		if dist <= reach and to:Dot(fwd) >= dist * CONE
			and not util.TraceLine({
				start = mouth, endpos = aim, mask = MASK_SOLID,
				filter = function(e) return e ~= snake and e ~= prey and not e.EvilHitboxOwner and not e.EvilSnakeRide end,
			}).Hit then
			return self:Start(snake, prey, reach, to / math.max(dist, 1))
		end
	end
end

function Tongue:Lick(snake, from, to)
	local travel = from:Distance(to)
	local steps = math.max(math.ceil(travel / LICK), 1)
	for _, ent in ipairs(ents.FindInSphere((from + to) * 0.5, LICK + travel * 0.5)) do
		if Lickable(ent, snake) and EvilSnake.Reaches(ent, from, to, steps, LICK) and EvilSnake.Clear(snake, from, ent, to) then return ent end
	end
end

function Tongue:Wrap(snake, ent, now)
	local rag = Evil.Grip(ent, snake, { bone = BONE, speed = GRIP_SPEED, push = -self.dir * PUSH + UP * PUSH_UP })
	if not IsValid(rag) then return self:Back() end
	self.state, self.target, self.ent, self.rag = WRAP, nil, ent, rag
	self.from = Gripped(rag)
	self.tip, self.pos = Vector(self.from), Vector(self.from)
	self.k, self.at, self.stuck, self.late = 0, now, 0, 0
	self.writhe, self.pull = now, now + math.Rand(PULL_GAP[1], PULL_GAP[2])
	snake.Prey = nil
	snake:Struggle(ent)
	Say(snake, table.Random(SLAP), 1, self.tip)
	Evil.Frighten(self.tip, FEAR_RANGE, FEAR, true)
	hook.Run("EvilSnakeTongued", snake, ent)
end

function Tongue:Lash(snake, now, dt, on)
	local target = self.target
	if not on or snake.Held or (target ~= nil and not EvilSnake.Edible(target, snake)) then return self:Back() end
	local mouth = self.mouth
	if target then
		local to = (target:WorldSpaceCenter() - mouth):GetNormalized()
		self.dir = LerpVector(math.min(dt * TRACK, 1), self.dir, to):GetNormalized()
	end
	if self.open >= 1 then self.len = math.min(self.len + LASH * dt, self.max) end
	local side = self.dir:Cross(UP)
	side:Normalize()
	local u = self.len / math.max(self.max, 1)
	local wave = math.sin(u * math.pi) * math.sin(u * WAVES * math.pi * 2 + self.wave) * self.max * WAVE
	local from, tip = self.tip, mouth + self.dir * self.len + side * wave
	local tr = util.TraceLine({ start = from, endpos = tip, mask = MASK_SOLID_BRUSHONLY })
	if tr.Hit and not tr.StartSolid then
		self.tip = tr.HitPos
		return self:Back()
	end
	self.tip = tip
	local hit = self:Lick(snake, from, tip)
	if hit then return self:Wrap(snake, hit, now) end
	if self.len >= self.max then
		if target then EvilSnake.Watch(target, "dodged") end
		self:Back()
	end
end

function Tongue:Thrash()
	local rag = self.rag
	if not IsValid(rag) then return end
	local n = rag:GetPhysicsObjectCount()
	for _ = 1, THRASH_LIMBS do
		local phys = rag:GetPhysicsObjectNum(math.random(0, n - 1))
		if IsValid(phys) then phys:AddVelocity(VectorRand() * THRASH_PUSH) end
	end
end

function Tongue:Writhe(rag, now)
	if now < self.writhe then return end
	self.writhe = now + math.Rand(WRITHE[1], WRITHE[2])
	local phys = rag:GetPhysicsObjectNum(math.random(0, rag:GetPhysicsObjectCount() - 1))
	if not IsValid(phys) then return end
	phys:AddVelocity(VectorRand() * WRITHE_PUSH)
	phys:Wake()
end

function Tongue:Feed(snake, now)
	local ent = self.ent
	self:Reset(now)
	Evil.Up(ent)
	if IsValid(ent) then snake:Grab(ent, now) end
end

function Tongue:Reel(snake, now, dt, on)
	local ent, rag = self.ent, self.rag
	if not on or not IsValid(ent) or not IsValid(rag) or Evil.Owner(ent) ~= snake then return self:Drop(snake) end
	local at = Gripped(rag)
	self.tip = at
	local goal = self.mouth + self.up * (ent:OBBMaxs().z * HANG)
	local span = math.max(self.from:Distance(goal), 1)
	self.k = math.min(self.k + Setting("tongue_reel") * snake.Sharp.reel * dt / span, 1)
	local s = Smooth(self.k)
	local t = now - self.at
	local side = self.fwd:Cross(UP)
	side:Normalize()
	local sway = (side * math.sin(t * 2.1) + UP * (0.5 * math.sin(t * 3.3))) * (SWAY * (1 - s))
	self.pos = LerpVector(s, self.from, goal) + UP * (ARC * math.sin(math.pi * s)) + sway
	self.stuck = at:Distance(self.pos) > STUCK and self.stuck + dt or 0
	if self.stuck > STUCK_TIME then return self:Drop(snake) end
	self:Writhe(rag, now)
	if now >= self.pull then
		self.pull = now + math.Rand(PULL_GAP[1], PULL_GAP[2])
		Say(snake, table.Random(PULL), 0.8)
	end
	if self.k < 1 then return end
	self.late = self.late + dt
	if at:Distance(goal) <= SWALLOW or self.late >= LATE then self:Feed(snake, now) end
end

function Tongue:Retract(now, dt)
	self.len = math.max(self.len - RETRACT * dt, 0)
	self.tip = self.mouth + self.dir * self.len
	if self.len <= 0 then self:Reset(now) end
end

function Tongue:Think(snake, now, dt)
	local was = self.state
	local x = snake.Chain.x
	local r = snake:Radius()
	local head, neck = EvilSnake.HeadPoints(x[1], x[2], r, snake.Chain.up)
	local f, up = EvilSnake.Gape(head, neck, snake.Chain.up)
	self.mouth, self.fwd, self.up = head + f * EvilSnake.HeadRadius(r), f, up
	local on = Setting("tongue") ~= 0
	if self.state == IN then
		self.open = math.max(self.open - dt / OPEN, 0)
		if on and not snake.Held and now >= self.next then self:Try(snake, now) end
	else
		self.open = math.min(self.open + dt / OPEN, 1)
		if self.state == OUT then
			self:Lash(snake, now, dt, on)
		elseif self.state == WRAP then
			self:Reel(snake, now, dt, on)
		else
			self:Retract(now, dt)
		end
	end
	return was ~= IN or self.state ~= IN
end
