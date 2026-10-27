AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
if not EvilSnake then return end

util.AddNetworkString("EvilSnakeBody")

local Setting = EvilSnake.Setting

local ASK_GAP = 0.2
local FAR_EVERY = 5
local PVS_STEP = 8
local DECIDE = 0.2
local LOSE = 1.25
local STUCK = 0.3
local STUCK_TIME = 1
local DETOUR = 1.5
local WANDER_TURN = 90
local WANDER_TIME = { 3, 7 }
local BITE = "npc/ichthyosaur/snap.wav"
local DOORS = { prop_door_rotating = true, func_door = true, func_door_rotating = true }
local DOOR_REACH = 48
local DOOR_GAP = 2
local DOOR_DELAY = 0.2
local DOOR_SLAP = "physics/flesh/flesh_impact_hard2.wav"
local CRUNCH = { "npc/barnacle/barnacle_crunch2.wav", "npc/barnacle/barnacle_crunch3.wav" }
local SQUISH = {
	"physics/flesh/flesh_squishy_impact_hard1.wav", "physics/flesh/flesh_squishy_impact_hard2.wav",
	"physics/flesh/flesh_squishy_impact_hard3.wav", "physics/flesh/flesh_squishy_impact_hard4.wav",
}
local GULP = { "npc/barnacle/barnacle_gulp1.wav", "npc/barnacle/barnacle_gulp2.wav" }
local GULP_DELAY = 0.35
local GULP_AT = 1
local EAT_LEVEL = 80
local MIN_REACH = 4
local PRESENCE_REACH = 450
local DREAD = 4
local GRAB_FEAR = 30
local GRAB_FEAR_RANGE = 900
local FAST = 4
local ESCAPE_PUSH = 350
local ESCAPE_UP = 220
local ESCAPE_GRACE = 4
local LANDING = 6
local SPLASH = { "ambient/water/water_splash1.wav", "ambient/water/water_splash2.wav", "ambient/water/water_splash3.wav" }
local SPLASH_GAP = 0.5
local SPLASH_LEVEL = 75
local MASH_DECAY = 0.15
local THRASH_WRAP = 1000
local THRASH_LOUD = 0.35
local HEARD = 3
local LEAD_MAX = 2
local QUICKER = 0.8
local NIMBLE = 1
local LONGER = 0.5
local GRIP = 0.75
local REEL = 1
local GULP_FASTER = 0.5
local TIRE = 1
local DIGEST = 1.5
local KEEP = 1
local HEAR = 2
local SMELL = 1.5
local DREAD_MORE = 1
local PICKY = 3
local CLING = 2.5
local DROP_TIME = 1.5
local DROP_CHANCE = 0.25
local TOUGH = 0.5
local HEAD_HIT = 1.5
local SHOCK_FADE = 2
local PAIN_GAP = 0.6
local PAIN = { "npc/ichthyosaur/attack_growl1.wav", "npc/ichthyosaur/attack_growl2.wav", "npc/ichthyosaur/attack_growl3.wav" }
local DIE = { "npc/barnacle/barnacle_die1.wav", "npc/barnacle/barnacle_die2.wav" }
local MIN_BOX = 4
local GUTS = 4
local FLING = 8
local MAX_FLING = 2000
local BLAST_NEAR = 150
local LIFT = 0.6
local KG = 60
local MIN_PUSH = 20
local SPREAD = 60
local LIMP_SPEED = 250
local LIMP_TIME = 1.5
local LIMP_MAX = 4
local SMALLEST = 0.25
local BLAST = bit.bor(DMG_BLAST, DMG_BLAST_SURFACE)
local NUDGE = 0.15
local REPATH = 1
local REPATH_FAIL = 3
local STUCK_AGAIN = 4
local SLIP = 3
local SQUEEZE = 3
local LEVEL = 48
local WAYPOINT = 32
local STAY = 0.7
local OFF_LEVEL = 3
local FLYING = 4
local HIDDEN = 1.5
local FRAIL = 1
local SCARED = 0.3
local CRUISE = 200
local CRUISE_AHEAD = 600
local CRUISE_LOOK = 2000
local FOLLOW_LOOK = 32768
local FOLLOW_STEEP = 0.7
local FOLLOW_INTO = 4
local FOLLOW_WALLS = 16
local FOLLOW_WALL_LOOK = 3000
local BACK_PACE = 0.6
local BACK_SLOWEST = 40
local BACK_TIME = 1
local BACK_STEP = 0.5
local BACK_LIMIT = 6
local BACK_REST = 4
local BEHIND = 110
local TURN_ROOM = 4
local PASS_HULL = 0.75
local PASS_MAX = 16
local PULLS = 3
local CRUMB_GAP = 48
local CRUMBS = 64
local CRUMB_CHECKS = 6
local TRAIL_TRUST = 3
local TRAIL_OFF = 4
local TRACK_EVERY = 1
local TRACK_SPAN = 4
local LOITER_TRAVEL = 200
local LOITER_SHARE = 0.2
local GIVE_UP = 8
local CLOSER = 32
local SHUN = 15

local HANDLE_RESIZE = 1
local GRIP_SNAP = 8
local GRIP_LIMP = 0.5
local DROP_LIMP = 1
local PHYSGUN_RANGE = 4096

local ai_disabled = GetConVar("ai_disabled")
local physgun_range = GetConVar("physgun_maxrange")
local snakes = {}

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end
	local ent = ents.Create(class)
	ent:SetPos(tr.HitPos)
	ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
	ent:Spawn()
	ent:Activate()
	return ent
end

function ENT:Initialize()
	self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:DrawShadow(false)
	self:SetGirth(1)
	self:Bounds()
	self.BaseSegments = math.Round(Setting("segments"))
	self:SetLength(self.BaseSegments)
	local filter = function(e)
		return not e.EvilHitboxOwner and e ~= self and not e:IsPlayer() and not e:IsNPC() and not e:IsNextBot()
			and e:GetClass() ~= "evil_snake" and not e.EvilDowned and not e.EvilSnakeRide
	end
	local joints = EvilSnake.Layout(self:GetPos(), self:GetAngles().y, self.BaseSegments, filter)
	self.Chain = EvilSnake.Chain.New(joints, filter)
	self:SetPos(joints[1])
	self.LastThink = CurTime()
	self.Dirty = true
	self.WanderYaw = self:GetAngles().y
	self.Stomach = EvilSnake.Stomach.New(self)
	self.Stomach.onDigest = function(v) self:Absorb(v) end
	self.Mind = EvilSnake.Brain.New()
	self.Shun = setmetatable({}, { __mode = "k" })
	self.Tongue = EvilSnake.Tongue.New()
	self.Hitbox = Evil.Hitbox(self)
	self.Born = CurTime()
	self:SetDigest(1)
	self:Sharpen()
	self:Toughen()
	self:Steady()
	self:Box()
	EvilSnake.Expose(self)
	snakes[self] = true
end

function ENT:Sharpen()
	local mind = self.Mind
	local s = self.Sharp or {}
	self.Sharp = s
	local agility, strength, hunger, fear = mind:Edge("agility"), mind:Edge("strength"), mind:Edge("hunger"), mind:Edge("fear")
	s.speed = 1 + QUICKER * mind:Edge("energy")
	s.turn = 1 + NIMBLE * agility
	s.reach = 1 + LONGER * agility
	s.lick = 1 + LONGER * agility
	s.grip = 1 + GRIP * strength
	s.reel = 1 + REEL * strength
	s.gulp = 1 + GULP_FASTER * strength
	s.tire = 1 + TIRE * mind:Edge("resilience")
	s.tough = 1 + TOUGH * mind:Edge("resilience")
	s.digest = 1 + DIGEST * hunger
	s.keep = 1 + KEEP * hunger
	s.hear = 1 + HEAR * mind:Edge("firearms")
	s.smell = 1 + SMELL * fear
	s.dread = 1 + DREAD_MORE * fear
	s.picky = PICKY * mind:Edge("cunning")
	s.lead = math.min(mind:Edge("tactics"), 1)
	local c = self.Chain
	c.quick = s.turn
	c.walls = math.min(1, mind:Edge("walls") * CLING)
	c.ceilings = math.min(1, mind:Edge("ceilings") * CLING)
	if Setting("wall_addiction") ~= 0 then c.walls, c.ceilings = 1, 1 end
	if math.abs(self:GetDigest() - s.digest) > 1e-3 then self:SetDigest(s.digest) end
	if self.Dreading ~= s.dread then
		self.Dreading = s.dread
		Evil.Presence(self, { reach = PRESENCE_REACH * s.dread, dread = DREAD * s.dread, near = self.Nearest })
	end
end

function ENT:Nearest(pos)
	local best, bestDist
	for _, p in ipairs(self.Chain.x) do
		local d = p:DistToSqr(pos)
		if not bestDist or d < bestDist then best, bestDist = p, d end
	end
	return best
end

function ENT:Bounds()
	local r = self:Radius()
	local mins, maxs = Vector(-r, -r, -r), Vector(r, r, r)
	if not self.Gripped and math.abs(r - (self.Handle or 0)) > HANDLE_RESIZE then
		self.Handle = r
		self:PhysicsInitBox(mins, maxs, "flesh")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_BBOX)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
	end
	self:SetCollisionBounds(mins, maxs)
end

function ENT:Loose()
	local phys = self:GetPhysicsObject()
	return IsValid(phys) and phys:IsMotionEnabled()
end

function ENT:Anchor()
	if self:Loose() then
		self:GetPhysicsObject():EnableMotion(false)
		self:SetAngles(angle_zero)
	end
	self:SetPos(self.Chain.x[1])
end

function ENT:Grip(ply)
	local grip = self.Gripped
	if not grip then
		local x = self.Chain.x
		local at = self:GetPos()
		local best, bestDist = 1, math.huge
		for i, p in ipairs(x) do
			local d = p:DistToSqr(at)
			if d < bestDist then best, bestDist = i, d end
		end
		grip = { by = {}, i = best, off = x[best] - at }
		self.Gripped = grip
		self.Prey, self.LastHead, self.Route = nil, nil, nil
		if IsValid(self:GetPrey()) then self:SetPrey(NULL) end
	end
	grip.by[ply] = true
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(true)
		phys:Wake()
	end
end

function ENT:Ungrip(ply)
	local grip = self.Gripped
	if not grip then return end
	if ply then grip.by[ply] = nil end
	if next(grip.by) then return end
	self.Gripped = nil
	self.Astray = true
	local c = self.Chain
	EvilSnake.Chain.Unpin(c)
	EvilSnake.Chain.Limp(c, DROP_LIMP)
end

function ENT:Handled(dt)
	local grip = self.Gripped
	if not grip then return false end
	for ply in pairs(grip.by) do
		local wep = IsValid(ply) and ply:Alive() and ply:KeyDown(IN_ATTACK) and ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "weapon_physgun" then grip.by[ply] = nil end
	end
	if not next(grip.by) then
		self:Ungrip()
		return false
	end
	local c = self.Chain
	grip.off:Mul(math.exp(-GRIP_SNAP * dt))
	EvilSnake.Chain.Pin(c, math.min(grip.i, #c.x), self:GetPos() + grip.off)
	EvilSnake.Chain.Limp(c, GRIP_LIMP)
	return true
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

local PACK, PACK_MAX = EvilSnake.PACK, EvilSnake.PACK_MAX
local packed = {}

local function Pack(v)
	return math.Clamp(math.Round(v * PACK), -PACK_MAX, PACK_MAX)
end

function ENT:SendBody(to)
	local x = self.Chain.x
	net.Start("EvilSnakeBody")
	net.WriteEntity(self)
	net.WriteDouble(CurTime() - self.Chain.acc)
	net.WriteUInt(#x, 8)
	local rx, ry, rz = x[1]:Unpack()
	net.WriteFloat(rx)
	net.WriteFloat(ry)
	net.WriteFloat(rz)
	local most, k = 0, 0
	for i = 2, #x do
		local p = x[i]
		local dx, dy, dz = Pack(p.x - rx), Pack(p.y - ry), Pack(p.z - rz)
		packed[k + 1], packed[k + 2], packed[k + 3] = dx, dy, dz
		k = k + 3
		most = math.max(most, math.abs(dx), math.abs(dy), math.abs(dz))
		rx, ry, rz = rx + dx / PACK, ry + dy / PACK, rz + dz / PACK
	end
	local bits = 2
	while 2 ^ (bits - 1) <= most do bits = bits + 1 end
	net.WriteUInt(bits, 5)
	for i = 1, k do net.WriteInt(packed[i], bits) end
	net.WriteNormal(self.Chain.up)
	local transit = self.Stomach.transit
	net.WriteUInt(#transit, 6)
	for _, m in ipairs(transit) do
		net.WriteFloat(m.at)
		net.WriteFloat(m.size)
		net.WriteEntity(m.ply or NULL)
	end
	local held = self.Held
	net.WriteBool(held ~= nil)
	if held then
		net.WriteEntity(held.ent)
		net.WriteDouble(held.at)
		net.WriteFloat(held.hold)
		net.WriteFloat(held.pace)
		net.WriteFloat(held.size)
	end
	self.Tongue:Write()
	if to then net.Send(to) else net.Broadcast() end
end

function ENT:Recipients()
	self.Sends = (self.Sends or 0) + 1
	if self.Sends % FAR_EVERY == 0 then return end
	local rf = RecipientFilter()
	local x = self.Chain.x
	for i = 1, #x, PVS_STEP do rf:AddPVS(x[i]) end
	rf:AddPVS(x[#x])
	for _, m in ipairs(self.Stomach.transit) do
		if IsValid(m.ply) then rf:AddPlayer(m.ply) end
	end
	local held = self.Held
	if held and IsValid(held.ent) and held.ent:IsPlayer() then rf:AddPlayer(held.ent) end
	return rf
end

local function Unseen(ply)
	local f = ply.EvilFrozen
	if f then return f.notarget end
	return ply:IsFlagSet(FL_NOTARGET) or GetConVar("ai_ignoreplayers"):GetBool()
end

function EvilSnake.Full(snake)
	local max = Setting("max_meals")
	if max <= 0 then return false end
	local pending = (snake.Held and 1 or 0) + (IsValid(snake.Tongue.ent) and 1 or 0)
	return snake.Stomach:Count() + pending >= max
end

function EvilSnake.Edible(ent, snake)
	if not IsValid(ent) or not (ent:IsPlayer() or ent:IsNPC()) or CurTime() < (ent.EvilSnakeFree or 0) or ent.EvilCrawlerVictim or not Evil.Claimable(ent, snake) then return false end
	if EvilSnake.Full(snake) then return false end
	if ent:IsPlayer() then return Setting("hunt_players") ~= 0 and ent:Alive() and not ent:HasGodMode() and not Unseen(ent) end
	return Setting("hunt_npcs") ~= 0 and ent:IsNPC() and ent:GetClass() ~= "npc_bullseye" and ent:Health() > 0 and not ent.EvilFungusAsleep
end

local Edible = EvilSnake.Edible

function ENT:Mouth()
	local x = self.Chain.x
	local r = self:Radius()
	local head, neck = EvilSnake.HeadPoints(x[1], x[2], r, self.Chain.up)
	return head + (head - neck):GetNormalized() * EvilSnake.HeadRadius(r)
end

hook.Add("EntityFireBullets", "EvilSnakeHeard", function(ent)
	ent.EvilSnakeShot = CurTime()
end)

function ENT:Noticed()
	return Setting("sight_range") * math.max(self.Sharp.hear, self.Sharp.smell)
end

local function Airborne(ent)
	return ent:GetMoveType() == MOVETYPE_NOCLIP or not ent:IsOnGround() and ent:WaterLevel() < 2
end

function ENT:Keeps()
	return self:Noticed() * LOSE * self.Sharp.keep
end

function ENT:Appeal(ent, from, d)
	local score = d / (1 + self.Sharp.picky * EvilSnake.Worth(ent))
	local fly = self.Chain.fly
	if not fly and not self:Level(ent:WorldSpaceCenter(), from) then score = score * OFF_LEVEL end
	if Airborne(ent) then score = fly and score / FLYING or score * FLYING end
	if not EvilSnake.Clear(self, from, ent) then score = score * HIDDEN end
	local max = ent:GetMaxHealth()
	if max > 0 then score = score / (1 + FRAIL * (1 - math.Clamp(ent:Health() / max, 0, 1))) end
	if Evil.Afraid(ent) then score = score / (1 + SCARED) end
	return score
end

function ENT:Overhead(ent, head)
	local c = self.Chain
	if c.fly or c.walls > 0 and c.ceilings > 0 or EvilSnake.Kind(ent) ~= "barnacle" then return false end
	local low = ent:WorldSpaceAABB()
	return low.z > head.z + self:Radius() * 2 + Setting("bite_reach") * self.Sharp.reach
end

function ENT:Shuns(ent, head, now)
	return now < (self.Shun[ent] or 0) or self:Overhead(ent, head)
end

function ENT:Stalled(prey, head, now)
	local d = head:Distance(prey:WorldSpaceCenter())
	local at = prey:GetPos()
	local chase = self.Chase
	if not chase or chase.prey ~= prey or now - chase.last > DECIDE * 2 or d < chase.best - CLOSER or at:DistToSqr(chase.at) > CLOSER * CLOSER then
		chase = { prey = prey, best = d, at = at, since = now }
		self.Chase = chase
	end
	chase.last = now
	if now - chase.since < GIVE_UP then return false end
	self.Shun[prey], self.Chase = now + SHUN, nil
	return true
end

function ENT:FindPrey(from, current)
	local sight, s = Setting("sight_range"), self.Sharp
	local now = CurTime()
	local best, bestScore
	if current and self:Shuns(current, from, now) then current = nil end
	if current then
		local d = from:Distance(current:WorldSpaceCenter())
		if d <= self:Keeps() then best, bestScore = current, self:Appeal(current, from, d) * STAY end
	end
	for _, ent in ipairs(ents.FindInSphere(from, self:Noticed())) do
		if ent ~= current and Edible(ent, self) and not self:Shuns(ent, from, now) then
			local d = from:Distance(ent:WorldSpaceCenter())
			local reach = sight
			if now - (ent.EvilSnakeShot or -math.huge) < HEARD then reach = sight * s.hear end
			if Evil.Afraid(ent) then reach = math.max(reach, sight * s.smell) end
			if d < reach then
				local score = self:Appeal(ent, from, d)
				if not bestScore or score < bestScore then best, bestScore = ent, score end
			end
		end
	end
	return best
end

function ENT:Lead(prey, from)
	local aim = prey:WorldSpaceCenter()
	local lead = self.Sharp.lead
	if lead <= 0 then return aim end
	local vel = prey:GetVelocity()
	vel.z = 0
	local speed = math.max(Setting("hunt_speed") * self.Sharp.speed, 1)
	return aim + vel * (math.min(from:Distance(aim) / speed, LEAD_MAX) * lead)
end

function ENT:Grow()
	local st = self.Stomach
	local mass = st:Mass() + st:Eating(#self.Chain.x - 1)
	self:SetLength(st:Length(self.BaseSegments, mass))
	local girth = st:Girth(mass)
	if math.abs(girth - self.Chain.girth) < 1e-3 then return end
	self:SetGirth(girth)
	EvilSnake.Chain.Swell(self.Chain, girth)
	self:Bounds()
	if not self.Dead then self:Box() end
	self.Dirty = true
end

function ENT:Absorb(v)
	local lessons = self.Mind:Learn(v)
	self:Sharpen()
	self:Grow()
	self:Toughen()
	self:Steady()
	self:Heal(self.Toughness * Setting("meal_heal"))
	hook.Run("EvilSnakeAbsorbed", self, v, lessons)
end

function ENT:Rethink()
	self.Mind = EvilSnake.Brain.Rebuild(self.Stomach.victims)
	self:Sharpen()
	self.Stomach:Changed()
	self:Grow()
end

function ENT:EvilStomachSummary()
	local mind = self.Mind
	if not mind then return end
	local knows = {}
	for i, aspect in ipairs(EvilSnake.ASPECTS) do knows[i] = { aspect, mind:Knows(aspect) } end
	knows[#knows + 1] = { "untenable", self.Steadied or 0 }
	return {
		base = self.BaseSegments, length = self:GetLength(), girth = self:GetGirth(),
		power = mind.power, level = mind:Level(), knows = knows,
	}
end

function ENT:EvilStomachProgress()
	local links = math.max(#self.Chain.x - 1, 1)
	local out = {}
	for _, m in ipairs(self.Stomach.transit) do out[#out + 1] = { m.victim.n, math.Clamp(m.at / links, 0, 1) } end
	return out
end

function ENT:Voice(size)
	local volume = Setting("eat_volume")
	if volume <= 0 then return end
	local mass = math.max(self:Weight(), 1e-3)
	local pitch = math.Clamp(105 / mass ^ 0.1 / size ^ 0.25, 50, 160)
	local level = EAT_LEVEL + math.Clamp(math.log(mass, 2) * 2, 0, 10)
	return pitch, level, math.min(volume * (0.7 + 0.3 * size), 1)
end

function ENT:Bite(size)
	local pitch, level, loud = self:Voice(size)
	if not pitch then return end
	self:EmitSound(BITE, level, pitch * math.Rand(0.95, 1.05), loud)
	self:EmitSound(table.Random(SQUISH), level, pitch * math.Rand(0.9, 1.1), loud * 0.8)
end

function ENT:Splash(now)
	local wet = (self.Chain.wet[1] or 0) > 0
	if wet == (self.Wet or false) or now < (self.NextSplash or 0) then return end
	self.Wet, self.NextSplash = wet, now + SPLASH_GAP
	local volume = Setting("slither_volume")
	if volume <= 0 then return end
	local pitch = math.Clamp(110 / math.max(self:Weight(), 1e-3) ^ 0.12, 60, 140)
	self:EmitSound(table.Random(SPLASH), SPLASH_LEVEL, pitch * math.Rand(0.9, 1.1), volume)
end

function ENT:Chomp(size)
	local pitch, level, loud = self:Voice(size)
	if not pitch then return end
	self:EmitSound(table.Random(CRUNCH), level, pitch * math.Rand(0.9, 1.1), loud)
	self:EmitSound(table.Random(SQUISH), level, pitch * math.Rand(0.9, 1.1), loud * 0.8)
	timer.Simple(GULP_DELAY * size, function()
		if IsValid(self) then self:EmitSound(table.Random(GULP), level, pitch * 0.9, loud) end
	end)
end

function ENT:EvilPose(victim)
	local tongued = self.Tongue:Pose(victim)
	if tongued then return tongued end
	local held = self.Held
	if not held or held.ent ~= victim then return end
	local x = self.Chain.x
	local depth = EvilSnake.Hold((CurTime() - held.at) * held.pace, held.hold)
	local up = self.Chain.up
	local head, neck = EvilSnake.HeadPoints(x[1], x[2], self:Radius(), up)
	local pos, ang = EvilSnake.HeldPlace(head, neck, victim:OBBMaxs().z * depth, up)
	return pos, ang
end

function ENT:Grab(ent, now)
	local size = EvilSnake.PreySize(ent)
	local fast = not ent:IsPlayer() and Setting("instant_npcs") ~= 0
	self.Held = {
		ent = ent, at = now, hold = fast and 0 or Setting("hold_time") / self.Sharp.gulp, pace = fast and FAST or 1,
		size = EvilSnake.BulgeSize(size), prey = size, from = ent:GetPos(),
	}
	if not Evil.Pose(ent, self, { act = ACT_BARNACLE_PULL }) then
		self.Held = nil
		self:Unstruggle(ent)
		return
	end
	self:Struggle(ent, EvilSnake.HoldLength(self.Held.hold) / self.Held.pace)
	self.Prey = nil
	self:Bite(size)
	Evil.Frighten(self:Mouth(), GRAB_FEAR_RANGE * self.Sharp.dread, GRAB_FEAR, true)
	self.Dirty = true
	hook.Run("EvilSnakeGrabbed", self, ent)
end

function ENT:Struggle(ent, time)
	local presses = Setting("escape_presses")
	if not ent:IsPlayer() or presses <= 0 then return end
	local m = Evil.Mashing(ent)
	Evil.Mash(ent, self, {
		gain = 1 / (presses * self.Sharp.grip), decay = MASH_DECAY * self.Sharp.tire, time = time, start = m and m.source == self and m.progress or 0,
		done = function() self:Escape(ent) end,
		press = function() self:Thrash(ent) end,
	})
end

function ENT:Thrash(ent)
	ent:SetNW2Int("EvilSnakeThrash", ent:GetNW2Int("EvilSnakeThrash", 0) % THRASH_WRAP + 1)
	if self.Tongue.ent == ent then self.Tongue:Thrash() end
	local pitch, level, loud = self:Voice(1)
	if pitch then
		sound.Play(table.Random(SQUISH), ent:WorldSpaceCenter(), level, pitch * math.Rand(1, 1.25), loud * THRASH_LOUD)
	end
end

function ENT:Unstruggle(ent)
	local m = IsValid(ent) and ent:IsPlayer() and Evil.Mashing(ent)
	if m and m.source == self then Evil.StopMash(ent) end
end

function ENT:Escape(ent)
	ent.EvilSnakeFree = CurTime() + ESCAPE_GRACE
	EvilSnake.Watch(ent, "slipped")
	if self.Tongue.ent == ent then
		self.Tongue:Drop(self)
		Evil.Up(ent)
		return self:Fling(ent)
	end
	local held = self.Held
	if not held or held.ent ~= ent then return end
	self:Release()
	self:Fling(ent)
	hook.Run("EvilSnakeEscaped", self, ent)
end

function ENT:Fling(ent)
	if not IsValid(ent) then return end
	local away = ent:WorldSpaceCenter() - self:Mouth()
	away.z = 0
	if away:LengthSqr() < 1 then
		away = Vector(self.Tongue.fwd)
		away.z = 0
	end
	away:Normalize()
	ent.EvilSnakeLanding = CurTime() + LANDING
	ent:SetVelocity(away * ESCAPE_PUSH + Vector(0, 0, ESCAPE_UP))
end

hook.Add("OnPlayerHitGround", "EvilSnakeLanding", function(ply)
	local t = ply.EvilSnakeLanding
	if not t then return end
	ply.EvilSnakeLanding = nil
	if CurTime() <= t then return true end
end)

local function Free(ent, pos, snake)
	return not util.TraceHull({
		start = pos, endpos = pos, mins = ent:OBBMins(), maxs = ent:OBBMaxs(),
		mask = ent:IsPlayer() and MASK_PLAYERSOLID or MASK_NPCSOLID,
		filter = function(e) return e ~= ent and e ~= snake and not e.EvilHitboxOwner end,
	}).StartSolid
end

function ENT:Release()
	local held = self.Held
	self.Held = nil
	self.Dirty = true
	if not held then return end
	local ent = held.ent
	self:Unstruggle(ent)
	if Evil.Owner(ent) ~= self then return end
	Evil.Unpose(ent, self)
	local mouth = self:Mouth()
	ent:SetPos(Free(ent, mouth, self) and mouth or held.from)
	ent:SetAngles(Angle(0, ent:GetAngles().y, 0))
	ent.EvilSnakeLanding = CurTime() + LANDING
	hook.Run("EvilSnakeReleased", self, ent)
end

local function Notice(snake, ent)
	if not GAMEMODE.SendDeathNotice or not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then return end
	local victim = ent:IsPlayer() and ent or GAMEMODE:GetDeathNoticeEntityName(ent)
	GAMEMODE:SendDeathNotice(GAMEMODE:GetDeathNoticeEntityName(snake), "evil_snake", victim, 0)
end

function ENT:Hold(now)
	local held = self.Held
	if not held then return end
	local ent = held.ent
	if Evil.Owner(ent) ~= self or (ent:IsPlayer() and not ent:Alive()) then return self:Release() end
	self.Dirty = true
	if (now - held.at) * held.pace < EvilSnake.HoldLength(held.hold) then return end
	self.Held = nil
	local v = self.Stomach:Swallow(ent, GULP_AT)
	self:Chomp(held.prey)
	hook.Run("EvilSnakeSwallowed", self, v, ent)
	Notice(self, ent)
	if ent:IsPlayer() then
		self:Unstruggle(ent)
		Evil.Unpose(ent, self)
		ent:KillSilent()
	else
		ent:Remove()
	end
	self.NextDecide = now
end

function ENT:OnRemove()
	snakes[self] = nil
	EvilSnake.Unrotor(self)
	self.Tongue:Drop(self)
	self:Release()
	self.Stomach:Vacate()
	self.Hitbox:Clear()
end

function ENT:Toughen()
	local max = math.max(Setting("health") * math.max(self:Weight(), 1e-3) ^ Setting("size_health") * self.Sharp.tough, 1)
	local old = self.Toughness
	if old and math.abs(old - max) < 0.5 then return end
	self.Hp = old and self.Hp * max / old or max
	self.Toughness = max
	self:SetMaxHealth(math.ceil(max))
	self:SetHealth(math.ceil(self.Hp))
end

function ENT:Steadiness()
	local need = Setting("untenable_meals")
	if need <= 0 then return 0 end
	return math.min(self.Stomach:Mass() * self.Sharp.tough / need, 1)
end

function ENT:Steady()
	local was = self.Untenable
	self.Steadied = self:Steadiness()
	self.Untenable = self.Steadied >= 1
	if self.Untenable and not was then hook.Run("EvilSnakeUntenable", self) end
end

function ENT:Limp()
	return self.Gripped ~= nil or CurTime() < (self.LimpUntil or 0)
end

local function Struck(dmg, fallback)
	local pos = dmg:GetDamagePosition()
	if pos:IsZero() then pos = dmg:GetReportedPosition() end
	if pos:IsZero() then pos = fallback end
	return pos
end

function ENT:Knock(dmg, amount)
	local k = Setting("knockback")
	if k <= 0 or self.Untenable then return end
	local give = k * (1 - self.Steadied) / math.max(self:Weight(), SMALLEST)
	local c = self.Chain
	local x = c.x
	local from = Struck(dmg, x[1])
	local peak
	if bit.band(dmg:GetDamageType(), BLAST) ~= 0 then
		peak = math.min(amount * FLING * give, MAX_FLING)
		for i, p in ipairs(x) do
			local away = p - from
			local d = away:Length()
			away = away / math.max(d, 1)
			away.z = math.max(away.z, 0) + LIFT
			away:Normalize()
			EvilSnake.Chain.Kick(c, i, away * (peak * BLAST_NEAR / (BLAST_NEAR + d)))
		end
	else
		local force = dmg:GetDamageForce()
		local f = force:Length()
		peak = math.min(f / KG * give, MAX_FLING)
		if peak < MIN_PUSH or not (f < math.huge) then return end
		local dir = force / f
		if peak >= LIMP_SPEED then
			dir.z = math.max(dir.z, 0) + LIFT
			dir:Normalize()
		end
		local hit = self:Nearest(from)
		for i, p in ipairs(x) do
			local w = math.exp(-(p:Distance(hit) / SPREAD) ^ 2)
			if w > 0.01 then EvilSnake.Chain.Kick(c, i, dir * (peak * w)) end
		end
	end
	if peak < LIMP_SPEED then return end
	local limp = math.min(LIMP_TIME * peak / LIMP_SPEED, LIMP_MAX)
	self.LimpUntil = math.max(self.LimpUntil or 0, CurTime() + limp)
	EvilSnake.Chain.Limp(c, limp)
	self.Prey = nil
	self:Spit()
	hook.Run("EvilSnakeFlung", self, peak, limp)
end

function ENT:Heal(amount)
	if self.Dead or amount <= 0 or self.Hp >= self.Toughness then return end
	self.Hp = math.min(self.Hp + amount, self.Toughness)
	local hp = math.ceil(self.Hp)
	if hp ~= self:Health() then self:SetHealth(hp) end
end

function ENT:Regen(now, dt)
	local rate = Setting("regen")
	if rate <= 0 or now - (self.LastHurt or -math.huge) < Setting("regen_delay") then return end
	self:Heal(rate * dt)
end

function ENT:Box()
	local x = self.Chain.x
	local r, n = self:Radius(), #x
	local body, tail = EvilSnake.Shape()
	self.Hitbox:Place(x, function(i)
		return math.max(r * EvilSnake.Profile((i - 1) / math.max(n - 1, 1), body, tail), MIN_BOX)
	end)
end

function ENT:Douse()
	if not self:IsOnFire() then return end
	local wet = (self.Chain.wet[1] or 0) > 0
	if wet or not self.Dead and (Setting("killable") == 0 or Setting("dmg_fire") <= 0) then self:Extinguish() end
end

local function Unsuppressed(fn)
	local ply = GetPredictionPlayer()
	if IsValid(ply) then SuppressHostEvents(NULL) end
	fn()
	if IsValid(ply) then SuppressHostEvents(ply) end
end

function ENT:Bleed(pos, size)
	local fx = EffectData()
	fx:SetOrigin(pos)
	fx:SetColor(BLOOD_COLOR_RED)
	fx:SetScale(size)
	util.Effect("BloodImpact", fx, true, true)
end

function ENT:Cry(sounds)
	local pitch, level, loud = self:Voice(1)
	if pitch then self:EmitSound(table.Random(sounds), level, pitch * math.Rand(0.9, 1.1), loud) end
end

function ENT:HitPos(dmg)
	local pos = dmg:GetDamagePosition()
	if pos:IsZero() then return self.Chain.x[1] end
	if Evil.AreaDamage(dmg) then return self:Nearest(pos) end
	return pos
end

function ENT:Where(dmg)
	if Evil.AreaDamage(dmg) then return Setting("body_damage") end
	local pos, part = dmg:GetDamagePosition(), self.EvilStruckPart
	local head
	if pos:IsZero() then
		head = not part or part.EvilIndex == 1
	else
		local x, r = self.Chain.x, self:Radius()
		local at = EvilSnake.HeadPoints(x[1], x[2], r, self.Chain.up)
		head = pos:Distance(at) <= EvilSnake.HeadRadius(r) * HEAD_HIT
	end
	return Setting(head and "head_damage" or "body_damage")
end

local FROM = { player = "from_players", npc = "from_npcs", world = "from_world" }

function ENT:Exposed()
	return self.Held ~= nil or IsValid(self.Tongue.ent)
end

function ENT:OnTakeDamage(dmg)
	local fresh = self.Hitbox:Fresh(dmg)
	if fresh <= 0 then return end
	self:Knock(dmg, fresh)
	local now = CurTime()
	if self.Dead or Setting("killable") == 0 or now < self.Born + Setting("spawn_grace") or now < (self.HurtUntil or 0) then return end
	if Setting("exposed_only") ~= 0 and not self:Exposed() then return end
	local who, by = Evil.Attacker(dmg)
	local scale = Evil.DamageScale(EvilSnake.Settings, dmg) * self:Where(dmg) * Setting(FROM[who])
	if scale <= 0 then return end
	local amount = fresh * scale - Setting("armor")
	if amount <= 0 then return end
	local override = hook.Run("EvilSnakeHurt", self, dmg, amount)
	if override == false then return end
	if isnumber(override) then amount = override end
	if amount <= 0 then return end
	self.Hp = self.Hp - amount
	self:SetHealth(math.max(math.ceil(self.Hp), 0))
	self.LastHurt = now
	local gap = Setting("hurt_gap")
	if gap > 0 then self.HurtUntil = now + gap end
	Unsuppressed(function()
		self:Bleed(self:HitPos(dmg), 1)
		if now >= (self.NextPain or 0) then
			self.NextPain = now + PAIN_GAP
			self:Cry(PAIN)
		end
	end)
	if self.Hp <= 0 then return self:Die(dmg) end
	self:Shaken(amount, now)
	self:Avenge(by)
end

function ENT:Shaken(amount, now)
	self.Shock = (self.Shock or 0) * math.exp(-(now - (self.ShockAt or now)) / SHOCK_FADE) + amount
	self.ShockAt = now
	local need = Setting("drop_damage")
	if need <= 0 or self.Shock < need or not self:Exposed() then return end
	self.Shock = 0
	self:Spit()
end

function ENT:Spit()
	local tongued = IsValid(self.Tongue.ent)
	local ent = tongued and self.Tongue.ent or self.Held and self.Held.ent
	if not IsValid(ent) then return end
	ent.EvilSnakeFree = CurTime() + ESCAPE_GRACE
	if tongued then
		self.Tongue:Drop(self)
		Evil.Up(ent)
	else
		self:Release()
	end
	self:Fling(ent)
	hook.Run("EvilSnakeSpat", self, ent)
end

function ENT:Avenge(by)
	if Setting("retaliate") == 0 or by == self.Prey or self:Exposed() or self:Limp() or not Edible(by, self) then return end
	self.Prey = by
	self:SetPrey(by)
end

function ENT:Die(dmg)
	self.Dead = true
	self:SetDead(true)
	self.Hp = 0
	self:SetHealth(0)
	self.Tongue.target = nil
	self.Tongue:Drop(self)
	self:Release()
	self.Stomach:Vacate()
	self.Hitbox:Clear()
	EvilSnake.Unrotor(self)
	EvilSnake.Unexpose(self)
	Evil.Absent(self)
	self.Prey = nil
	self:SetPrey(NULL)
	local c = self.Chain
	c.walls, c.ceilings, c.back = 0, 0, 0
	EvilSnake.Chain.Drive(c, EvilSnake.Chain.HeadYaw(c), 0)
	Unsuppressed(function()
		for i = 1, #c.x, GUTS do self:Bleed(c.x[i], 2) end
		self:Cry(DIE)
	end)
	local attacker, inflictor = dmg:GetAttacker(), dmg:GetInflictor()
	hook.Run("EvilSnakeKilled", self, attacker, inflictor)
	if Setting("npc_kill") ~= 0 then
		ProtectedCall(function() hook.Run("OnNPCKilled", self, attacker, inflictor) end)
	end
	SafeRemoveEntityDelayed(self, Setting("corpse_time"))
	self.Dirty = true
end

function EvilSnake.Reaches(ent, from, to, steps, reach)
	for k = 0, steps do
		local at = LerpVector(k / steps, from, to)
		if ent:NearestPoint(at):Distance(at) <= reach then return true end
	end
	return false
end

local Reaches = EvilSnake.Reaches

function EvilSnake.Clear(snake, from, ent, near)
	local filter = function(e)
		return e ~= snake and e ~= ent and not e.EvilHitboxOwner and not e.EvilSnakeRide and not e:IsPlayer() and not e:IsNPC() and e:GetClass() ~= "evil_snake"
	end
	local center = ent:WorldSpaceCenter()
	if not util.TraceLine({ start = from, endpos = center, mask = MASK_SOLID, filter = filter }).Hit then return true end
	local edge = LerpVector(NUDGE, ent:NearestPoint(near or from), center)
	return not util.TraceLine({ start = from, endpos = edge, mask = MASK_SOLID, filter = filter }).Hit
end

local Clear = EvilSnake.Clear

function ENT:Catch(now)
	local mouth = self:Mouth()
	local from = self.LastMouth or mouth
	self.LastMouth = mouth
	if self.Held or IsValid(self.Tongue.ent) then return end
	local reach = Setting("bite_reach") * self.Sharp.reach
	local travel = from:Distance(mouth)
	local steps = math.ceil(travel / math.max(reach, MIN_REACH))
	for _, ent in ipairs(ents.FindInSphere((from + mouth) * 0.5, reach + travel * 0.5)) do
		if Edible(ent, self) and Reaches(ent, from, mouth, steps, reach) and Clear(self, self.Chain.x[1], ent, mouth) then
			self:Grab(ent, now)
			return
		end
	end
end

function ENT:Above(prey, head)
	return prey:GetPos().z > head.z + Setting("step_height") + self:Radius() * 2
end

function ENT:Drop(prey, head)
	local c = self.Chain
	if EvilSnake.Chain.Surface(c) ~= "ceiling" then return end
	if not prey then
		if Setting("wall_addiction") == 0 and math.random() < DROP_CHANCE then EvilSnake.Chain.LetGo(c, DROP_TIME) end
		return
	end
	local at = prey:WorldSpaceCenter()
	local reach = self:Radius() * 2 + Setting("bite_reach") * self.Sharp.reach
	if at.z < head.z and (at.x - head.x) ^ 2 + (at.y - head.y) ^ 2 < reach * reach and Clear(self, head, prey) then
		EvilSnake.Chain.LetGo(c, DROP_TIME)
	end
end

function ENT:Level(at, head)
	return math.abs(at.z - head.z) <= Setting("step_height") + self:Radius() * 2 + LEVEL
end

function ENT:Front(prey, head, aim)
	local fwd = Angle(0, prey:GetAngles().y, 0):Forward()
	local tr = util.TraceLine({ start = aim, endpos = aim + fwd * math.abs(aim.z - head.z), mask = MASK_SOLID_BRUSHONLY })
	return tr.HitPos - fwd * (tr.Hit and self:Radius() * 2 or 0)
end

local pass = { mins = Vector(), maxs = Vector(), mask = MASK_SOLID }

function ENT:Passable(from, to)
	local c = self.Chain
	local hull = c.hull[1]
	local h = math.min(hull, PASS_MAX) * PASS_HULL
	local lift = Setting("step_height") * 0.5
	pass.mins:SetUnpacked(-h, -h, -h)
	pass.maxs:SetUnpacked(h, h, h)
	pass.start = Vector(from.x, from.y, from.z + lift)
	pass.endpos = Vector(to.x, to.y, to.z + hull + lift)
	pass.filter = c.filter
	return not util.TraceHull(pass).Hit
end

function ENT:Sniff(prey)
	local s = self.Scent
	local at = prey:GetPos()
	if not s or s.prey ~= prey then
		self.Scent = { prey = prey, pts = { at }, i = 1, held = -math.huge }
		return
	end
	if Airborne(prey) and not self.Chain.fly then return end
	local pts = s.pts
	if pts[#pts]:DistToSqr(at) < CRUMB_GAP * CRUMB_GAP then return end
	pts[#pts + 1] = at
	if #pts > CRUMBS then
		table.remove(pts, 1)
		s.i = math.max(1, s.i - 1)
	end
end

function ENT:Trail(head, now)
	local s = self.Scent
	local pts = s.pts
	local n = #pts
	local near = self:Radius() * 2 + WAYPOINT
	while s.i <= n do
		local at = pts[s.i]
		if (at.x - head.x) ^ 2 + (at.y - head.y) ^ 2 > near * near then break end
		s.i = s.i + 1
	end
	if s.i > n then return end
	local step = math.max(1, math.ceil((n - s.i) / CRUMB_CHECKS))
	for j = n, s.i + 1, -step do
		if self:Passable(head, pts[j]) then
			s.i, s.held = j, now
			break
		end
	end
	if s.held ~= now and self:Passable(head, pts[s.i]) then s.held = now end
	if now - s.held > TRAIL_TRUST then return end
	return pts[s.i]
end

function ENT:Goal(prey, head, now)
	local aim = self:Lead(prey, head)
	local route = self.Route
	local scent = self.Scent
	if self:Level(aim, head) and self:Passable(head, prey:GetPos()) then
		scent.i, scent.held = #scent.pts, now
		if route then route.redo = now end
		return aim
	end
	if now >= (self.TrailOff or 0) then
		local crumb = self:Trail(head, now)
		if crumb then return crumb + Vector(0, 0, self:Radius()) end
	end
	if not route or route.prey ~= prey or now >= route.redo then
		local r = self:Radius()
		local rise = self.Chain.walls > 0 and math.huge or Setting("step_height") + r
		local known = route and route.prey == prey and route.pts or nil
		local pts = EvilSnake.Path.Find(head, prey:WorldSpaceCenter(), rise, known)
		if not route or route.prey ~= prey or pts ~= known then
			route = { prey = prey, pts = pts, i = 1 }
			self.Route = route
		end
		route.redo = now + (pts and #pts > 0 and REPATH or REPATH_FAIL)
	end
	local pts = route.pts
	if not pts or #pts == 0 then return self:Front(prey, head, aim) end
	local near = self:Radius() * 2 + WAYPOINT
	local pulls = 0
	while route.i < #pts do
		local at = pts[route.i]
		if (at.x - head.x) ^ 2 + (at.y - head.y) ^ 2 > near * near then
			if pulls >= PULLS or not self:Passable(head, pts[route.i + 1]) then break end
			pulls = pulls + 1
		end
		route.i = route.i + 1
	end
	if route.i >= #pts then return aim end
	return pts[route.i] + Vector(0, 0, self:Radius())
end

function ENT:Cruise(head, yaw)
	local aim = head + Angle(0, yaw, 0):Forward() * CRUISE_AHEAD
	local ground = util.TraceLine({ start = head, endpos = head - Vector(0, 0, CRUISE_LOOK), mask = MASK_SOLID_BRUSHONLY }).HitPos
	local roof = util.TraceLine({ start = head, endpos = head + Vector(0, 0, CRUISE), mask = MASK_SOLID_BRUSHONLY }).HitPos
	aim.z = math.min(ground.z + CRUISE, roof.z - self:Radius() * 2)
	return aim
end

function ENT:WallNear(head, spot)
	local r = self:Radius()
	local from = head + Vector(0, 0, r)
	local best, bestScore
	for k = 0, FOLLOW_WALLS - 1 do
		local dir = Angle(0, k * 360 / FOLLOW_WALLS, 0):Forward()
		local tr = util.TraceLine({ start = from, endpos = from + dir * FOLLOW_WALL_LOOK, mask = MASK_SOLID_BRUSHONLY })
		if tr.Hit and not tr.HitSky and not tr.HitNoDraw and math.abs(tr.HitNormal.z) < FOLLOW_STEEP then
			local score = from:Distance(tr.HitPos) + math.sqrt((tr.HitPos.x - spot.x) ^ 2 + (tr.HitPos.y - spot.y) ^ 2)
			if not bestScore or score < bestScore then best, bestScore = tr, score end
		end
	end
	if best then return best.HitPos - best.HitNormal * r * FOLLOW_INTO end
end

function ENT:Crawl(c, head, tr, spot, to)
	local on = EvilSnake.Chain.Surface(c)
	local n = tr.HitNormal
	local r = self:Radius()
	if on == "wall" then
		local out = Vector(c.cn[1].x, c.cn[1].y, 0)
		out:Normalize()
		local flat = Vector(to.x, to.y, 0)
		local away = flat:Dot(out)
		if math.abs(to.z) <= r then c.climb = away > 0 and -1 or 1 end
		return head + flat - out * away - out * math.max(math.abs(to.z), math.abs(away))
	end
	if on == "ceiling" and n.z > -FOLLOW_STEEP and to.z < -r and to.x ^ 2 + to.y ^ 2 < (r * 2 + WAYPOINT) ^ 2 then
		EvilSnake.Chain.LetGo(c, DROP_TIME)
	end
	if math.abs(n.z) < FOLLOW_STEEP then return tr.HitPos - n * r * FOLLOW_INTO end
	if n.z <= -FOLLOW_STEEP and on ~= "ceiling" then return self:WallNear(head, spot) or spot end
	return spot
end

function ENT:Follow(c, head)
	local ply = EvilSnake.Leader
	if not IsValid(ply) then return end
	self.Prey, self.LastHead, self.Route = nil, nil, nil
	if IsValid(self:GetPrey()) then self:SetPrey(NULL) end
	c.walls, c.ceilings = 1, 1
	local eye = ply:EyePos()
	local tr = util.TraceLine({ start = eye, endpos = eye + ply:GetAimVector() * FOLLOW_LOOK, mask = MASK_SOLID_BRUSHONLY })
	local r = self:Radius()
	local spot = tr.HitPos + tr.HitNormal * r
	local to = spot - head
	if to:LengthSqr() < (r * 2 + WAYPOINT) ^ 2 then
		EvilSnake.Chain.Drive(c, EvilSnake.Chain.HeadYaw(c), 0)
		return true
	end
	c.climb = to.z < -r and -1 or 1
	local aim = c.fly and spot or self:Crawl(c, head, tr, spot, to)
	to = aim - head
	local speed = Setting(c.fly and "fly_speed" or "hunt_speed") * self.Sharp.speed
	EvilSnake.Chain.Drive(c, math.deg(math.atan2(to.y, to.x)), speed, aim)
	return true
end

function ENT:Doors(now)
	local c = self.Chain
	if Setting("open_doors") == 0 or c.speed <= 0 or now < (self.NextDoor or 0) then return end
	local head = c.x[1]
	local fwd = Angle(0, EvilSnake.Chain.HeadYaw(c), 0):Forward()
	local tr = util.TraceLine({
		start = head, endpos = head + fwd * (self:Radius() * 2 + DOOR_REACH), mask = MASK_SOLID,
		filter = function(e) return e ~= self and not e.EvilHitboxOwner and not e.EvilSnakeRide end,
	})
	local door = tr.Entity
	if not IsValid(door) or not DOORS[door:GetClass()] then return end
	self.NextDoor = now + DOOR_GAP
	local tongue, at = self.Tongue, tr.HitPos
	if tongue.state == EvilSnake.TONGUE_IN then
		local to = at - tongue.mouth
		tongue:Start(self, nil, to:Length() + 8, to:GetNormalized())
	end
	timer.Simple(DOOR_DELAY, function()
		if not IsValid(door) or not IsValid(self) then return end
		door:Fire("Unlock")
		if door:GetClass() == "prop_door_rotating" then
			door:Fire("OpenAwayFrom", "!activator", 0, self)
		else
			door:Fire("Open")
		end
		sound.Play(DOOR_SLAP, at, 80, math.random(80, 100))
	end)
end

function ENT:Back(now, seconds, detour)
	local c = self.Chain
	if c.fly or self.Gripped then return false end
	EvilSnake.Chain.Back(c, seconds, math.max(Setting("hunt_speed") * self.Sharp.speed * BACK_PACE, BACK_SLOWEST))
	self.BackUntil, self.BackDetour, self.Track = now + seconds, detour, nil
	return true
end

function ENT:Detour(now, yaw)
	self.WanderYaw = yaw
	self.NextWander = now + math.Rand(WANDER_TIME[1], WANDER_TIME[2])
	self.DetourUntil = now + DETOUR
end

function ENT:Cramped(head, yaw)
	local reach = self:Radius() * TURN_ROOM
	local side = Angle(0, yaw + 90, 0):Forward() * reach
	local filter = self.Chain.filter
	local a = util.TraceLine({ start = head, endpos = head + side, mask = MASK_SOLID, filter = filter }).Fraction
	local b = util.TraceLine({ start = head, endpos = head - side, mask = MASK_SOLID, filter = filter }).Fraction
	return a + b < 1
end

function ENT:Turnabout(now, c, head, yaw)
	if c.fly or EvilSnake.Chain.Surface(c) ~= "floor" or now < (self.BackRest or 0) then return false end
	if math.abs(math.AngleDifference(self.GoalYaw, yaw)) <= BEHIND or not self:Cramped(head, yaw) then
		self.Backed = 0
		return false
	end
	self.Backed = (self.Backed or 0) + BACK_STEP
	if self.Backed > BACK_LIMIT then
		self.Backed, self.BackRest = 0, now + BACK_REST
		EvilSnake.Chain.Ghost(c, SLIP)
		return false
	end
	return self:Back(now, BACK_STEP, false)
end

function ENT:Loiter(now, c, head)
	if now < (self.NextTrack or 0) then return false end
	self.NextTrack = now + TRACK_EVERY
	local track = self.Track
	if not track or now - track[#track][3] > TRACK_EVERY * 2 then track = {} end
	self.Track = track
	track[#track + 1] = { Vector(head), c.speed, now }
	if #track > TRACK_SPAN then table.remove(track, 1) end
	if #track < TRACK_SPAN then return false end
	local travel = 0
	for k = 2, #track do travel = travel + track[k][2] * TRACK_EVERY end
	return travel >= LOITER_TRAVEL and head:Distance(track[1][1]) < travel * LOITER_SHARE
end

function ENT:Unstick(now, c, head)
	local level = now < (self.StuckAgain or 0) and (self.StuckLevel or 0) + 1 or 1
	self.StuckLevel, self.StuckAgain = level, now + STUCK_AGAIN
	self.Stuck, self.Track = 0, nil
	EvilSnake.Chain.Squeeze(c, SQUEEZE)
	c.climb = -c.climb
	if IsValid(self.Prey) and self:Above(self.Prey, head) then EvilSnake.Watch(self.Prey, "climbed") end
	if self.Route then self.Route.redo = now end
	if level >= 2 then
		EvilSnake.Chain.Ghost(c, SLIP)
		if level == 2 and navmesh.IsLoaded() then self.TrailOff = now + TRAIL_OFF end
	end
	local open = EvilSnake.Chain.Opening(c, level < 3 and self.GoalYaw or nil)
	local behind = math.abs(math.AngleDifference(open, EvilSnake.Chain.HeadYaw(c))) > BEHIND
	if (level >= 2 or behind) and self:Back(now, BACK_TIME * math.min(level, 3), true) then return end
	self:Detour(now, open)
end

function ENT:Decide(now)
	local c = self.Chain
	local head = c.x[1]
	local yaw = EvilSnake.Chain.HeadYaw(c)
	if c.landed then
		self.WanderYaw = EvilSnake.Chain.Away(self.WanderYaw, c.landed)
		c.landed = nil
	end
	if c.turned then
		self.WanderYaw = self.WanderYaw + c.turned
		c.turned = nil
	end
	if self.Held or IsValid(self.Tongue.ent) then
		self.Prey, self.LastHead, self.Route = nil, nil, nil
		if IsValid(self:GetPrey()) then self:SetPrey(NULL) end
		EvilSnake.Chain.Drive(c, yaw, 0)
		return
	end
	if self:Follow(c, head) then return end
	self:Doors(now)
	local backing = self.BackUntil ~= nil
	if backing and now >= self.BackUntil then
		backing, self.BackUntil = false, nil
		if self.BackDetour then self:Detour(now, EvilSnake.Chain.Opening(c, (self.StuckLevel or 0) < 3 and self.GoalYaw or nil)) end
	end
	if not backing then
		if self.LastHead and c.speed > 0 then
			local moved = self.LastHead:Distance(head)
			if moved < c.speed * DECIDE * STUCK then
				self.Stuck = (self.Stuck or 0) + DECIDE
			else
				self.Stuck = 0
			end
		end
		if (self.Stuck or 0) >= STUCK_TIME then
			self:Unstick(now, c, head)
		elseif self:Loiter(now, c, head) then
			self.StuckLevel, self.StuckAgain = math.max(self.StuckLevel or 0, 1), now + STUCK_AGAIN
			self:Unstick(now, c, head)
		end
	end
	self.LastHead = Vector(head)

	local old = self.Prey
	local edible = Edible(old, self)
	local prey = self:FindPrey(head, edible and old or nil)
	if prey and self:Stalled(prey, head, now) then prey = self:FindPrey(head) end
	if edible and prey ~= old and head:Distance(old:WorldSpaceCenter()) > self:Keeps() then
		EvilSnake.Watch(old, self:Above(old, head) and "climbed" or "outran")
	end
	self.Prey = prey
	if self:GetPrey() ~= (prey or NULL) then self:SetPrey(prey or NULL) end
	if prey then self:Sniff(prey) else self.GoalYaw = nil end
	if self.BackUntil then
		EvilSnake.Chain.Drive(c, yaw, 0)
		return
	end

	if prey and now >= (self.DetourUntil or 0) and c.fly then
		local aim = Clear(self, head, prey) and self:Lead(prey, head) or self:Goal(prey, head, now)
		local to = aim - head
		self.GoalYaw = math.deg(math.atan2(to.y, to.x))
		EvilSnake.Chain.Drive(c, self.GoalYaw, Setting("fly_speed") * self.Sharp.speed, aim)
	elseif prey and now >= (self.DetourUntil or 0) then
		local aim = self:Goal(prey, head, now)
		local to = aim - head
		local r = self:Radius()
		self.GoalYaw = math.deg(math.atan2(to.y, to.x))
		if self:Turnabout(now, c, head, yaw) then
			EvilSnake.Chain.Drive(c, yaw, 0)
			return
		end
		if to.z > r then c.climb = 1 elseif to.z < -r then c.climb = -1 end
		self:Drop(prey, head)
		local near = r * 2 + WAYPOINT
		if (Airborne(prey) or c.walls <= 0) and not self:Level(aim, head) and to.x * to.x + to.y * to.y < near * near then
			EvilSnake.Chain.Drive(c, yaw, 0)
		else
			EvilSnake.Chain.Drive(c, math.deg(math.atan2(to.y, to.x)), Setting("hunt_speed") * self.Sharp.speed, aim)
		end
	elseif prey or Setting("wander") ~= 0 then
		if now >= (self.NextWander or 0) then
			self.WanderYaw = self.WanderYaw + math.Rand(-WANDER_TURN, WANDER_TURN)
			self.NextWander = now + math.Rand(WANDER_TIME[1], WANDER_TIME[2])
			c.climb = math.random() < 0.5 and 1 or -1
			if not prey then self:Drop(nil, head) end
		end
		local aim = c.fly and self:Cruise(head, self.WanderYaw) or nil
		if not prey and not c.fly and Setting("wall_addiction") ~= 0 and EvilSnake.Chain.Surface(c) == "floor" then
			local wall = self:WallNear(head, head)
			if wall then
				aim, c.climb = wall, 1
				self.WanderYaw = math.deg(math.atan2(wall.y - head.y, wall.x - head.x))
			end
		end
		EvilSnake.Chain.Drive(c, self.WanderYaw, Setting("wander_speed") * self.Sharp.speed, aim)
	else
		EvilSnake.Chain.Drive(c, yaw, 0)
	end
end

function ENT:Switched()
	if not ai_disabled:GetBool() then return false end
	if self.Held then self:Release() end
	local state = self.Tongue.state
	if state == EvilSnake.TONGUE_OUT or state == EvilSnake.TONGUE_WRAP then self.Tongue:Drop(self) end
	self.Prey, self.LastHead, self.Route = nil, nil, nil
	if IsValid(self:GetPrey()) then self:SetPrey(NULL) end
	return true
end

function ENT:Think()
	local now = CurTime()
	local dt = now - self.LastThink
	self.LastThink = now
	local c = self.Chain
	local alive = not self.Dead
	local off = alive and self:Switched()
	self:Handled(dt)
	if alive and now >= (self.NextDecide or 0) then
		self.NextDecide = now + DECIDE
		self:Sharpen()
		self:Grow()
		self:Toughen()
		self:Steady()
		if off or self:Limp() then
			EvilSnake.Chain.Drive(c, EvilSnake.Chain.HeadYaw(c), 0)
		else
			self:Decide(now)
		end
	elseif #self.Stomach.transit > 0 then
		self:Grow()
	end
	EvilSnake.Chain.Fit(c, self:GetLength())
	local stepped = EvilSnake.Chain.Update(c, dt)
	if stepped then
		self.Dirty = true
		if alive then self:Box() end
	end
	if not self.Gripped and (stepped or self.Astray or self:Loose()) then self:Anchor() end
	self.Astray = nil
	self:Splash(now)
	self:Douse()
	local slide = math.Round(c.slide or 0)
	if slide ~= self:GetSlide() then self:SetSlide(slide) end
	if alive then
		if not off and not self:Limp() and not IsValid(EvilSnake.Leader) then self:Catch(now) end
		self.Hitbox:Think(now)
		self:Regen(now, dt)
		EvilSnake.Smear(self, now)
		EvilSnake.Propellor(self, now)
	end
	if self.Tongue:Think(self, now, dt) then self.Dirty = true end
	if alive then
		self:Hold(now)
		if self.Stomach:Digest(dt, #c.x - 1, EvilSnake.Chain.Link(c), self.Sharp.digest) then self.Dirty = true end
	end
	if (self.Dirty or self.Behind) and now >= (self.NextSend or 0) then
		local to = self.Dirty and self:Recipients()
		self.Dirty = false
		self.Behind = to and true or nil
		self.NextSend = now + EvilSnake.SEND
		if not to or to:GetCount() > 0 then self:SendBody(to) end
	end
	self:NextThink(now)
	return true
end

net.Receive("EvilSnakeBody", function(_, ply)
	local ent = net.ReadEntity()
	if not IsValid(ent) or ent:GetClass() ~= "evil_snake" or not ent.Chain then return end
	local now = RealTime()
	local asked = ply.EvilSnakeAsk or setmetatable({}, { __mode = "k" })
	ply.EvilSnakeAsk = asked
	if now < (asked[ent] or 0) then return end
	asked[ent] = now + ASK_GAP
	ent:SendBody(ply)
end)

hook.Add("StartCommand", "EvilSnakeGrip", function(ply, cmd)
	if not next(snakes) or not cmd:KeyDown(IN_ATTACK) then return end
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep:GetClass() ~= "weapon_physgun" then return end
	local eye = ply:EyePos()
	local range = physgun_range and physgun_range:GetFloat() or PHYSGUN_RANGE
	local tr = util.TraceLine({ start = eye, endpos = eye + cmd:GetViewAngles():Forward() * range, mask = MASK_SHOT, filter = ply })
	local snake = Evil.HitboxOwner(tr.Entity)
	if not snake or not snakes[snake] or snake.Gripped then return end
	snake.Astray = true
	snake:SetPos(tr.HitPos)
end)

hook.Add("OnPhysgunPickup", "EvilSnakeGrip", function(ply, ent)
	if snakes[ent] then ent:Grip(ply) end
end)

hook.Add("PhysgunDrop", "EvilSnakeGrip", function(ply, ent)
	if snakes[ent] then ent:Ungrip(ply) end
end)

hook.Add("OnPhysgunFreeze", "EvilSnakeGrip", function(_, _, ent, ply)
	if snakes[ent] then ent:Ungrip(ply) end
end)
