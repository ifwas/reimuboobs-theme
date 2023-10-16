local enabled = PREFSMAN:GetPreference("ShowBackgrounds")
local brightness = 0.4
local t = Def.ActorFrame {}

if enabled then
	t[#t + 1] = Def.Sprite {
		OnCommand = function(self)
			if GAMESTATE:GetCurrentSong() and GAMESTATE:GetCurrentSong():GetBackgroundPath() then
				self:finishtweening()
				self:visible(true)
				self:LoadBackground(GAMESTATE:GetCurrentSong():GetBackgroundPath())
				self:scaletocover(0, 0, SCREEN_WIDTH, SCREEN_BOTTOM)
				self:sleep(0.5)
				self:decelerate(2)
				self:diffusealpha(brightness)
			else
				self:visible(false)
			end
		end
	}
end

t[#t + 1] = Def.Sprite {
	Name = "Banner",
	OnCommand = function(self)
		self:x(SCREEN_CENTER_X - 308):y(36):valign(0)
		self:scaletoclipped(capWideScale(get43size(220), 220), capWideScale(get43size(77), 77))
		local bnpath = GAMESTATE:GetCurrentSong():GetBannerPath()
		self:visible(true)
		if not BannersEnabled() then
			self:visible(false)
		elseif not bnpath then
			bnpath = THEME:GetPathG("Common", "fallback banner")
		end
		self:LoadBackground(bnpath)
	end
}

return t
