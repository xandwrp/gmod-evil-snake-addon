EvilSnake = EvilSnake or {}
local Eyes = {}
EvilSnake.Eyes = Eyes

local sqrt, sin, cos, min, exp = math.sqrt, math.sin, math.cos, math.min, math.exp

local STALK = 1.05
local STALK_R = 0.1
local STALK_TIP = 0.055
local SEGS = 7
local SIDES = 6
local BALL = 0.25
local BALL_RINGS = 10
local BALL_SIDES = 12
local SPRING = 240
local DAMP = 6
local LEAN = 0.9
local UPRIGHT = 1.2
local ALERT_UPRIGHT = 0.7
local ALERT_REACH = 1.15
local KICK = 70
local JITTER = 6
local SACCADE = 16
local GLANCE = { 0.5, 2.2 }
local STARE = 500
local STEP = 1 / 60
local SCLERA = { 235, 215, 120 }
local IRIS = { 215, 95, 20 }
local PUPIL = { 8, 6, 6 }
local PUPIL_W = 0.22
local PUPIL_H = 0.6
local IRIS_AT = 0.55

local cube
local verts, vr, vg, vb = {}, {}, {}, {}

local function Point(k, x, y, z, r, g, b, nx, ny, nz)
	local v = verts[k]
	if not v then
		v = Vector()
		verts[k] = v
	end
	v:SetUnpacked(x, y, z)
	local l = EvilSnake.Bright(cube, 0, nx, ny, nz)
	vr[k], vg[k], vb[k] = min(255, r * l), min(255, g * l), min(255, b * l)
end

local function Vert(k)
	mesh.Position(verts[k])
	mesh.TexCoord(0, 0, 0)
	mesh.Color(vr[k], vg[k], vb[k], 255)
	mesh.AdvanceVertex()
end

local function Grid(rows, cols)
	local stride = cols + 1
	mesh.Begin(MATERIAL_QUADS, rows * cols)
	for i = 0, rows - 1 do
		local o0, o1 = i * stride + 1, (i + 1) * stride + 1
		for q = 0, cols - 1 do
			Vert(o0 + q)
			Vert(o0 + q + 1)
			Vert(o1 + q + 1)
			Vert(o1 + q)
		end
	end
	mesh.End()
end

local function Want(e, base, now, look, head)
	if look then
		if not e.alert then
			e.alert = true
			e.vel = e.vel + VectorRand() * KICK
		end
		if now >= e.next then
			e.next = now + math.Rand(0.15, 0.5)
			e.jit = VectorRand() * JITTER
		end
		return look + e.jit
	end
	e.alert = false
	if now >= e.next then
		e.next = now + math.Rand(GLANCE[1], GLANCE[2])
		e.vel = e.vel + VectorRand() * KICK * 0.5
		local ply = LocalPlayer()
		if IsValid(ply) and ply:Alive() and ply:EyePos():DistToSqr(base) < STARE * STARE and math.random() < 0.5 then
			e.ent, e.aim = ply, nil
		else
			e.ent = nil
			e.aim = head.p + head.f * math.Rand(60, 260) + head.r * math.Rand(-220, 220) + head.u * math.Rand(-20, 90)
		end
	end
	if IsValid(e.ent) then return e.ent:EyePos() end
	return e.aim or base + head.f * 100
end

local function Simulate(e, base, up, want, L, dt)
	local to = want - base
	to:Normalize()
	local aim = up * (e.alert and ALERT_UPRIGHT or UPRIGHT) + to * LEAN
	aim:Normalize()
	local rest = base + aim * (L * (e.alert and ALERT_REACH or 1))
	if not e.tip then e.tip, e.vel, e.look = rest, Vector(), Vector(to) end
	local steps = math.ceil(dt / STEP)
	local h = steps > 0 and dt / steps or 0
	for _ = 1, steps do
		e.vel = e.vel + ((rest - e.tip) * (SPRING * e.k) - e.vel * DAMP) * h
		e.tip = e.tip + e.vel * h
	end
	local d = e.tip - base
	local len = d:Length()
	if len > 1e-3 then e.tip = base + d * (math.Clamp(len, L * 0.7, L * 1.25) / len) end
	local lv = want - e.tip
	lv:Normalize()
	e.look = LerpVector(1 - exp(-dt * SACCADE * e.k), e.look, lv)
	e.look:Normalize()
end

local function Stalk(base, up, tip, side, W, cr, cg, cb)
	local L = (tip - base):Length()
	local ctrl = base + up * (L * 0.55)
	local tr = EvilSnake.Trig(SIDES)
	for i = 0, SEGS do
		local t = i / SEGS
		local a, b = (1 - t) * (1 - t), 2 * (1 - t) * t
		local c = t * t
		local p = base * a + ctrl * b + tip * c
		local tan = (ctrl - base) * (2 * (1 - t)) + (tip - ctrl) * (2 * t)
		tan:Normalize()
		local n1 = side - tan * side:Dot(tan)
		n1:Normalize()
		local n2 = tan:Cross(n1)
		local r = W * Lerp(t, STALK_R, STALK_TIP) * (i % 2 == 1 and 1.18 or 1)
		local shade = i % 2 == 1 and 0.85 or 1
		local sr, sg, sb = cr * shade, cg * shade, cb * shade
		local px, py, pz = p:Unpack()
		local ax, ay, az = n1:Unpack()
		local bx, by, bz = n2:Unpack()
		local o = i * (SIDES + 1) + 1
		for q = 0, SIDES do
			local cs, sn = tr.c[q], tr.s[q]
			local nx, ny, nz = ax * cs + bx * sn, ay * cs + by * sn, az * cs + bz * sn
			Point(o + q, px + nx * r, py + ny * r, pz + nz * r, sr, sg, sb, nx, ny, nz)
		end
	end
	Grid(SEGS, SIDES)
	local tan = tip - ctrl
	tan:Normalize()
	return tan
end

local function Ball(center, look, r)
	local lx, ly, lz = look:Unpack()
	local rx, ry, rz = ly, -lx, 0
	if rx * rx + ry * ry < 1e-4 then rx, ry, rz = 0, lz, -ly end
	local rl = sqrt(rx * rx + ry * ry + rz * rz)
	rx, ry, rz = rx / rl, ry / rl, rz / rl
	local ux, uy, uz = ry * lz - rz * ly, rz * lx - rx * lz, rx * ly - ry * lx
	local ox, oy, oz = center:Unpack()
	local tr = EvilSnake.Trig(BALL_SIDES)
	for i = 0, BALL_RINGS do
		local lat = (i / BALL_RINGS - 0.5) * math.pi
		local f, cl = sin(lat), cos(lat)
		local o = i * (BALL_SIDES + 1) + 1
		for q = 0, BALL_SIDES do
			local s, u = tr.c[q] * cl, tr.s[q] * cl
			local nx, ny, nz = lx * f + rx * s + ux * u, ly * f + ry * s + uy * u, lz * f + rz * s + uz * u
			local col = SCLERA
			if f > 0.3 then
				local pupil = (s / PUPIL_W) ^ 2 + (u / PUPIL_H) ^ 2
				if pupil < 1 then
					col = PUPIL
				elseif f > IRIS_AT then
					col = IRIS
				end
			end
			Point(o + q, ox + nx * r, oy + ny * r, oz + nz * r, col[1], col[2], col[3], nx, ny, nz)
		end
	end
	Grid(BALL_RINGS, BALL_SIDES)
end

function Eyes.Draw(state, light, stalks, head, W, look, cr, cg, cb)
	cube = light
	local now = RealTime()
	local dt = math.Clamp(now - (state.t or now), 0, 0.1)
	state.t = now
	local L = W * STALK
	for i, s in ipairs(stalks) do
		local e = state[i]
		if not e then
			e = { vel = Vector(), next = 0, k = 1 + (i - 1.5) * 0.3, jit = Vector() }
			state[i] = e
		end
		if state.dead then e.alert = false end
		local want = state.dead and s.base + head.f * 100 - head.u * 150 or Want(e, s.base, now, look, head)
		Simulate(e, s.base, s.up, want, L, dt)
		local tan = Stalk(s.base, s.up, e.tip, s.side, W, cr * 0.9, cg * 0.9, cb * 0.9)
		Ball(e.tip + tan * (W * BALL * 0.6), e.look, W * BALL)
	end
end
