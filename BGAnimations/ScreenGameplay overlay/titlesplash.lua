local mods = {}

local translated_info = {
	InvalidMods = THEME:GetString("ScreenGameplay", "InvalidMods"),
	By = THEME:GetString("ScreenGameplay", "CreatedBy")
}

local bannerWidth = 256
local bannerHeight = 80
local borderWidth = 2
local shuri = 29

-- splashy thing when you first start a song
local t = Def.ActorFrame {
	Name = "Splashy",
	DootCommand = function(self)
		self:RemoveAllChildren()
	end,
	Def.Quad {
		Name = "DestroyMe",
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 37)
			self:zoomto(400, 58)
			self:diffuse(color("#000111"))
			self:scaletoclipped(SCREEN_WIDTH,bannerHeight + 5)
			self:fadeleft(0.4):faderight(0.4)
			self:diffusealpha(0)
		end,
		OnCommand = function(self)
			self:smooth(0.5):diffusealpha(0.5):sleep(1):smooth(0.3):smooth(0.4):diffusealpha(0)
		end
	},
	--Main Tittle
	LoadFont("Common Large") .. {
		Name = "DestroyMe2", 
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X - 140, SCREEN_CENTER_Y - 48)
			self:diffuse(color("#FFFF00"))
			self:horizalign(left)
			self:zoom(0.4)
			self:diffusealpha(0)
			self:maxwidth(SCREEN_WIDTH*1)
		end,
		BeginCommand = function(self)
			self:settext(GAMESTATE:GetCurrentSong():GetDisplayMainTitle())
		end,
		OnCommand = function(self)
			self:diffusealpha(0):addx(SCREEN_WIDTH*1):sleep(0.2):accelerate(0.4):diffusealpha(1):addx(-SCREEN_WIDTH*1):sleep(1.2):accelerate(0.1):addx(150):diffusealpha(0)
		end
	},
	--Subtitle
	LoadFont("Common Normal") .. {
		Name = "DestroyMe3",
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X - 140, SCREEN_CENTER_Y - 27)
			self:diffuse(color("#FFFF00"))
			self:horizalign(left)
			self:zoom(0.30)
			self:shadowlength(1)
			self:diffusealpha(0)
			self:maxwidth(SCREEN_WIDTH*1)
		end,
		BeginCommand = function(self)
			self:settext(GAMESTATE:GetCurrentSong():GetDisplaySubTitle())
		end,
		OnCommand = function(self)
			self:diffusealpha(0):addx(SCREEN_WIDTH*1):sleep(0.2):accelerate(0.4):diffusealpha(1):addx(-SCREEN_WIDTH*1):sleep(1.2):accelerate(0.1):addx(170):diffusealpha(0)
		end
	},
	--Artist
	LoadFont("Common Normal") .. {
		Name = "DestroyMe4",
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X - 140, SCREEN_CENTER_Y - 34.5)
			self:diffuse(color("#FFFF00"))
			self:horizalign(left)
			self:zoom(0.3)
			self:shadowlength(1)
			self:diffusealpha(0)
			self:maxwidth(SCREEN_WIDTH*1)
		end,
		BeginCommand = function(self)
			self:settext(GAMESTATE:GetCurrentSong():GetDisplayArtist())
		end,
		OnCommand = function(self)
			local time = 0.4
			if #mods > 0 then
				time = 2
			end
			self:diffusealpha(0):addx(SCREEN_WIDTH*1):sleep(0.2):accelerate(0.4):diffusealpha(1):addx(-SCREEN_WIDTH*1):sleep(1.2):accelerate(0.1):addx(160):diffusealpha(0)
		end,
		DootCommand = function(self)
			self:GetParent():queuecommand("Doot")
		end
	},
	--load banner
	Def.Sprite {
	CurrentSongChangedMessageCommand = function(self)
        local song = GAMESTATE:GetCurrentSong()
		if song then
		   local bnpath = song:GetBannerPath()
		   if not bnpath then
		    bnpath = THEME:GetPathG("Common", "fallback banner")
			end
			self:LoadBackground(bnpath)
			end
			--i have no idea why noire made it like that, ask him not me -ifwas
			self:scaletoclipped(bannerWidth, bannerHeight)
			self:x(SCREEN_LEFT+150)
			self:y(SCREEN_CENTER_Y - 40)
			self:diffusealpha(0)
			self:zoomtowidth(SCREEN_WIDTH*2)
			self:zoomtoheight(8/2)
			self:diffusealpha(1)
			self:accelerate(0.3)
			self:zoomtoheight(8/2)
			self:diffusealpha(1)
			self:accelerate(0.3)
			self:zoomtowidth(256)
			self:accelerate(0.2)
			self:zoomtoheight(80)
			self:sleep(0.6)
			self:smooth(0.7)
			self:linear(0.35)
			self:zoomy(0)
			self:zoomx(2)
			self:diffusealpha(0)
			end
	}, 
	LoadFont("Common Normal") .. {
		Name = "DestroyMe6",
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 15):zoom(0.3):diffusealpha(0)
		end,
		BeginCommand = function(self)
			local auth = GAMESTATE:GetCurrentSong():GetOrTryAtLeastToGetSimfileAuthor()
			self:settextf("%s: %s", translated_info["By"], auth)
		end,
		OnCommand = function(self)
			self:smooth(0.5):diffusealpha(1):sleep(1):smooth(0.3):smooth(0.4):diffusealpha(0)
		end
	},
	LoadFont("Common Normal") .. {
		Name = "DestroyMe5",
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):zoom(0.5):diffusealpha(0):valign(0)
		end,
		BeginCommand = function(self)
			mods = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions():GetInvalidatingMods()
			local translated = {}
			if #mods > 0 then
				for _,mod in ipairs(mods) do
					table.insert(translated, THEME:HasString("OptionNames", mod) and THEME:GetString("OptionNames", mod) or mod)
				end
				self:settextf("%s\n%s", translated_info["InvalidMods"], table.concat(translated, "\n"))
			end
		end,
		OnCommand = function(self)
			self:smooth(0.5):diffusealpha(1):sleep(1):smooth(0.3):smooth(0.4):smooth(2):diffusealpha(0)
		end
	}
}
return t
