if SERVER then resource.AddWorkshop("3823740816") end
if not file.Exists("evil_api/init.lua", "LUA") then
	EvilNeedsAPI = EvilNeedsAPI or {}
	EvilNeedsAPI[#EvilNeedsAPI + 1] = "Evil snake"
	if #EvilNeedsAPI > 1 then return end

	local API = "3823740816"
	local URL = "https://steamcommunity.com/sharedfiles/filedetails/?id=" .. API
	local RED = Color(255, 90, 90)

	local function Needs()
		return table.concat(EvilNeedsAPI, ", ") .. (#EvilNeedsAPI > 1 and " need" or " needs") .. " Syhgma's Evil API now."
	end

	hook.Add("Initialize", "EvilNeedsAPI", function()
		local fix = SERVER and game.IsDedicated() and "Add it to the server's workshop collection, then restart." or "Subscribe to it, then restart the game."
		MsgC(RED, Needs() .. " " .. fix .. " " .. URL .. "\n")
	end)
	if SERVER then return end

	local function Fix()
		if not game.SinglePlayer() and not LocalPlayer():IsListenServerHost() then return end
		for _, addon in ipairs(engine.GetAddons()) do
			if tostring(addon.wsid) == API then
				if not addon.downloaded then return "Steam is still downloading it, restart the game once it's done." end
				if not addon.mounted then return "It's turned off, turn it on in the Addons menu, then restart the game." end
				return "It's installed but didn't load. Unsubscribe and subscribe to it again, then restart the game."
			end
		end
		return "Subscribe to it, then restart the game."
	end

	hook.Add("InitPostEntity", "EvilNeedsAPI", function()
		local fix = Fix()
		if not fix then
			chat.AddText(RED, Needs() .. " This server doesn't have it, the server owner needs to add it to the server's workshop collection.")
			return
		end
		chat.AddText(RED, Needs() .. " " .. fix)

		local frame = vgui.Create("DFrame")
		frame:SetTitle("Syhgma's Evil API")
		frame:SetSize(420, 140)
		frame:Center()
		frame:MakePopup()

		local open = vgui.Create("DButton", frame)
		open:Dock(BOTTOM)
		open:SetTall(30)
		open:SetText("Open it on the Workshop")
		function open:DoClick()
			if steamworks and steamworks.ViewFile then
				steamworks.ViewFile(API)
			else
				gui.OpenURL(URL)
			end
		end

		local text = vgui.Create("DLabel", frame)
		text:Dock(FILL)
		text:DockMargin(4, 4, 4, 8)
		text:SetWrap(true)
		text:SetText(Needs() .. " " .. fix)
	end)
	return
end
include("evil_api/init.lua")

AddCSLuaFile("evil_snake/sh_settings.lua")
AddCSLuaFile("evil_snake/sh_body.lua")
AddCSLuaFile("evil_snake/sh_stomach.lua")
AddCSLuaFile("evil_snake/cl_util.lua")
AddCSLuaFile("evil_snake/cl_skin.lua")
AddCSLuaFile("evil_snake/cl_eyes.lua")
AddCSLuaFile("evil_snake/cl_head.lua")
AddCSLuaFile("evil_snake/cl_body.lua")
AddCSLuaFile("evil_snake/cl_stomach.lua")
AddCSLuaFile("evil_snake/cl_tongue.lua")
AddCSLuaFile("evil_snake/cl_inside.lua")
AddCSLuaFile("evil_snake/cl_thrash.lua")
AddCSLuaFile("evil_snake/cl_propellor.lua")
include("evil_snake/sh_settings.lua")
include("evil_snake/sh_body.lua")
include("evil_snake/sh_stomach.lua")
if SERVER then
	-- A combine ball bounces off evil_hitbox without the engine ever dealing
	-- damage to it, so a head hit never reaches the snake's OnTakeDamage. Watch
	-- the balls and sweep each one's path against the head hitbox part instead.
	local BALL = "prop_combine_ball"
	local SNAKE = "evil_snake"
	local balls = {}
	local snakes = 0

	local function Radius(ball)
		return math.Clamp(ball:BoundingRadius(), 4, 48)
	end

	local function Head(ball, from, to, parts)
		local delta, reach = to - from, Radius(ball)
		for _, part in ipairs(parts) do
			local snake = part.EvilHitboxOwner
			if part.EvilIndex == 1 and IsValid(snake) and snake:GetClass() == "evil_snake" then
				local s = (part.EvilSize or 0) + reach
				local box = Vector(s, s, s)
				if delta:LengthSqr() > 1e-6 then
					if util.IntersectRayWithOBB(from, delta, part:GetPos(), part:GetAngles(), -box, box) then
						return snake, part
					end
				elseif from:DistToSqr(part:GetPos()) <= s * s then
					return snake, part
				end
			end
		end
	end

	hook.Add("OnEntityCreated", "EvilSnakeCombineBall", function(ent)
		local class = ent:GetClass()
		if class == BALL then
			balls[ent] = false
		elseif class == SNAKE then
			snakes = snakes + 1
		end
	end)

	hook.Add("EntityRemoved", "EvilSnakeCombineBall", function(ent)
		if ent:GetClass() == SNAKE then snakes = math.max(snakes - 1, 0) end
	end)

	hook.Add("InitPostEntity", "EvilSnakeCombineBall", function()
		for _, ent in ipairs(ents.FindByClass(BALL)) do balls[ent] = false end
		snakes = #ents.FindByClass(SNAKE)
	end)

	hook.Add("Think", "EvilSnakeCombineBall", function()
		-- Nothing to sweep against: no balls in flight, or no snakes to hit.
		if not next(balls) or snakes <= 0 then return end
		local parts
		for ball, last in pairs(balls) do
			if not IsValid(ball) then
				balls[ball] = nil
			else
				local now = ball:GetPos()
				parts = parts or ents.FindByClass("evil_hitbox")
				local snake, part = Head(ball, last or now, now, parts)
				if snake and not ball.EvilSnakeHit then snake:BallHit(ball, part:GetPos()) end
				balls[ball] = now
			end
		end
	end)

	resource.AddFile("materials/killicons/evil_snake.png")
	include("evil_snake/sv_chain.lua")
	include("evil_snake/sv_path.lua")
	include("evil_snake/sv_brain.lua")
	include("evil_snake/sv_stomach.lua")
	include("evil_snake/sv_tongue.lua")
	include("evil_snake/sv_fungus.lua")
	include("evil_snake/sv_propellor.lua")
	include("evil_snake/sv_debug.lua")
	include("evil_snake/sv_enemy.lua")
else
	include("evil_snake/cl_util.lua")
	include("evil_snake/cl_skin.lua")
	include("evil_snake/cl_eyes.lua")
	include("evil_snake/cl_head.lua")
	include("evil_snake/cl_body.lua")
	include("evil_snake/cl_tongue.lua")
	include("evil_snake/cl_stomach.lua")
	include("evil_snake/cl_inside.lua")
	include("evil_snake/cl_thrash.lua")
	include("evil_snake/cl_propellor.lua")
end
