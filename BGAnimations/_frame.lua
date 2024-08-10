local t = Def.ActorFrame {}
local topFrameHeight = SCREEN_BOTTOM
local bottomFrameHeight = 54
local borderWidth = 4

--Frames

t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(502, 0):halign(0):valign(0):zoomto(SCREEN_WIDTH / 2, topFrameHeight):diffuse(color("0,0,0,0")):diffusetopedge(getMainColor("positive"), 0.1):diffusealpha(0.15)
	end
}


t[#t + 1] = UIElements.QuadButton(1, 1) .. {
	InitCommand = function(self)
		self:xy(0, SCREEN_HEIGHT):halign(0):valign(1):zoomto(SCREEN_WIDTH, bottomFrameHeight):diffuse(getMainColor("frames")):diffusealpha(0.7)
	end
}


--[[
if themeConfig:get_data().global.TipType == 2 or themeConfig:get_data().global.TipType == 3 then
	t[#t + 1] =
		LoadFont("Common Normal") ..
		{
			InitCommand = function(self)
				self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 7):zoom(0.35):settext(
					getRandomQuotes(themeConfig:get_data().global.TipType)
				):diffuse(getMainColor("highlight")):diffusealpha(0):zoomy(0):maxwidth((SCREEN_WIDTH - 350) / 0.35)
			end,
			BeginCommand = function(self)
				self:sleep(2)
				self:smooth(1)
				self:diffusealpha(1)
				self:zoomy(0.35)
			end
		}
end
]]

return t
