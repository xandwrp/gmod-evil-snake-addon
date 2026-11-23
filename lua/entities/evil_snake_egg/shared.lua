-- The snake's egg: the crawler's egg, purple and half again as big. The HL2 watermelon at three
-- times its size, about 46 x 54 x 47. sv_eggs.lua in the snake keeps its own copy of the size for the nest checks.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Evil Snake Egg"
ENT.Category = "Syhgma's Evil Entities"
ENT.Spawnable = EvilSnake ~= nil
ENT.RenderGroup = RENDERGROUP_OPAQUE
-- Stops the spawn menu handing out a second one while the button is held. It is a table field the
-- spawn menu reads before spawning; setting ent.NoDuplicate on the instance afterwards does nothing.
ENT.DoNotDuplicate = true

ENT.EGG_MODEL = "models/props_junk/watermelon01.mdl"
ENT.EGG_SCALE = 3
ENT.EGG_HALF = Vector(7.70, 8.96, 7.83) * ENT.EGG_SCALE -- the model's hull, scaled
ENT.EGG_THICK = 48
