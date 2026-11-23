include("shared.lua")

-- The snake's egg is the same form as the crawler's: the spawn-menu PHX cannonball, here a little
-- larger and near-white. The shell is a plain material over vgui/white with the game's own cannon
-- bump map for relief, tinted here rather than shipped as an image. Being a model material
-- (VertexLitGeneric), map light and flashlights land on it on their own.
--
-- The cannonball's origin sits at the base of the ball, so the render bounds run up from it, matching
-- the physics hull built in the same model space in init.lua.
local HALF = ENT.EGG_HALF
local TINT = Vector(0.95, 0.96, 0.98) -- paper white, a touch cold

local Shell = CreateMaterial("evil_snake_egg_shell_tinted", "VertexLitGeneric", {
	["$basetexture"] = "vgui/white",
	["$bumpmap"] = "phoenix_storms/cannon_bump",
	["$model"] = 1,
	["$halflambert"] = 1,
})

local tinted
local function Tint()
	local key = TINT.x * 65536 + TINT.y * 256 + TINT.z
	if key == tinted then return end
	tinted = key
	Shell:SetVector("$color2", TINT)
end

function ENT:Initialize()
	self:SetRenderBounds(
		Vector(-HALF.x * 1.1, -HALF.y * 1.1, -2),
		Vector(HALF.x * 1.1, HALF.y * 1.1, HALF.z * 2.2)
	)
end

function ENT:Draw()
	Tint()
	render.MaterialOverride(Shell)
	self:DrawModel()
	render.MaterialOverride()
end
