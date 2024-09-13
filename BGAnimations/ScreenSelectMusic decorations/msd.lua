--Local vars
local update = false
local steps
local song
local frameX = 10
local frameY = 40
local frameWidth = SCREEN_WIDTH * 0.56
local frameHeight = 368
local fontScale = 0.4
local distY = 15
local offsetX = 10
local offsetY = 20
local pn = GAMESTATE:GetEnabledPlayers()[1]
local greatest = 0
local txtDist = 29
local steps
local meter = {}
meter[1] = 0.00

local cd -- chord density graph

local translated_text = {
	AverageNPS = THEME:GetString("TabMSD", "AverageNPS"),
	NegBPM = THEME:GetString("TabMSD", "NegativeBPM"),
	Title = THEME:GetString("TabMSD", "Title")
}


--Actor Frame
local t = Def.ActorFrame {
	Name = "MSDTab",
	BeginCommand = function(self)
		cd = self:GetChild("ChordDensityGraph")
		cd:xy(frameX + offsetX, frameY + 122):visible(false)
		self:queuecommand("Set"):visible(false)
	end,
	OffCommand = function(self)
		self:bouncebegin(0.2):xy(0, 500):diffusealpha(0)
		self:sleep(0.04):queuecommand("Invis")
	end,
	InvisCommand= function(self)
		self:visible(false)
	end,
	OnCommand = function(self)
		self:bouncebegin(0.2):xy(0, 0):diffusealpha(1)
	end,
	SetCommand = function(self)
		self:finishtweening()
		if getTabIndex() == 1 then
			self:queuecommand("On")
			self:visible(true)
			song = GAMESTATE:GetCurrentSong()
			steps = GAMESTATE:GetCurrentSteps()

			--Find max MSD value, store MSD values in meter[]
			-- I plan to have c++ store the highest msd value as a separate variable to aid in the filter process so this won't be needed afterwards - mina
			greatest = 0
			if song and steps then
				for i = 1, #ms.SkillSets do
					meter[i + 1] = steps:GetMSD(getCurRateValue(), i)
					if meter[i + 1] > meter[greatest + 1] then
						greatest = i
					end
				end
			end

			if song and steps then
				cd:visible(true)
				cd:queuecommand("GraphUpdate")
				MESSAGEMAN:Broadcast("SetSteps",{steps = steps})
			else
				cd:visible(false)
			end
			update = true
		else
			self:queuecommand("Off")
			cd:visible(false)
			update = false
		end
	end,
	CurrentRateChangedMessageCommand = function(self)
		self:playcommand("Set")
	end,
	CurrentStepsChangedMessageCommand = function(self)
		if getTabIndex() == 1 then
			self:queuecommand("Set")
		end
	end,
	TabChangedMessageCommand = function(self)
		self:queuecommand("Set")
	end,
}

--BG quad
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(frameX, frameY):zoomto(frameWidth, frameHeight):halign(0):valign(0):diffuse(getMainColor("tabs"))
	end
}



--Tab Title Frame
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(frameX, frameY):zoomto(frameWidth, offsetY):halign(0):valign(0):diffuse(getMainColor("frames"))
		self:diffusealpha(0.5)
	end
}
--Tab Title
t[#t + 1] = LoadFont("Common Bold") .. {
	InitCommand = function(self)
		self:xy(frameX + offsetX/2, frameY + offsetY - 11):zoom(0.4):halign(0)
		self:settextf("%s (Calc v%s)",translated_text["Title"], GetCalcVersion())
	end
}
--Song Title
t[#t + 1] = LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(frameX + offsetX, frameY + 35):zoom(0.45):halign(0):diffuse(getMainColor("positive"))
		self:maxwidth(SCREEN_CENTER_X / 0.5)
		self:diffusetopedge(Saturation(getMainColor("highlight"), 0.2))
		self:diffusebottomedge(Saturation(getMainColor("positive"), 0.3))
	end,
	SetCommand = function(self)
		if song then
			self:settext(song:GetDisplayMainTitle())
		else
			self:settext("")
		end
	end
}

--Author Title
t[#t + 1] = LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(frameX + offsetX, frameY + 53):zoom(0.2):halign(0):diffuse(getMainColor("positive"))
		self:maxwidth(SCREEN_CENTER_X / 0.5)
		self:diffusetopedge(Saturation(getMainColor("highlight"), 0.2))
		self:diffusebottomedge(Saturation(getMainColor("positive"), 0.3))
	end,
	SetCommand = function(self)
		if song then
			self:settext("Made by: " .. song:GetOrTryAtLeastToGetSimfileAuthor())
		else
			self:settext("")
		end
	end
}

-- Music Rate Display
t[#t + 1] = LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(frameX + capWideScale(290,310), frameY + 123):visible(true):align(1,0):zoom(0.3)
	end,
	SetCommand = function(self)
		if steps then
			self:settext(getCurRateDisplayString(true))
		else
			self:settext("")
		end
	end
}

--Difficulty
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "StepsAndMeter",
	InitCommand = function(self)
		self:xy(frameX + offsetX, frameY + offsetY + 46):zoom(0.5):halign(0):maxwidth(350)
	end,
	SetCommand = function(self)
		steps = GAMESTATE:GetCurrentSteps()
		if steps ~= nil then
			local diff = getDifficulty(steps:GetDifficulty())
			local stype = ToEnumShortString(steps:GetStepsType()):gsub("%_", " ")
			local meter = steps:GetMeter()
			if update then
				self:settext(stype .. " " .. diff .. " " .. meter)
				self:diffuse(getDifficultyColor(GetCustomDifficulty(steps:GetStepsType(), steps:GetDifficulty())))
			end
		else
			self:settext("")
		end
	end
}

--NPS
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "NPS",
	InitCommand = function(self)
		self:xy(frameX + offsetX + 175, frameY + offsetY + 47):zoom(0.45):halign(0)
	end,
	SetCommand = function(self)
		steps = GAMESTATE:GetCurrentSteps()
		--local song = GAMESTATE:GetCurrentSong()
		local notecount = 0
		local length = 1
		if steps ~= nil and song ~= nil and update then
			length = steps:GetLengthSeconds()
			if length == 0 then length = 1 end
			notecount = steps:GetRadarValues(pn):GetValue("RadarCategory_Notes")
			self:settextf("%0.2f %s", notecount / length, translated_text["AverageNPS"])
			self:diffuse(Saturation(getDifficultyColor(GetCustomDifficulty(steps:GetStepsType(), steps:GetDifficulty())), 0.3))
		else
			self:settext("")
		end
	end
}

-- cdtitle
t[#t + 1] = UIElements.SpriteButton(1, 1, nil) .. {
	InitCommand = function(self)
		self:xy(capWideScale(get43size(344), 364) + 50, capWideScale(get43size(350), 160))
		self:halign(0.5):valign(1)
	end,
	SetCommand = function(self)
		self:finishtweening()
		self.song = song
		if song then
			if song:HasCDTitle() then
				self:visible(true)
				self:Load(song:GetCDTitlePath()):bob():effectmagnitude(0,1,0):diffusealpha(1)
			else
				self:visible(true)
				self:Load(THEME:GetPathG("","cdtitle")):diffusealpha(0) --honestly i could just make it load whatever asset it had, but whatever
			end
		else
			self:visible(false)
		end
		local height = self:GetHeight()
		local width = self:GetWidth()

		if height >= 60 and width >= 75 then
			if height * (75 / 60) >= width then
				self:zoom(60 / height)
			else
				self:zoom(75 / width)
			end
		elseif height >= 60 then
			self:zoom(60 / height)
		elseif width >= 75 then
			self:zoom(75 / width)
		else
			self:zoom(1)
		end
		if isOver(self) then
			self:playcommand("ToolTip")
		end
	end,
	ToolTipCommand = function(self)
		if isOver(self) then
			if self.song and self:GetVisible() then 
				local auth = self.song:GetOrTryAtLeastToGetSimfileAuthor()
				if auth and #auth > 0 and auth ~= "Author Unknown" then
					TOOLTIP:SetText(auth)
					TOOLTIP:Show()
				else
					TOOLTIP:Hide()
				end
			else
				TOOLTIP:Hide()
			end
		end
	end,
	MouseOverCommand = function(self)
		self:playcommand("ToolTip")
	end,
	MouseOutCommand = function(self)
		TOOLTIP:Hide()
	end,
}


t[#t+1] = LoadActor("ssrbreakdown") .. {
	InitCommand = function(self)
		self:xy(capWideScale(135,160),280)
		self:delayedFadeIn(4)
	end
}

t[#t + 1] = LoadActor("../_chorddensitygraph.lua")

return t
