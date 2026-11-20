ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Evil snake"
ENT.Category = "Syhgma's Evil Entities"
ENT.Spawnable = EvilSnake ~= nil
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "Girth")
	self:NetworkVar("Float", 1, "Length")
	self:NetworkVar("Float", 2, "Slide")
	self:NetworkVar("Float", 3, "Digest")
	self:NetworkVar("Entity", 0, "Prey")
	self:NetworkVar("Bool", 0, "Dead")
	self:NetworkVar("Float", 4, "BodyScale")
end

-- How big this snake is against a normal one, thickness and segment length both. Only the
-- stillborn snake from a broken egg is smaller; everything else is 1.
function ENT:Scaled()
	local s = self:GetBodyScale()
	return s > 0 and s or 1
end

local WEIGHT = 14 * 14 * 28 * 17

function ENT:Radius()
	return EvilSnake.Setting("radius") * math.max(self:GetGirth(), 1) * self:Scaled()
end

function ENT:Weight()
	local r = self:Radius()
	return r * r * math.max(self:GetLength(), 1) * EvilSnake.Setting("segment_length") * self:Scaled() / WEIGHT
end
