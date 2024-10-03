local t = Def.ActorFrame {}


translated_info = {
	Title = THEME:GetString("ScreenEvaluation", "Title"),
	Replay = THEME:GetString("ScreenEvaluation", "ReplayTitle")
}


--Group folder name
local frameWidth = SCREEN_CENTER_X - capWideScale(get43size(150),20)
local frameHeight = 20
local frameX = SCREEN_WIDTH - 20
local frameY = 15

t[#t + 1] = LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(frameX, frameY + 10):halign(1):zoom(0.35):maxwidth((frameWidth) / 0.35)
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

--readded this bc the gradecounter breaks if the replay results text is not present
--thanks steffen
t[#t + 1] = LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(30, 32):halign(0):valign(1):zoom(0.35):diffuse(getMainColor("positive"))
		self:settext("")
	end,
	OnCommand = function(self)
		local title = translated_info["Title"]
		local ss = SCREENMAN:GetTopScreen():GetStageStats()
		if not ss:GetLivePlay() then title = translated_info["Replay"] end
		local gamename = GAMESTATE:GetCurrentGame():GetName():lower()
		if gamename ~= "dance" then
			title = gamename:gsub("^%l", string.upper) .. " " .. title
		end
		self:settextf("%s:", title)

		-- gradecounter logic
		-- only increment gradecounter on liveplay
		local liveplay = ss:GetLivePlay()
		if liveplay then
			local score = SCOREMAN:GetMostRecentScore()
			local wg = score:GetWifeGrade()
			if wg == "Grade_Tier01" or wg == "Grade_Tier02" or wg == "Grade_Tier03" or wg == "Grade_Tier04" then
				GRADECOUNTERSTORAGE:increment("AAAA")
			elseif wg == "Grade_Tier05" or wg == "Grade_Tier06" or wg == "Grade_Tier07" then
				GRADECOUNTERSTORAGE:increment("AAA")
			elseif wg == "Grade_Tier08" or wg == "Grade_Tier09" or wg == "Grade_Tier10" then
				GRADECOUNTERSTORAGE:increment("AA")
			elseif wg == "Grade_Tier11" or wg == "Grade_Tier12" or wg == "Grade_Tier13" then
				GRADECOUNTERSTORAGE:increment("A")
			end
		end
		-- gradecounter logic end
	end,
}

local bannersizemultiplier = 1.27
local BannerWidth = 220 * bannersizemultiplier-- 220
local BannerHeight = 77 * bannersizemultiplier    -- 77

--test banner overlay
t[#t + 1] = Def.Quad {
	Name = "Banner",
	OnCommand = function(self)
		self:x(SCREEN_CENTER_X + capWideScale(get43size(280),280)):y(70):valign(0) --308
		self:scaletoclipped(capWideScale(get43size(270), BannerWidth), capWideScale(get43size(94.5), BannerHeight)) -- 220, 77
		self:diffuse(getMainColor("frames"))
	end
}

--test banner overlay
t[#t + 1] = Def.Sprite {
	Name = "Banner",
	OnCommand = function(self)
		self:x(SCREEN_CENTER_X + capWideScale(get43size(280),280)):y(70):valign(0) --308
		self:scaletoclipped(capWideScale(get43size(270), BannerWidth), capWideScale(get43size(94.5), BannerHeight)) -- 220, 77
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



t[#t + 1] = LoadActor("../gradecounter")
t[#t + 1] = LoadActor("../_cursor")

return t

