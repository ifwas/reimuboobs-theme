-- Various player and stage info, more text = fps drop so we should be sparing
-- i will try to remove some unnecesary stuff tho -ifwas
local profileP1 = GetPlayerOrMachineProfile(PLAYER_1)
local PlayerFrameX = 0
local PlayerFrameY = SCREEN_HEIGHT - 60
local bgalpha = PREFSMAN:GetPreference("BGBrightness")


local translated_info = {
	Judge = THEME:GetString("ScreenGameplay", "ScoringJudge"),
	profileName = THEME:GetString("GeneralInfo", "NoProfile"),
}

local t = Def.ActorFrame {
	Def.Quad {
		InitCommand = function(self)
			self:xy(0, SCREEN_HEIGHT):align(0,1):zoomto(150,61)
			self:diffuse(0,0,0,bgalpha*0.4)
		end,
	},
	Def.Quad {
		InitCommand = function(self)
			self:xy(150, SCREEN_HEIGHT):align(0,1):zoomto((SCREEN_WIDTH*.44)-150,18)
			self:diffuse(0,0,0,bgalpha*0.4)
			self:faderight(0.7)
		end,
	},
	Def.Sprite {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(PlayerFrameX, PlayerFrameY)
		end,
		BeginCommand = function(self)
			self:finishtweening()
			self:Load(getAvatarPath(PLAYER_1))
			self:zoomto(60, 60)
		end
	},
	LoadFont("Common Large") .. {
		InitCommand = function(self)
			self:xy(PlayerFrameX + 62, PlayerFrameY + 38):halign(0):zoom(0.45):maxwidth(100)
		end,
		SetCommand = function(self)
			local meter = GAMESTATE:GetCurrentSteps():GetMSD(getCurRateValue(), 1)
			self:settextf("%05.2f", meter)
			self:diffuse(byMSD(meter))
		end,
		DoneLoadingNextSongMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		CurrentRateChangedMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		PracticeModeReloadMessageCommand = function(self)
			self:queuecommand("Set")
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(PlayerFrameX + 62, PlayerFrameY + 55):halign(0):zoom(0.4):maxwidth(SCREEN_WIDTH * 0.8)
		end,
		BeginCommand = function(self)
			self:settext(getModifierTranslations(GAMESTATE:GetPlayerState():GetPlayerOptionsString("ModsLevel_Current")))
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(PlayerFrameX + 63, PlayerFrameY + 19):halign(0):zoom(0.45)
		end,
		BeginCommand = function(self)
			self:settextf("%s: %d", translated_info["Judge"], GetTimingDifficulty())
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(PlayerFrameX + 63, PlayerFrameY + 4):halign(0):zoom(0.45)
		end,
		BeginCommand = function(self)
			self:settextf(profileName)
		end
	}
}
return t
