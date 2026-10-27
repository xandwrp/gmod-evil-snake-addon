EvilSnake = EvilSnake or {}
local Chain = {}
EvilSnake.Chain = Chain

local Setting = EvilSnake.Setting

local BASE = 1 / 33
local DT = BASE
local MAX_STEPS = 4
local DAMP = 0.995
local HULL = EvilSnake.HULL
local REST = 0.02
local SETTLE = 1
local NAP = 1
local PROBE = 1
local FLOOR = 0.7
local TRAIL_GAP = 4
local REBASE = 2
local TIP = 0.15
local UP = Vector(0, 0, 1)
local SELF_ARC = 1.6
local SELF_MARGIN = 8
local SELF_STIFF = 0.8
local AIM = 3
local SPIN = 6
local SPIN_SPEED = 50
local SWAY_EASE = 3
local CLOSE = 0.5
local TURN_SLOW = 0.35
local PACE = 4
local CRAWL = 1
local MAX_BEND = 1.4
local WATER = bit.bor(CONTENTS_WATER, CONTENTS_SLIME)
local BUOY = 1.3
local WET_DAMP = 0.9
local DIVE = 0.8
local SURGE = 0.5
local RISE = 1
local FLOAT = 0.6
local HOVER = 0.9
local STICK = 1
local CLING_GRIP = 1
local HUG = 0.5
local UP_EASE = 4
local LOOK = 3
local NECK = 2
local DODGE = 1.5
local DODGE_HEIGHT = 1.5
local OPEN_LOOK = 6
local OPENINGS = 12
local BLOCKED = 0.25
local WET_EVERY = 3
local CONTACT_EVERY = 2
local ALWAYS = 6
local MAX_WAVES = 2
local MAX_SWING = 300
local STRIDE = 1
local MAX_SPLIT = 4
local KNOT_SHARE = 0.5
local KNOT_TIME = 2
local GHOST_TIME = 3
local FIRM_TIME = 1
local SQUEEZE_HULL = 16
local SQUEEZE_IN = 2
local SQUEEZE_OUT = 0.5
local TIGHT_EVERY = 0.25
local TIGHT_HOLD = 1.5
local TIGHT_CHECKS = 16
local TIGHT_LOOK = 2
local TIGHT_GAIN = 0.25
local TIGHT_MASK = bit.band(MASK_SOLID, bit.bnot(CONTENTS_MONSTER))
local PIVOT = 20
local PREFER = 0.35
local CALM_LOOK = 4
local CALM_HULL = 2
local ESCAPE = {
	Vector(0, 0, 1), Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0),
	Vector(0.7071, 0.7071, 0), Vector(0.7071, -0.7071, 0), Vector(-0.7071, 0.7071, 0), Vector(-0.7071, -0.7071, 0),
	Vector(0.7071, 0, 0.7071), Vector(-0.7071, 0, 0.7071), Vector(0, 0.7071, 0.7071), Vector(0, -0.7071, 0.7071),
}

local folds = {}

local function Size(c)
	local r = Setting("radius") * c.girth * HULL
	local body, tail = EvilSnake.Shape()
	local n = #c.x
	for i = 1, n do
		local h = r * math.max(EvilSnake.Profile((i - 1) / math.max(n - 1, 1), body, tail), TIP)
		if c.squeeze > 0 then h = Lerp(c.squeeze, h, math.min(h, SQUEEZE_HULL)) end
		local grow = h - (c.hull[i] or h)
		if grow > 0 then
			local normal = c.cn[i]
			local lift = UP * grow
			if normal then
				local reach = math.abs(normal.x) + math.abs(normal.y) + math.abs(normal.z)
				lift = normal.z >= 0.3 and UP * (grow * reach / normal.z) or normal * (grow * reach)
				c.cd[i] = c.cd[i] + grow * reach
			end
			c.x[i] = c.x[i] + lift
			c.old[i] = c.old[i] + lift
		end
		c.hull[i] = h
	end
	for i = n + 1, #c.hull do c.hull[i] = nil end
end

function Chain.New(joints, filter)
	local c = {
		x = {}, old = {}, p = {}, cn = {}, cd = {}, filter = filter, awake = true, still = 0, acc = 0, nap = 0,
		mins = Vector(), maxs = Vector(), hull = {}, trail = {}, arcs = {}, speed = 0, phase = 0, girth = 1, stretch = 1, wet = {},
		up = Vector(0, 0, 1), walls = 0, ceilings = 0, climb = 1, letgo = 0, tick = 0,
		ghost = 0, knot = 0, firm = 1, squeeze = 0, squeezing = 0, back = 0, backSpeed = 0, calm = 1,
	}
	c.trace = { mins = c.mins, maxs = c.maxs, mask = MASK_SOLID, filter = filter }
	for i, j in ipairs(joints) do c.x[i], c.old[i] = Vector(j), Vector(j) end
	Size(c)
	return c
end

local function Wet(pos)
	return bit.band(util.PointContents(pos), WATER) ~= 0
end

local function Soak(c, i, pos)
	if not Wet(pos) then return 0 end
	return Wet(pos + UP * (c.hull[i] / HULL * 0.5)) and 1 or 0.5
end

local function Clings(c, normal)
	if c.letgo > 0 then return 0 end
	if normal.z > -FLOOR then return c.walls end
	return c.ceilings
end

local function Steep(c, normal)
	return normal ~= nil and normal.z < FLOOR and Clings(c, normal) > 0
end

local function Hold(c, normal)
	return normal and normal.z < FLOOR and Clings(c, normal) or 0
end

local function Hull(c, i, from, to)
	local r = c.hull[i]
	c.mins:SetUnpacked(-r, -r, -r)
	c.maxs:SetUnpacked(r, r, r)
	local q = c.trace
	q.start, q.endpos = from, to
	return util.TraceHull(q)
end

function Chain.Link(c)
	return Setting("segment_length") * c.stretch
end

function Chain.HeadYaw(c)
	local d = c.x[1] - c.x[2]
	return math.deg(math.atan2(d.y, d.x))
end

function Chain.Drive(c, yaw, speed, aim)
	c.goal, c.want, c.aim = yaw, speed, aim
	if speed > 0 then c.awake, c.still = true, 0 end
end

function Chain.LetGo(c, seconds)
	c.letgo = math.max(c.letgo, seconds)
	c.awake, c.still = true, 0
end

function Chain.Ghost(c, seconds)
	c.ghost, c.knot, c.firm = math.max(c.ghost, seconds), 0, 0
	c.awake, c.still = true, 0
end

function Chain.Squeeze(c, seconds)
	c.squeezing = math.max(c.squeezing, seconds)
	c.awake, c.still = true, 0
end

function Chain.Back(c, seconds, speed)
	c.back, c.backSpeed = math.max(c.back, seconds), speed
	c.speed, c.driving = 0, false
	c.awake, c.still = true, 0
end

function Chain.Limp(c, seconds)
	Chain.LetGo(c, seconds)
	c.speed, c.want, c.aim, c.driving, c.back = 0, 0, nil, false, 0
end

function Chain.Pin(c, i, pos)
	c.pinned = i
	c.pinnedAt = c.pinnedAt or Vector()
	c.pinnedAt:Set(pos)
	c.awake, c.still = true, 0
end

function Chain.Unpin(c)
	c.pinned = nil
	c.awake, c.still = true, 0
end

function Chain.Kick(c, i, vel)
	c.old[i] = c.old[i] - vel * (c.dt or BASE)
	if vel.z > 0 then c.cn[i], c.cd[i] = nil, nil end
	c.awake, c.still = true, 0
end

function Chain.Surface(c)
	local normal = c.cn[1]
	if not normal then return end
	if normal.z >= FLOOR then return "floor" end
	return normal.z > -FLOOR and "wall" or "ceiling"
end

function Chain.Swell(c, girth)
	c.girth = girth
	Size(c)
	c.awake, c.still = true, 0
end

local function Reseed(c)
	local x, trail, arcs = c.x, {}, {}
	local n = #x
	local arc = 0
	for k = 1, n do
		local p = x[n - k + 1]
		if k > 1 then arc = arc + p:Distance(trail[k - 1]) end
		trail[k], arcs[k] = Vector(p), arc
	end
	c.trail, c.arcs = trail, arcs
end

local function Resize(c, count)
	local x, old = c.x, c.old
	while #x > count + 1 do
		local n = #x
		x[n], old[n], c.cn[n], c.cd[n] = nil, nil, nil, nil
	end
	while #x < count + 1 do
		local n = #x
		local dir = n > 1 and (x[n] - x[n - 1]):GetNormalized() or Vector(1, 0, 0)
		Size(c)
		local tr = Hull(c, n, x[n], x[n] + dir * Chain.Link(c))
		x[n + 1], old[n + 1] = Vector(tr.HitPos), Vector(tr.HitPos)
	end
	Size(c)
	Reseed(c)
	c.awake, c.still = true, 0
end

function Chain.Fit(c, length)
	local count = math.max(1, math.Round(length))
	c.stretch = length / count
	if #c.x ~= count + 1 then Resize(c, count) end
end

local function Record(c, head)
	local trail, arcs = c.trail, c.arcs
	local last = #trail
	local gap = head:Distance(trail[last])
	if gap < TRAIL_GAP then return end
	trail[last + 1], arcs[last + 1] = Vector(head), arcs[last] + gap
	local keep = arcs[last + 1] - (#c.x + 2) * Chain.Link(c)
	while #arcs > 2 and arcs[2] < keep do
		table.remove(trail, 1)
		table.remove(arcs, 1)
	end
end

local function Follow(c, p, amount)
	local trail, arcs = c.trail, c.arcs
	local last = #trail
	local link = Chain.Link(c)
	local head = arcs[last] + p[1]:Distance(trail[last])
	local k = last
	for i = 2, #p do
		local want = head - (i - 1) * link
		if want < arcs[1] then return false end
		local target
		if want >= arcs[last] then
			target = LerpVector((want - arcs[last]) / math.max(head - arcs[last], 1e-4), trail[last], p[1])
		else
			while k > 1 and arcs[k] > want do k = k - 1 end
			local span = arcs[k + 1] - arcs[k]
			target = LerpVector(span > 0 and (want - arcs[k]) / span or 0, trail[k], trail[k + 1])
		end
		if target:Distance(p[i]) > REBASE * link then return true end
		p[i] = LerpVector(amount, p[i], target)
	end
	return false
end

local function Grip(v, amount)
	local len = v:Length()
	if len <= amount then return v * 0 end
	return v * ((len - amount) / len)
end

local function Touch(c, i, pos, dir)
	local tr = Hull(c, i, pos, pos + dir * PROBE)
	if not tr.Hit or tr.StartSolid or not (tr.HitNormal.z > 0 or Clings(c, tr.HitNormal) > 0) then return false end
	if tr.HitNormal.z < FLOOR and (tr.HitSky or tr.HitNoDraw) then return false end
	c.cn[i], c.cd[i] = tr.HitNormal, tr.HitPos:Dot(tr.HitNormal)
	return true
end

local function Contact(c, i, pos, hit, ahead)
	local prev, lead = c.cn[i], i > 1 and c.cn[i - 1] or nil
	if ahead and (c.walls > 0 or c.ceilings > 0) and Touch(c, i, pos, ahead) then return end
	if i == 1 and hit and Touch(c, i, pos, hit.z >= FLOOR and -UP or -hit) then return end
	if i == 1 and Steep(c, prev) and Touch(c, i, pos, -prev) then return end
	if Touch(c, i, pos, -UP) then return end
	if Steep(c, prev) and Touch(c, i, pos, -prev) then return end
	if Steep(c, lead) and Touch(c, i, pos, -lead) then return end
	if hit and Steep(c, hit) and Touch(c, i, pos, -hit) then return end
	c.cn[i], c.cd[i] = nil, nil
end

local function Over(c, i, pos, wall, move)
	local reach = c.hull[i] * 2 + PROBE
	local across = Hull(c, i, pos, pos - wall * reach)
	if across.StartSolid then return end
	local down = Hull(c, i, across.HitPos, across.HitPos - UP * reach)
	if not down.StartSolid and down.Hit and down.HitNormal.z >= FLOOR then return down.HitPos end
	local side = move - wall * move:Dot(wall)
	side.z = 0
	if side:LengthSqr() < 1e-4 then return end
	side:Normalize()
	local back = Hull(c, i, across.HitPos, across.HitPos - side * reach)
	if back.StartSolid or not back.Hit then return end
	return back.HitPos, -back.HitNormal
end

local function Turn(c, from, to)
	local a = math.NormalizeAngle(math.deg(math.atan2(to.y, to.x) - math.atan2(from.y, from.x)))
	if c.yaw then c.yaw = c.yaw + a end
	if c.goal then c.goal = c.goal + a end
	c.aim = nil
	c.turned = (c.turned or 0) + a
end

local function Surface(c, normal, step)
	local into = step:Dot(normal)
	local d = step - normal * into
	if normal.z > -FLOOR then
		local up = UP - normal * normal.z
		up:Normalize()
		d = d + up * (math.abs(into) * c.climb)
	end
	local len = d:Length()
	if len > 1e-4 then d = d * (step:Length() / len) end
	return d
end

local function Unstick(c, i, pos)
	if not Hull(c, i, pos, pos).StartSolid then return pos end
	local reach = c.hull[i] * 2 + 1
	local best, bestDist
	for _, dir in ipairs(ESCAPE) do
		local tr = Hull(c, i, pos + dir * reach, pos)
		if tr.Hit and not tr.StartSolid then
			local d = tr.HitPos:DistToSqr(pos)
			if not bestDist or d < bestDist then best, bestDist = tr.HitPos, d end
		end
	end
	return best
end

local function Climb(c, i, from, to, reached)
	local height = Setting("step_height")
	if height <= 0 then return end
	height = height + Setting("radius") * c.girth
	local flat = Vector(to.x - from.x, to.y - from.y, 0)
	if flat:Length() < 1e-3 then return end
	local top = Hull(c, i, from, from + UP * height).HitPos
	local over = Hull(c, i, top, top + flat)
	if over.StartSolid then return end
	local land = over.HitPos
	local done = Vector(land.x - from.x, land.y - from.y, 0):Length()
	local slid = Vector(reached.x - from.x, reached.y - from.y, 0):Length()
	if done <= slid + 0.5 then return end
	local down = Hull(c, i, land, land - UP * (top.z - from.z + PROBE))
	if down.StartSolid or not down.Hit or down.HitNormal.z < FLOOR then return end
	return down.HitPos
end

local function Collide(c, i, from, to, along, gravity)
	local normal = c.cn[i]
	local ahead
	if i == 1 then
		ahead = to - from
		if normal then ahead = ahead - normal * ahead:Dot(normal) end
		ahead = ahead:LengthSqr() > 1e-4 and ahead:GetNormalized() or nil
	end
	if normal then
		local move = to - from
		local into = move:Dot(normal)
		local rest = move - normal * into
		local flat = (along - normal * along:Dot(normal)):GetNormalized()
		local slide = flat * rest:Dot(flat)
		local weight = gravity * DT * DT * math.max(normal.z, Hold(c, normal) * CLING_GRIP)
		rest = Grip(slide, c.gripAlong * weight) + Grip(rest - slide, c.gripSide * weight)
		to = from + rest + normal * math.max(into, math.min(0, c.cd[i] - from:Dot(normal)))
	end
	local tr = Hull(c, i, from, to)
	if tr.StartSolid then
		local free = Unstick(c, i, to) or Unstick(c, i, from) or from
		Contact(c, i, free)
		return free, false, free ~= to
	end
	local final, climbed, hit = to, false, nil
	if tr.Hit then
		hit = tr.HitNormal
		local rest = to - tr.HitPos
		rest = rest - tr.HitNormal * math.min(0, rest:Dot(tr.HitNormal))
		final = tr.HitPos
		if rest:LengthSqr() > 1e-6 then
			local tr2 = Hull(c, i, final, final + rest)
			if not tr2.StartSolid then final = tr2.HitPos end
		end
		if tr.HitNormal.z < FLOOR then
			local stepped = Climb(c, i, from, to, final)
			if stepped then final, climbed, hit = stepped, true, nil end
		end
	end
	if not hit and not climbed and i > ALWAYS and normal and normal.z >= FLOOR and (c.tick + i) % CONTACT_EVERY ~= 0 then
		return final, false
	end
	Contact(c, i, final, hit, ahead)
	if not c.cn[i] and Steep(c, normal) and normal.z > -FLOOR then
		local top, grab = Over(c, i, final, normal, final - from)
		if top then
			if not (grab and Touch(c, i, top, grab)) then Contact(c, i, top) end
			local now = c.cn[i]
			if i == 1 and grab and now and now.z < FLOOR and now.z > -FLOOR then Turn(c, normal, now) end
			return top, false, true
		end
	end
	return final, climbed
end

local function Dodge(c)
	local x, hull = c.x, c.hull
	local head = x[1]
	local r = hull[1] / HULL
	local link = Chain.Link(c)
	local yaw = math.rad(c.yaw)
	local fx, fy = math.cos(yaw), math.sin(yaw)
	local px, py = 0, 0
	for i = 3, #x do
		local ri = hull[i] / HULL
		local p = x[i]
		local dx, dy, dz = p.x - head.x, p.y - head.y, p.z - head.z
		if (i - 1) * link >= (r + ri) * NECK and math.abs(dz) < (r + ri) * DODGE_HEIGHT and dx * fx + dy * fy > 0 then
			local reach = r * LOOK + ri
			local d2 = dx * dx + dy * dy
			if d2 < reach * reach and d2 > 1e-4 then
				local d = math.sqrt(d2)
				local w = 1 - d / reach
				px, py = px - dx / d * w, py - dy / d * w
			end
		end
	end
	return px, py
end

function Chain.Opening(c, prefer)
	local x, hull = c.x, c.hull
	local head = x[1] + UP
	local r = hull[1] / HULL
	local len = r * OPEN_LOOK
	local base = math.Rand(0, 360)
	local best, bestScore
	for k = 0, OPENINGS - 1 do
		local yaw = base + k * 360 / OPENINGS
		local dir = Angle(0, yaw, 0):Forward()
		local tr = Hull(c, 1, head, head + dir * len)
		local score = tr.StartSolid and 0 or tr.Fraction
		if prefer then score = score + PREFER * math.cos(math.rad(yaw - prefer)) end
		for i = 3, #x do
			local d = x[i] - head
			local along = d:Dot(dir)
			if along > 0 and along < len and (d - dir * along):Length() < r + hull[i] / HULL then
				score = score - BLOCKED
			end
		end
		if not bestScore or score > bestScore then best, bestScore = yaw, score end
	end
	return best
end

local function Steer(c)
	local wave = math.max(Setting("wavelength"), c.speed / MAX_WAVES)
	local sway = math.min(Setting("sway"), MAX_SWING * wave / (2 * math.pi * math.max(c.speed, 1))) * c.calm
	local aim, dist = c.aim, nil
	if aim then
		local head = c.x[1]
		local dx, dy = aim.x - head.x, aim.y - head.y
		dist = math.max(math.sqrt(dx * dx + dy * dy), 1)
		c.goal = math.deg(math.atan2(dy, dx))
		sway = sway * math.Clamp(dist / wave - CLOSE, 0, 1)
	end
	c.sway = c.sway and c.sway + (sway - c.sway) * math.min(1, SWAY_EASE * DT) or sway
	if not c.driving then
		c.driving, c.spin = true, 0
		c.yaw = Chain.HeadYaw(c) - c.sway * math.sin(c.phase)
		Reseed(c)
	end
	local goal = c.goal
	local px, py = 0, 0
	if c.ghost <= 0 then px, py = Dodge(c) end
	if px ~= 0 or py ~= 0 then
		local g = math.rad(goal)
		goal = math.deg(math.atan2(math.sin(g) + py * DODGE, math.cos(g) + px * DODGE))
	end
	local turn = Setting("turn_rate") * (c.quick or 1)
	local diff = math.AngleDifference(goal, c.yaw)
	local want = diff * AIM
	if dist then
		local chase = math.deg(2 * math.sin(math.rad(diff)) * c.speed / dist)
		if math.abs(chase) > math.abs(want) then want = chase end
	end
	want = math.Clamp(want, -turn, turn)
	c.spin = c.spin + (want - c.spin) * math.min(1, (SPIN + c.speed / SPIN_SPEED) * DT)
	local turned = c.spin * DT
	if turned * diff > 0 and math.abs(turned) > math.abs(diff) then
		turned = diff
		c.spin = diff / DT
	end
	c.yaw = c.yaw + turned
	c.phase = (c.phase + c.speed * DT / wave * math.pi * 2) % (math.pi * 2)
	local heading = math.rad(c.yaw + c.sway * math.sin(c.phase))
	return Vector(math.cos(heading), math.sin(heading), 0) * (c.speed * DT)
end

local function CellKey(x, y, z)
	return (x + 2048) + (y + 2048) * 4096 + (z + 2048) * 16777216
end

local grid, sizes, used, pool, found = {}, {}, {}, {}, {}
local atx, aty, atz = {}, {}, {}
local midx, midy, midz, half = {}, {}, {}, {}

local function Nearby(c, p, n, link)
	local hull = c.hull
	local widest = 0
	for i = 1, n do widest = math.max(widest, hull[i]) end
	widest = widest / HULL
	local cell = link + widest * 2 + SELF_MARGIN
	for k = #used, 1, -1 do
		local key = used[k]
		grid[key], sizes[key], used[k] = nil, nil, nil
	end
	local cells = 0
	for s = 1, n - 1 do
		local ax, ay, az = p[s]:Unpack()
		local bx, by, bz = p[s + 1]:Unpack()
		local mx, my, mz = (ax + bx) * 0.5, (ay + by) * 0.5, (az + bz) * 0.5
		local ex, ey, ez = bx - ax, by - ay, bz - az
		midx[s], midy[s], midz[s] = mx, my, mz
		half[s] = math.sqrt(ex * ex + ey * ey + ez * ez) * 0.5
		local gx = math.floor(mx / cell)
		local gy = math.floor(my / cell)
		local gz = math.floor(mz / cell)
		atx[s], aty[s], atz[s] = gx, gy, gz
		local key = CellKey(gx, gy, gz)
		local size = sizes[key]
		if not size then
			cells = cells + 1
			local bucket = pool[cells]
			if not bucket then
				bucket = {}
				pool[cells] = bucket
			end
			grid[key], size = bucket, 0
			used[#used + 1] = key
		end
		size = size + 1
		grid[key][size], sizes[key] = s, size
	end
	local count = 0
	for s = 1, n - 1 do
		local gx, gy, gz = atx[s], aty[s], atz[s]
		local mx, my, mz, hs = midx[s], midy[s], midz[s], half[s]
		local rs = math.max(hull[s], hull[s + 1]) / HULL
		for dx = -1, 1 do
			for dy = -1, 1 do
				for dz = -1, 1 do
					local key = CellKey(gx + dx, gy + dy, gz + dz)
					local bucket = grid[key]
					if bucket then
						for k = 1, sizes[key] do
							local t = bucket[k]
							if t > s + 1 then
								local rt = math.max(hull[t], hull[t + 1]) / HULL
								if (t - s) * link >= (rs + rt) * SELF_ARC then
									local ex, ey, ez = midx[t] - mx, midy[t] - my, midz[t] - mz
									local reach = hs + half[t] + rs + rt + SELF_MARGIN
									if ex * ex + ey * ey + ez * ez < reach * reach then
										found[count + 1], found[count + 2] = s, t
										count = count + 2
									end
								end
							end
						end
					end
				end
			end
		end
	end
	for k = #found, count + 1, -1 do found[k] = nil end
	return found
end

local function Push(p, i, wx, wy, wz)
	local v = p[i]
	v:SetUnpacked(v.x + wx, v.y + wy, v.z + wz)
end

local function Pull(a, b, rest, pinned, apart, held)
	local ax, ay, az = a:Unpack()
	local bx, by, bz = b:Unpack()
	local dx, dy, dz = bx - ax, by - ay, bz - az
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	if len <= 1e-4 or apart and len >= rest then return end
	local k = (len - rest) / len * 0.5
	dx, dy, dz = dx * k, dy * k, dz * k
	if pinned then
		b:SetUnpacked(bx - dx * 2, by - dy * 2, bz - dz * 2)
	elseif held then
		a:SetUnpacked(ax + dx * 2, ay + dy * 2, az + dz * 2)
	else
		a:SetUnpacked(ax + dx, ay + dy, az + dz)
		b:SetUnpacked(bx - dx, by - dy, bz - dz)
	end
end

local function Separate(c, p, found)
	local hull = c.hull
	local stiff = SELF_STIFF * c.firm
	local touching = 0
	for k = 1, #found, 2 do
		local i, j = found[k], found[k + 1]
		local p1, q1, p2, q2 = p[i], p[i + 1], p[j], p[j + 1]
		local d1x, d1y, d1z = q1.x - p1.x, q1.y - p1.y, q1.z - p1.z
		local d2x, d2y, d2z = q2.x - p2.x, q2.y - p2.y, q2.z - p2.z
		local rx, ry, rz = p1.x - p2.x, p1.y - p2.y, p1.z - p2.z
		local a = d1x * d1x + d1y * d1y + d1z * d1z
		local e = d2x * d2x + d2y * d2y + d2z * d2z
		if a > 1e-6 and e > 1e-6 then
			local b = d1x * d2x + d1y * d2y + d1z * d2z
			local cc = d1x * rx + d1y * ry + d1z * rz
			local f = d2x * rx + d2y * ry + d2z * rz
			local denom = a * e - b * b
			local s = denom > 1e-6 and math.Clamp((b * f - cc * e) / denom, 0, 1) or 0
			local t = (b * s + f) / e
			if t < 0 then
				t, s = 0, math.Clamp(-cc / a, 0, 1)
			elseif t > 1 then
				t, s = 1, math.Clamp((b - cc) / a, 0, 1)
			end
			local nx = rx + d1x * s - d2x * t
			local ny = ry + d1y * s - d2y * t
			local nz = rz + d1z * s - d2z * t
			local dist = math.sqrt(nx * nx + ny * ny + nz * nz)
			local reach = (Lerp(s, hull[i], hull[i + 1]) + Lerp(t, hull[j], hull[j + 1])) / HULL
			if dist < reach then
				touching = touching + 1
				if dist > 1e-4 then
					nx, ny, nz = nx / dist, ny / dist, nz / dist
				else
					nx, ny, nz = 0, 0, 1
				end
				if i == 1 and nz > 0 then c.propped = true end
				local half = (reach - dist) * 0.5 * stiff
				local ks = half / ((1 - s) ^ 2 + s * s)
				local kt = half / ((1 - t) ^ 2 + t * t)
				Push(p, i, nx * ks * (1 - s), ny * ks * (1 - s), nz * ks * (1 - s))
				Push(p, i + 1, nx * ks * s, ny * ks * s, nz * ks * s)
				Push(p, j, -nx * kt * (1 - t), -ny * kt * (1 - t), -nz * kt * (1 - t))
				Push(p, j + 1, -nx * kt * t, -ny * kt * t, -nz * kt * t)
			end
		end
	end
	return touching
end

function Chain.Away(yaw, out)
	local h = Angle(0, yaw, 0):Forward()
	local d = h:Dot(out)
	if d >= 0 then return yaw end
	h = h - out * (2 * d)
	return math.deg(math.atan2(h.y, h.x))
end

local function Land(c, wall)
	local out = Vector(wall.x, wall.y, 0)
	out:Normalize()
	c.landed, c.aim = out, nil
	if c.yaw then c.yaw = Chain.Away(c.yaw, out) end
	if c.goal then c.goal = Chain.Away(c.goal, out) end
end

local function Reverse(c, p, n, d)
	local x, cn = c.x, c.cn
	for i = 1, n - 1 do
		local a, b, v = x[i], x[i + 1], p[i]
		local len = a:Distance(b)
		local t = len > 1e-4 and math.min(d / len, 1) or 0
		v:SetUnpacked(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t + math.min(0, v.z - a.z))
	end
	local tail, v = x[n], p[n]
	local dir = tail - x[n - 1]
	local normal = cn[n]
	if normal then dir = dir - normal * dir:Dot(normal) end
	local len = dir:Length()
	if len < 1e-4 then return end
	dir:Mul(d / len)
	v:SetUnpacked(tail.x + dir.x, tail.y + dir.y, tail.z + dir.z + math.min(0, v.z - tail.z))
end

local function Tick(c)
	local x, old, p, cn, cd = c.x, c.old, c.p, c.cn, c.cd
	local n = #x
	local link = Chain.Link(c)
	local curl = Setting("curl")
	for i = 1, n - 2 do
		local bend = math.min(link / math.max(curl * c.hull[i + 1] / HULL, 1e-3), MAX_BEND)
		folds[i] = 2 * link * math.cos(bend * 0.5)
	end
	local gravity = Setting("gravity")
	local fall = Vector(0, 0, -gravity * DT * DT)
	local wet = c.wet
	local stick = STICK * gravity * DT * DT
	local per = DT / BASE
	local damp, wetDamp, hover = DAMP ^ per, WET_DAMP ^ per, HOVER ^ per
	if c.letgo > 0 then c.letgo = math.max(0, c.letgo - DT) end
	if c.ghost > 0 then
		c.ghost = math.max(0, c.ghost - DT)
	elseif c.firm < 1 then
		c.firm = math.min(1, c.firm + DT / FIRM_TIME)
	end
	local fly = c.fly and c.letgo <= 0
	c.tick = c.tick + 1
	c.gripAlong, c.gripSide = Setting("grip_along"), Setting("grip_side")
	for i = 1, n do
		if i == 1 or not wet[i] or (c.tick + i) % WET_EVERY == 0 then wet[i] = Soak(c, i, x[i]) end
		local soak = wet[i]
		local pull = fall * (1 - BUOY * soak)
		local hold = Hold(c, cn[i])
		if hold > 0 then pull = pull * (1 - hold) - cn[i] * (stick * hold) end
		if fly then pull = pull * (i == 1 and 0 or 1 - FLOAT) end
		p[i] = x[i] + (x[i] - old[i]) * (fly and i == 1 and hover or soak > 0 and wetDamp or damp) + pull
	end
	local want = c.want or 0
	local back = c.back > 0 and not fly and not c.pinned
	if back then
		c.back = math.max(0, c.back - DT)
		want, c.speed = 0, 0
	elseif c.driving and c.goal then
		local diff = math.AngleDifference(c.goal, c.yaw)
		want = want * math.max(math.cos(math.rad(diff)), TURN_SLOW)
		if c.aim then
			local dx, dy = c.aim.x - x[1].x, c.aim.y - x[1].y
			local s = math.abs(diff) >= 90 and 1 or math.abs(math.sin(math.rad(diff)))
			if s > 1e-3 then
				local turn = math.rad(Setting("turn_rate") * (c.quick or 1))
				want = math.min(want, math.max(math.sqrt(dx * dx + dy * dy) / (2 * s) * turn, PIVOT))
			end
		end
	end
	c.speed = c.speed + (want - c.speed) * math.min(1, PACE * DT)
	if want <= 0 and c.speed < CRAWL then c.speed = 0 end
	local swim = not fly and wet[1] > 0 and (not cn[1] or wet[1] >= 1 and not (c.aim and c.aim.z < x[1].z))
	local propped = c.propped
	if back then
		Reverse(c, p, n, c.backSpeed * DT)
		c.driving = false
	elseif c.speed > 0 then
		local step = Steer(c)
		local hold = Hold(c, cn[1])
		if fly then
			local cap = c.speed * DT * RISE
			local to = x[1] + step
			if c.aim then
				local dx, dy = c.aim.x - x[1].x, c.aim.y - x[1].y
				local flat, len = math.sqrt(dx * dx + dy * dy), c.speed * DT
				if flat < len then to = x[1] + step * (flat / len) end
				to.z = x[1].z + math.Clamp(c.aim.z - x[1].z, -cap, cap)
			end
			p[1] = to
		elseif hold > 0 and not swim then
			p[1] = x[1] + Surface(c, cn[1], step) - cn[1] * HUG + fall * (1 - hold)
		elseif (cn[1] or propped) and not swim then
			p[1] = x[1] + step + Vector(0, 0, (x[1].z - old[1].z) * damp) + fall
		elseif swim then
			local cap = c.speed * DT * DIVE
			local to = x[1] + step * (1 + SURGE * math.cos(c.phase * 2))
			to.z = to.z + math.Clamp(c.aim and c.aim.z - x[1].z or cap, -cap, cap)
			if to.z > x[1].z and not Wet(to) then to.z = x[1].z end
			p[1] = to
		end
		Record(c, x[1])
		local follow = Setting("follow")
		if follow > 0 and Follow(c, p, 1 - (1 - follow) ^ (DT / BASE)) then Reseed(c) end
	else
		c.driving = false
	end
	local g = c.pinned and math.min(c.pinned, n)
	if g then p[g]:Set(c.pinnedAt) end
	local pin = not g and (fly or c.driving and (cn[1] ~= nil or propped or swim))
	local tail = back and not g and n or nil
	local found = c.ghost <= 0 and Setting("self_collide") ~= 0 and n > 3 and Nearby(c, p, n, link) or nil
	if found and #found == 0 then found = nil end
	c.propped = false
	local touching = 0
	for _ = 1, Setting("solver_passes") do
		for i = 1, n - 1 do
			Pull(p[i], p[i + 1], link, i == 1 and pin or i == g, false, i + 1 == g or i + 1 == tail)
		end
		for i = 1, n - 2 do
			Pull(p[i], p[i + 2], folds[i], i == 1 and pin or i == g, true, i + 2 == g or i + 2 == tail)
		end
		if found then touching = math.max(touching, Separate(c, p, found)) end
		for i = 1, n do
			local normal = cn[i]
			if normal then
				local v = p[i]
				local depth = v:Dot(normal) - cd[i]
				if depth < 0 then v:SetUnpacked(v.x - normal.x * depth, v.y - normal.y * depth, v.z - normal.z * depth) end
			end
		end
		if g then p[g]:Set(c.pinnedAt) end
	end
	if touching >= n * KNOT_SHARE then
		c.knot = c.knot + DT
		if c.knot >= KNOT_TIME then Chain.Ghost(c, GHOST_TIME) end
	elseif c.knot > 0 then
		c.knot = math.max(0, c.knot - DT)
	end
	local moved, slid = 0, 0
	local was = cn[1]
	for i = 1, n do
		local to, climbed, snapped
		local from = x[i]
		if i == g then
			to = Vector(c.pinnedAt)
			cn[i], cd[i] = nil, nil
		else
			local along = (p[math.min(i + 1, n)] - p[math.max(i - 1, 1)]):GetNormalized()
			to, climbed, snapped = Collide(c, i, x[i], p[i], along, gravity)
		end
		old[i], x[i] = snapped and Vector(to) or climbed and Vector(from.x, from.y, to.z) or from, to
		moved = math.max(moved, to:DistToSqr(from))
		if cn[i] then slid = slid + math.sqrt((to.x - old[i].x) ^ 2 + (to.y - old[i].y) ^ 2) end
	end
	if c.climb < 0 and was and cn[1] and was.z < FLOOR and was.z > -FLOOR and cn[1].z >= FLOOR then Land(c, was) end
	c.slide = slid / n / DT
	c.up = LerpVector(math.min(1, UP_EASE * DT), c.up, cn[1] or UP)
	c.up:Normalize()
	return moved
end

local function Split(c)
	local speed = c.back > 0 and math.max(c.speed, c.backSpeed) or c.speed
	local split = math.Clamp(math.ceil(speed * BASE / (Chain.Link(c) * STRIDE)), 1, MAX_SPLIT)
	local step = BASE / split
	local was = c.dt or BASE
	if step ~= was then
		local k = step / was
		local x, old = c.x, c.old
		for i = 1, #x do
			local a, b = x[i], old[i]
			b:SetUnpacked(a.x - (a.x - b.x) * k, a.y - (a.y - b.y) * k, a.z - (a.z - b.z) * k)
		end
	end
	c.dt = step
	DT = step
end

local function Fits(c, h, from, to)
	c.mins:SetUnpacked(-h, -h, -h)
	c.maxs:SetUnpacked(h, h, h)
	return util.TraceHull({ start = from, endpos = to, mins = c.mins, maxs = c.maxs, mask = TIGHT_MASK, filter = c.filter })
end

local function Tight(c)
	local r = Setting("radius") * c.girth * HULL
	if r <= SQUEEZE_HULL then return false end
	local x, cn, hull = c.x, c.cn, c.hull
	local n = #x
	local body, tail = EvilSnake.Shape()
	local stride = math.max(1, math.floor(n / TIGHT_CHECKS))
	for i = 1, n, stride do
		local h = r * math.max(EvilSnake.Profile((i - 1) / math.max(n - 1, 1), body, tail), TIP)
		if h > SQUEEZE_HULL then
			local at = cn[i] and x[i] + cn[i] * (h - hull[i]) or x[i]
			if Fits(c, h, at, at).StartSolid then return true end
		end
	end
	if not (c.driving and c.speed > 0 and cn[1] and cn[1].z >= FLOOR) then return false end
	local ahead = Angle(0, c.yaw, 0):Forward() * (Chain.Link(c) * TIGHT_LOOK)
	local head = x[1] + cn[1] * (r - hull[1])
	local full = Fits(c, r, head, head + ahead)
	if not full.Hit or full.StartSolid then return false end
	local thin = Fits(c, SQUEEZE_HULL, x[1], x[1] + ahead)
	return not thin.StartSolid and thin.Fraction > full.Fraction + TIGHT_GAIN
end

local function Calm(c)
	local normal = c.cn[1]
	if not (c.driving and c.speed > 0 and normal and normal.z >= FLOOR) then return 1 end
	local r = c.hull[1] / HULL
	local reach = r * CALM_LOOK
	local side = Angle(0, c.yaw + 90, 0):Forward() * reach
	local head = c.x[1]
	local gap = math.min(Fits(c, CALM_HULL, head, head + side).Fraction, Fits(c, CALM_HULL, head, head - side).Fraction) * reach
	return math.Clamp((gap - r) / r, 0, 1)
end

function Chain.Update(c, dt)
	if c.awake then
		c.tight = (c.tight or 0) - dt
		if c.tight <= 0 then
			c.tight = TIGHT_EVERY
			if Tight(c) then Chain.Squeeze(c, TIGHT_HOLD) end
			c.calm = Calm(c)
		end
	end
	if c.squeezing > 0 then c.squeezing = math.max(0, c.squeezing - dt) end
	local squeeze = c.squeezing > 0 and 1 or 0
	if c.squeeze ~= squeeze then
		c.squeeze = math.Approach(c.squeeze, squeeze, dt * (squeeze > c.squeeze and SQUEEZE_IN or SQUEEZE_OUT))
	end
	Size(c)
	Split(c)
	if not c.awake then
		c.slide = 0
		c.nap = c.nap + dt
		if c.nap < NAP then return false end
		c.nap = 0
		if Tick(c) < REST * REST then return false end
		c.awake, c.still = true, 0
		return true
	end
	c.acc = math.min(c.acc + dt, BASE * MAX_STEPS)
	local moved, stepped = 0, false
	while c.acc >= DT do
		c.acc = c.acc - DT
		moved = math.max(moved, Tick(c))
		stepped = true
	end
	if moved > REST * REST or c.speed > 0 or c.back > 0 then
		c.still = 0
	else
		c.still = c.still + dt
		if c.still > SETTLE then c.awake = false end
	end
	return stepped
end
