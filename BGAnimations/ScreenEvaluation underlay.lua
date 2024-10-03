local enabled = PREFSMAN:GetPreference("ShowBackgrounds")
local brightness = 0.4
local t = Def.ActorFrame {}

if enabled then
	t[#t + 1] = Def.Sprite {
		OnCommand = function(self)
			if GAMESTATE:GetCurrentSong() and GAMESTATE:GetCurrentSong():GetBackgroundPath() then
				self:visible(true)
				self:LoadBackground(GAMESTATE:GetCurrentSong():GetBackgroundPath())
				self:scaletocover(0, 0, SCREEN_WIDTH, SCREEN_BOTTOM)
				self:diffusealpha(brightness)
			else
				self:visible(false)
			end
		end
	}

	t[#t + 1] = Def.Quad {
		OnCommand = function(self)
			self:diffuse(getMainColor("frames")):fadebottom(0.9)
			self:scaletocover(0, 0, SCREEN_WIDTH, SCREEN_BOTTOM)
			self:addy(-100)
		end
	}

	t[#t + 1] = Def.Quad {
		OnCommand = function(self)
			self:diffuse(getMainColor("positive")):fadetop(0.9)
			self:scaletocover(0, SCREEN_HEIGHT / 1.5, SCREEN_WIDTH, SCREEN_BOTTOM)
			self:addy(350)
			self:blend("BlendMode_Normal")
		end
	}
end

return t
