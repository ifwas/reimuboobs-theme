local t = Def.ActorFrame {}
t[#t + 1] = LoadActor("../_xoon2")
t[#t + 1] = LoadActor("../_xoon3")

translated_info = {
	Title = THEME:GetString("ScreenEvaluation", "Title"),
	Replay = THEME:GetString("ScreenEvaluation", "ReplayTitle")
}


--Group folder name
local frameWidth = SCREEN_CENTER_X - 200
local frameHeight = 20
local frameX = 170
local frameY = 25 

t[#t + 1] = LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(frameX, frameY):halign(1):zoom(0.30):maxwidth((frameWidth - 40) / 0.35)
	end,
	BeginCommand = function(self)
		self:queuecommand("Set"):diffuse(getMainColor("positive"))
	end,
	SetCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		if song ~= nil then
			self:settext(song:GetGroupName())
		end
	end
}

--test banner overlay
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

t[#t + 1] = LoadActor("../_cursor")

return t
