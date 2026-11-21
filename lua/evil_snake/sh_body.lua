EvilSnake = EvilSnake or {}

EvilSnake.SEND = 1 / 15
EvilSnake.SPINUP = 1.5
EvilSnake.PACK = 16
EvilSnake.PACK_MAX = 32767
EvilSnake.HULL = 0.85

local STEP = 24
local DROP = 120
local TURN = 30
local TURNS = 6
local BOXED = 0.9

-- floor height under a point, keeping the last one when there is none
local function Floor(x, y, z, filter)
	local tr = util.TraceLine({
		start = Vector(x, y, z + STEP),
		endpos = Vector(x, y, z - DROP),
		mask = MASK_SOLID,
		filter = filter,
	})
	if tr.Hit and not tr.StartSolid then return tr.HitPos.z end
	return z
end

-- adds count joints behind the last one in joints, tracing each joint from
-- the one before and turning away from walls so no link goes through a solid.
-- once it picks a side it keeps turning that way so the body curls along the
-- wall instead of zigzagging. yaw is the way the body faces, toward the head
function EvilSnake.Trail(joints, yaw, count, link, lift, filter)
	local z = joints[#joints].z - lift
	local side = 1
	for _ = 1, count do
		local prev = joints[#joints]
		local placed, bestFrac, bestTo, bestZ, bestTurn
		for k = 0, TURNS * 2 do
			local turn = k == 0 and 0 or math.ceil(k / 2) * TURN * (k % 2 == 1 and side or -side)
			local to = prev - Angle(0, yaw + turn, 0):Forward() * link
			local tz = Floor(to.x, to.y, z, filter)
			-- trace level with the higher end so stepping up a stair is not a wall
			local h = math.max(prev.z, tz + lift)
			local tr = util.TraceLine({
				start = Vector(prev.x, prev.y, h),
				endpos = Vector(to.x, to.y, h),
				mask = MASK_SOLID,
				filter = filter,
			})
			if not tr.Hit then
				if turn ~= 0 then side = turn > 0 and 1 or -1 end
				yaw, z, placed = yaw + turn, tz, Vector(to.x, to.y, tz + lift)
				break
			end
			if not bestFrac or tr.Fraction > bestFrac then
				bestFrac, bestTo, bestZ, bestTurn = tr.Fraction, to, tz, turn
			end
		end
		-- boxed in on every side: go as far as the roomiest way allows and let
		-- the chain stretch it out once it starts moving
		if not placed then
			local p = LerpVector(bestFrac * BOXED, prev, bestTo)
			yaw = yaw + bestTurn
			if bestFrac > 0 then z = bestZ end
			placed = Vector(p.x, p.y, z + lift)
		end
		joints[#joints + 1] = placed
	end
	return joints
end

-- a body curled up flat around origin, the tail in the middle and the head on the outside,
-- the way a snake lies in its egg. nil when the floor there is too cramped or uneven for it
local COIL_GAP = 2.1 -- space between the turns, in body radii
function EvilSnake.Coil(origin, yaw, count, link, lift, filter)
	local gap = lift * COIL_GAP
	local spin = gap / (math.pi * 2)
	local z = Floor(origin.x, origin.y, origin.z, filter)
	local pts, a = {}, 0
	for i = 0, count do
		local r = gap * 0.6 + spin * a
		local dir = Angle(0, yaw + math.deg(a), 0):Forward()
		local x, y = origin.x + dir.x * r, origin.y + dir.y * r
		pts[i + 1] = Vector(x, y, Floor(x, y, z, filter) + lift)
		a = a + link / r
	end
	for i = 2, #pts do
		local p, q = pts[i - 1], pts[i]
		if math.abs(p.z - q.z) > lift then return end
		local h = math.max(p.z, q.z)
		local tr = util.TraceLine({
			start = Vector(p.x, p.y, h), endpos = Vector(q.x, q.y, h),
			mask = MASK_SOLID, filter = filter,
		})
		if tr.Hit then return end
	end
	-- the chain runs head first
	local joints = {}
	for i = #pts, 1, -1 do joints[#joints + 1] = pts[i] end
	return joints
end

-- lays a fresh body out behind the head, scale times the usual size. coiled tries to curl
-- it up around origin first, and lays it out straight when there is no room for that
function EvilSnake.Layout(origin, yaw, count, filter, scale, coiled)
	scale = scale or 1
	local lift = EvilSnake.Setting("radius") * scale
	local link = EvilSnake.Setting("segment_length") * scale
	if coiled then
		local joints = EvilSnake.Coil(origin, yaw, count, link, lift, filter)
		if joints then return joints end
	end
	local z = Floor(origin.x, origin.y, origin.z, filter)
	local joints = { Vector(origin.x, origin.y, z + lift) }
	return EvilSnake.Trail(joints, yaw, count, link, lift, filter)
end

function EvilSnake.Shape()
	local tail = math.Clamp(EvilSnake.Setting("tail_length"), 0.01, 1)
	return 1 / math.max(EvilSnake.Setting("head_size"), 1), tail
end

function EvilSnake.Profile(t, body, tail)
	local start = 1 - tail
	local s = start > 0 and 1 - math.min(t / start, 1) or 0
	local u = math.max(0, (t - start) / tail)
	return (body + (1 - body) * s * s) * (1 - u * u)
end

local GRAB_IN = 0.25
local PULL = 0.8
local PULL_DEEP = 0.7
local HALF = 0.45
local CREEP = 0.15
local DEEP = 1.15
local LIFT = 0.5
local UP = Vector(0, 0, 1)

local function Smooth(u)
	return u * u * (3 - 2 * u)
end

function EvilSnake.HoldLength(hold)
	return GRAB_IN + hold + PULL
end

function EvilSnake.Hold(t, hold)
	t = math.max(t, 0)
	if t < GRAB_IN then
		local u = Smooth(t / GRAB_IN)
		return HALF * u, 0, u
	end
	t = t - GRAB_IN
	if t < hold then return HALF + CREEP * t / hold, 0, 1 end
	local u = math.min((t - hold) / PULL, 1)
	return Lerp(Smooth(math.min(u / PULL_DEEP, 1)), HALF + CREEP, DEEP), Smooth(u), 1
end

function EvilSnake.HeadRadius(R)
	if EvilSnake.Setting("static_head") == 0 then return R end
	return math.min(R, EvilSnake.Setting("radius"))
end

function EvilSnake.HeadDrop(R)
	return (R - EvilSnake.HeadRadius(R)) * EvilSnake.HULL
end

function EvilSnake.HeadPoints(head, neck, R, up)
	local drop = EvilSnake.HeadDrop(R)
	if drop <= 0 then return head, neck end
	local down = (up or UP) * drop
	return head - down, neck - down
end

function EvilSnake.Gape(head, neck, surface)
	local f = head - neck
	f:Normalize()
	local up = f + (surface or UP) * LIFT
	up:Normalize()
	return f, up
end

function EvilSnake.HeldPlace(head, neck, depth, surface, length)
	local f, up = EvilSnake.Gape(head, neck, surface)
	local fwd = UP - up * UP:Dot(up)
	if fwd:LengthSqr() < 1e-4 then fwd = -f end
	fwd:Normalize()
	return head + up * (length - depth), fwd:AngleEx(-up), up, head
end

EvilSnake.TONGUE_IN, EvilSnake.TONGUE_OUT, EvilSnake.TONGUE_WRAP, EvilSnake.TONGUE_BACK = 0, 1, 2, 3
EvilSnake.TONGUE_BONE = "ValveBiped.Bip01_Spine2"
EvilSnake.TONGUE_OPEN = 0.25
