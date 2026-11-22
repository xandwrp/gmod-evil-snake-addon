AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")
if not EvilSnake then return end

-- The snake's egg, the same as the crawler's apart from a white shell, 100 health, a dead snake
-- inside, and its own gestation and population cap settings.
-- A physics prop: the HL2 watermelon at twice its size, in a white shell on the client. Laid on a
-- floor it settles like any other object. Laid on a wall or ceiling it is glued in place (motion off) until something knocks it
-- loose: a hit, a shot, the gravity gun or the physics gun. After that it is a loose prop that rolls,
-- can be carried and thrown, and breaks if it is slammed hard enough or runs out of health.
-- When its time is up it hatches into a snake. Broken before then, it spills a few bones (always a
-- skull) that stay in the world, and a stillborn snake that lies dead like any other snake corpse.

local EGG_HEALTH = 100
local EGG_THICK = ENT.EGG_THICK
local EGG_HALF = ENT.EGG_HALF
local HULL_RINGS, HULL_SIDES = 5, 10 -- points on the ellipsoid it collides as
local EGG_MASS = 30
local GLUE_DOT = 0.7      -- surfaces flatter than this (normal.z) are floors; anything else glues
local BREAK_SPEED = 450   -- impact speed that splits it
local HURT_SPEED = 220    -- impact speed that starts to hurt it
local HATCH_RETRY = 2     -- seconds between tries when there is no room to hatch
local HATCH_FORCE = 5     -- tries before it hatches right where it lies anyway
local DROP_PUSH = 40      -- speed it comes off the wall or ceiling with, away from the surface

-- A hard shell: knocks and shots on it sound like this instead of flesh.
local KNOCK = "physics/plastic/plastic_box_impact_hard"  -- 1 to 4
local SHELL_MATERIAL = "plastic_box" -- its physics surface, for the engine's own bump and bullet sounds

local STILLBORN_SIZE = 0.35 -- the dead snake inside, against a newly hatched one: thickness and length

local SKULL = "models/Gibs/HGIBS.mdl"
local RIB = "models/Gibs/HGIBS_rib.mdl"
local SPINE = "models/Gibs/HGIBS_spine.mdl"
-- Always spilled: the skull, a rib and a spine. Then a few more picked from BONES.
local ALWAYS = { SKULL, RIB, SPINE }
local BONES = { RIB, RIB, SPINE, "models/Gibs/HGIBS_scapula.mdl" }
local BONE_MIN, BONE_MAX = 1, 2 -- extra bones on top of ALWAYS
local BONE_LIFE = 120 -- seconds a spilled bone stays before it is cleaned up

-- A bone touching the egg feeds it: the egg draws it in and takes this many seconds off its gestation.
local FEED = 30
local SWALLOW = 0.3 -- seconds the bone takes to sink into the shell
local SWALLOW_SCALE = 0.2 -- how small it has shrunk by the time it is gone
local FEEDS = {
	["models/gibs/hgibs.mdl"] = true,
	["models/gibs/hgibs_rib.mdl"] = true,
	["models/gibs/hgibs_scapula.mdl"] = true,
	["models/gibs/hgibs_spine.mdl"] = true,
}

-- An ellipsoid the size of the scaled melon. Model physics do not scale with SetModelScale, so it
-- gets its own convex hull, which also rolls like a melon where a box would tip end over end.
local function Hull()
	local pts = { Vector(0, 0, EGG_HALF.z), Vector(0, 0, -EGG_HALF.z) }
	for i = 1, HULL_RINGS do
		local lat = math.pi * (i / (HULL_RINGS + 1) - 0.5)
		local c, s = math.cos(lat), math.sin(lat)
		for k = 0, HULL_SIDES - 1 do
			local a = k / HULL_SIDES * math.pi * 2
			pts[#pts + 1] = Vector(EGG_HALF.x * c * math.cos(a), EGG_HALF.y * c * math.sin(a), EGG_HALF.z * s)
		end
	end
	return pts
end

function ENT:Initialize()
	self:SetModel(self.EGG_MODEL)
	self:SetModelScale(self.EGG_SCALE, 0)
	self:PhysicsInitConvex(Hull())
	-- The convex hull drives the rolling, but players and bullets trace against a box from the bounds. With
	-- SOLID_VPHYSICS those traces go through the physics collision model, which is the part this egg kept
	-- slipping through; the bounds only count for collision when the solid type is SOLID_BBOX. Clearing the
	-- solid flags first drops anything left over from the trigger and custom-trace setup this used to have.
	self:SetSolidFlags(0)
	self:SetCollisionBounds(-EGG_HALF, EGG_HALF)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_BBOX)
	self:SetHealth(EGG_HEALTH)
	self:SetMaxHealth(EGG_HEALTH)
	self:SetSaveValue("m_takedamage", 2)

	local normal = self.SpawnNormal or Vector(0, 0, 1)
	if normal:LengthSqr() < 1e-4 then normal = Vector(0, 0, 1) end
	normal = normal:GetNormalized()
	self.LaidNormal = normal

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(EGG_MASS)
		phys:SetMaterial(SHELL_MATERIAL)
		if normal.z < GLUE_DOT then
			self.Glued = true
			phys:EnableMotion(false)
		else
			phys:Wake()
		end
	end

	if not IsValid(self.Layer) then self.Layer = nil end
	local time = math.max(1, EvilSnake.Setting("egg_time"))
	self.HatchAt = CurTime() + time
	self.HatchTries = 0
	self:SetNW2Float("EggHatchIn", time)
end

-- Placed from the spawn menu: on whatever was aimed at, lying flat on it and turned to face the
-- player. Initialize glues it in place when that is a wall or ceiling, the same as a laid egg.
function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end
	local normal = tr.HitNormal
	local fwd = ply:GetAimVector()
	fwd = fwd - normal * fwd:Dot(normal)
	if fwd:LengthSqr() < 1e-4 then fwd = normal:Angle():Up() end
	fwd:Normalize()
	local ent = ents.Create(class)
	if not IsValid(ent) then return end
	ent:SetPos(tr.HitPos + normal * (EGG_HALF.z + 1))
	ent:SetAngles(fwd:AngleEx(normal))
	ent.SpawnNormal = normal
	ent:Spawn()
	ent:Activate()
	ent:SetOwner(ply)
	ent.NoDuplicate = true
	undo.Create("evil_snake_egg")
	undo.AddEntity(ent)
	undo.SetPlayer(ply)
	ply:AddCleanup("props", ent)
	return ent
end

-- Draws a bone in: it stops colliding, slides to the egg's middle while shrinking, then is gone.
local function Swallow(egg, bone)
	local phys = bone:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(false) end
	bone:SetNotSolid(true)
	local from, start = bone:GetPos(), CurTime()
	local id = "EvilSnakeEggSwallow" .. bone:EntIndex()
	timer.Create(id, 0, 0, function()
		if not IsValid(bone) then timer.Remove(id) return end
		local t = IsValid(egg) and math.min(1, (CurTime() - start) / SWALLOW) or 1
		if IsValid(egg) then
			bone:SetPos(LerpVector(t, from, egg:WorldSpaceCenter()))
			bone:SetModelScale(Lerp(t, 1, SWALLOW_SCALE), 0)
		end
		if t >= 1 then
			timer.Remove(id)
			bone:Remove()
		end
	end)
end

-- A bone that touches it gets taken into the egg and brings the hatch closer.
function ENT:Feed(bone)
	if not IsValid(bone) or bone.EvilEggFed then return end
	if not FEEDS[string.lower(bone:GetModel() or "")] then return end
	bone.EvilEggFed = true
	self.HatchAt = self.HatchAt - FEED
	self:SetNW2Float("EggHatchIn", math.max(0, self.HatchAt - CurTime()))
	self:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav", 65, math.Rand(90, 110))
	-- Changing a prop's collisions is not allowed inside the collision callback, so wait a tick.
	timer.Simple(0, function()
		if IsValid(bone) then Swallow(self, bone) end
	end)
end

-- Off the wall and into the world as a loose prop.
function ENT:Unglue()
	if not self.Glued then return end
	self.Glued = false
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(true)
		phys:Wake()
		-- A little shove off the surface so it drops instead of sliding down the wall.
		phys:SetVelocity(self.LaidNormal * DROP_PUSH)
	end
end

-- Snakes crawl about their own eggs without knocking them down.
local function Snake(ent)
	return ent.EvilHitboxOwner ~= nil or ent:GetClass() == "evil_snake"
end

-- Stuck to a wall or ceiling the egg stays an ordinary solid prop: it blocks players and shots, and
-- a frozen prop gets no collision callback from either, so it looks for whatever is pressed against
-- it instead. It used to be a trigger to hear the bump, and that is exactly why players walked
-- through it and bullets passed through the shell without ever touching it.
local REACH = 8
local function Edible(ent)
	local model = ent:GetModel()
	return model ~= nil and FEEDS[string.lower(model)] == true
end

function ENT:Contact()
	local c = self:WorldSpaceCenter()
	for _, ent in ipairs(ents.FindInSphere(c, EGG_HALF.x + REACH)) do
		if IsValid(ent) and ent ~= self and not ent:IsWorld() and ent:GetMoveType() ~= MOVETYPE_NONE
			and ent:GetClass() ~= "evil_snake_egg" then
			if Edible(ent) then
				self:Feed(ent)
			elseif not Snake(ent) then
				-- Coming loose changes a frozen object's motion, which is best left out of the sweep.
				timer.Simple(0, function() if IsValid(self) then self:Unglue() end end)
				return
			end
		end
	end
end

function ENT:Think()
	if not self.Broken and not self.Hatched and CurTime() >= self.HatchAt then self:Hatch() end
	if self.Glued then self:Contact() end
	self:NextThink(CurTime() + 0.25)
	return true
end

function ENT:OnTakeDamage(dmg)
	if self.Broken or self.Hatched then return end
	self:Unglue()
	self:EmitSound(KNOCK .. math.random(1, 4) .. ".wav", 65, math.Rand(95, 110))
	self:TakePhysicsDamage(dmg)
	self:SetHealth(self:Health() - dmg:GetDamage())
	if self:Health() <= 0 then self:Break() end
	return dmg
end

function ENT:PhysicsCollide(data)
	if self.Broken or self.Hatched then return end
	self:Feed(data.HitEntity)
	-- A prop or anything else thrown at it knocks it loose. Motion cannot change inside this callback.
	if self.Glued and IsValid(data.HitEntity) and not Snake(data.HitEntity) then
		timer.Simple(0, function() if IsValid(self) then self:Unglue() end end)
	end
	local speed = data.Speed
	if speed >= BREAK_SPEED then
		-- Breaking spawns props, which the physics engine does not allow inside a collision callback.
		timer.Simple(0, function() if IsValid(self) then self:Break() end end)
	elseif speed >= HURT_SPEED then
		self:SetHealth(self:Health() - (speed - HURT_SPEED) / (BREAK_SPEED - HURT_SPEED) * EGG_HEALTH)
		if self:Health() <= 0 then
			timer.Simple(0, function() if IsValid(self) then self:Break() end end)
			return
		end
		self:EmitSound(KNOCK .. math.random(1, 4) .. ".wav", 65, math.Rand(95, 110))
	end
end

-- Grabbing it with either gun pulls it off whatever it was stuck to.
function ENT:GravGunPickupAllowed() self:Unglue() return true end
function ENT:GravGunPunt() self:Unglue() return true end

-- One bone flung out of the shell. Plain props with no timer on them: they stay until cleaned up.
local function Bone(model, pos, vel)
	local bone = ents.Create("prop_physics")
	if not IsValid(bone) then return end
	bone:SetModel(model)
	bone:SetPos(pos)
	bone:SetAngles(AngleRand())
	bone:Spawn()
	bone:Activate()
	local phys = bone:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:SetVelocity(vel)
		phys:AddAngleVelocity(VectorRand() * 300)
	end
	SafeRemoveEntityDelayed(bone, BONE_LIFE)
end

-- What was growing inside: a small snake, already dead. Die() leaves it lying as a corpse and
-- removes it after the snake's corpse time, the same as a snake killed in a fight.
function ENT:Stillborn(pos, up)
	local dead = ents.Create("evil_snake")
	if not IsValid(dead) then return end
	dead:SetPos(pos + up * 4)
	dead:SetAngles(Angle(0, math.Rand(0, 360), 0))
	dead.EggScale = STILLBORN_SIZE
	dead.EggCoil = true
	dead.Stillborn = true
	dead:Spawn()
	dead:Activate()
	timer.Simple(0, function()
		if IsValid(dead) and dead.Die and not dead.Dead then dead:Die(DamageInfo()) end
	end)
end

function ENT:Break()
	if self.Broken or self.Hatched then return end
	self.Broken = true
	local pos = self:WorldSpaceCenter()
	local up = self.Glued and self.LaidNormal or Vector(0, 0, 1)
	local fx = EffectData()
	fx:SetOrigin(pos)
	fx:SetNormal(up)
	fx:SetColor(BLOOD_COLOR_YELLOW)
	util.Effect("BloodImpact", fx)
	self:EmitSound("physics/flesh/flesh_bloody_break.wav", 75, math.Rand(90, 110))

	-- Out of the way first, so nothing spawned below starts inside the shell.
	self:SetNotSolid(true)
	self:SetNoDraw(true)

	local models = { unpack(ALWAYS) }
	for _ = 1, math.random(BONE_MIN, BONE_MAX) do models[#models + 1] = BONES[math.random(#BONES)] end
	for _, model in ipairs(models) do
		local out = (VectorRand() + up):GetNormalized()
		Bone(model, pos + out * EGG_THICK * 0.3, out * math.Rand(80, 180))
	end
	-- On the floor under the egg, curled up where it lay.
	self:Stillborn(self.Glued and pos + up * 4 or self:GetPos(), up)
	SafeRemoveEntity(self)
end

function ENT:Hatch()
	if self.Broken or self.Hatched then return end
	-- Too many snakes about: stay an egg and check again shortly. Waiting here does not use up
	-- the boxed-in tries below.
	if EvilSnake.AtCap() then
		self.HatchAt = CurTime() + HATCH_RETRY
		return
	end
	-- Still glued: hatch out the way it was laid. Loose: out of the top, wherever it ended up.
	local normal = self.Glued and self.LaidNormal or Vector(0, 0, 1)
	local at = self:GetPos() + normal * (EGG_THICK * 0.5 + 12)
	local room = util.TraceHull({
		start = at, endpos = at,
		mins = Vector(-12, -12, -12), maxs = Vector(12, 12, 12),
		mask = MASK_SOLID_BRUSHONLY,
	})
	if room.StartSolid then
		-- Boxed in. Wait a little in case it gets moved, then come out where it lies regardless.
		self.HatchTries = self.HatchTries + 1
		if self.HatchTries < HATCH_FORCE then
			self.HatchAt = CurTime() + HATCH_RETRY
			return
		end
		at = self:WorldSpaceCenter()
	end
	local snake = ents.Create("evil_snake")
	if not IsValid(snake) then
		self.HatchAt = CurTime() + HATCH_RETRY
		return
	end
	self.Hatched = true
	self:SetNotSolid(true)
	-- Loose on the floor it comes out curled up right where the egg lay.
	snake:SetPos(self.Glued and at or self:GetPos())
	snake:SetAngles(Angle(0, math.Rand(0, 360), 0))
	snake.EggCoil = true
	snake:Spawn()
	snake:Activate()
	local owner = self:GetOwner()
	if IsValid(owner) then
		snake:SetOwner(owner)
		owner:AddCleanup("npcs", snake)
	end
	self:EmitSound("npc/barnacle/barnacle_tongue_pull1.wav", 70, 85)
	SafeRemoveEntity(self)
end

-- The physics gun pulls it loose too. Allowed or not is left to whoever else answers the hook.
hook.Add("PhysgunPickup", "EvilSnakeEggUnglue", function(_, ent)
	if IsValid(ent) and ent:GetClass() == "evil_snake_egg" then ent:Unglue() end
end)
