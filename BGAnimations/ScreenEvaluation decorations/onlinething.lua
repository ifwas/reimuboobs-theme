---------------------------------------------------------------------------------------------
--scoretable related xy positions
local tzoom = 0.5
local rankx = 10
local ratex = rankx + 30
local ssrx = ratex + 35
local namex = ssrx + 30
local spreadx = namex + 90
local accx = 390
local datex = accx + 100
local scoreYgap = 20
---------------------------------------------------------------------------------------------
--scoretable related zoom values
local spreadzoom = 0.4
local datezoom = 0.4
---------------------------------------------------------------------------------------------
-- rank // rate // ssr // name // spread // acc // date--
---------------------------------------------------------------------------------------------
--scoretable update things
local ind = 0
local currentCountry = "Global"
local numscores = 7
local queso
local moving
local isGlobalRanking = true
local hoverAlpha = 0.6
local initialyScoreDisplay = 60
local steps = GAMESTATE:GetCurrentSteps()
local lightswitch = false
---------------------------------------------------------------------------------------------
--translated things
local filts = {
	THEME:GetString("NestedScores", "FilterAll"),
	THEME:GetString("NestedScores", "FilterCurrent")
}
local topornah = {
	THEME:GetString("NestedScores", "ScoresTop"),
	THEME:GetString("NestedScores", "ScoresAll")
}
local ccornah = {
	THEME:GetString("NestedScores", "ShowInvalid"),
	THEME:GetString("NestedScores", "HideInvalid")
}
local translated_info = {
	LoginToView = THEME:GetString("NestedScores", "LoginToView"),
	NoScoresFound = THEME:GetString("NestedScores", "NoScoresFound"),
	RetrievingScores = THEME:GetString("NestedScores", "RetrievingScores"),
	Watch = THEME:GetString("NestedScores", "WatchReplay")
}
---------------------------------------------------------------------------------------------
-- same logic as the superscoreboard, will eat any mousewheel inputs to scroll pages while mouse is over the background frame
local function input(event)
	if isOver(queso:GetChild("FrameDisplay")) then -- visibility checks are built into isover now -mina
		if event.DeviceInput.button == "DeviceButton_mousewheel up" and event.type == "InputEventType_FirstPress" then
			moving = true
			queso:queuecommand("PrevPage")
			return true
		elseif event.DeviceInput.button == "DeviceButton_mousewheel down" and event.type == "InputEventType_FirstPress" then
			queso:queuecommand("NextPage")
			return true
		elseif moving == true then
			moving = false
		end
	end
	return false
end


local scoretable = {}
local o = Def.ActorFrame{
    Name = "EvaluationScoreDisplay",
    InitCommand = function(self)
        queso = self
        self:x(-700)
        if steps then
			DLMAN:RequestChartLeaderBoardFromOnline(
				steps:GetChartKey(),
				function(leaderboard)
					self:queuecommand("SetFromLeaderboard", leaderboard)
				end
			)
		end
    end,
    BeginCommand = function(self)
        scoretable = DLMAN:GetChartLeaderBoard(GAMESTATE:GetCurrentSteps():GetChartKey(), currentCountry)
        SCREENMAN:GetTopScreen():AddInputCallback(input)
        self:playcommand("Update")
    end,
    GetFilteredLeaderboardCommand = function(self)
		if GAMESTATE:GetCurrentSong() then
			scoretable = DLMAN:GetChartLeaderBoard(GAMESTATE:GetCurrentSteps():GetChartKey(), currentCountry)
			ind = 0
			self:playcommand("Update")
		end
	end,
	SetFromLeaderboardCommand = function(self, lb)
		scoretable = lb
		ind = 0
		self:playcommand("GetFilteredLeaderboard") -- we can move all the filter stuff to lua so we're not being dumb hurr hur -mina
		self:playcommand("Update")
	end,
    UpdateCommand = function(self)
		if not scoretable then
			ind = 0
			return
		end
		if ind == #scoretable then
			ind = ind - numscores
		elseif ind > #scoretable - (#scoretable % numscores) then
			ind = #scoretable - (#scoretable % numscores)
		end
		if ind < 0 then
			ind = 0
		end
	end,
    NextPageCommand = function(self)
		ind = ind + numscores
		self:queuecommand("Update")
	end,
	PrevPageCommand = function(self)
		ind = ind - numscores
		self:queuecommand("Update")
	end,
    ChangingTabToScoreMessageCommand = function(self)
        self:bouncebegin(0.2):xy(0, 0):diffusealpha(1)
    end,
    ExitTabScoreMessageCommand = function(self)
        self:bouncebegin(0.2):xy(-700, 0):diffusealpha(0)
    end,
    UIElements.QuadButton(1, 1) .. {-- this is a nonfunctional button to mask buttons behind the window
		Name = "FrameDisplay",
		InitCommand = function(self)
			self:zoomto(505, 150):halign(0):valign(0):diffuse(getMainColor("tabs")):y(60)
		end,
	},
	UIElements.QuadButton(1, 1) .. {-- this is a nonfunctional button to mask buttons behind the window
		Name = "header",
		InitCommand = function(self)
			self:zoomto(222, 15):halign(0):valign(0):diffuse(getMainColor("frames")):y(45):diffusealpha(0.5)
		end,
	},
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		--current rate toggle
		InitCommand = function(self)
			self:xy(200, 57):zoom(tzoom):halign(1):valign(1)
			self:diffuse(getMainColor("positive"))
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		UpdateCommand = function(self)
			if DLMAN:GetCurrentRateFilter() then
				self:settext(filts[2])
			else
				self:settext(filts[1])
			end
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				DLMAN:ToggleRateFilter()
				ind = 0
				self:GetParent():queuecommand("GetFilteredLeaderboard")
			end
		end
	},
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		--top score/all score toggle
		InitCommand = function(self)
			self:diffuse(getMainColor("positive"))
			self:xy(70, 57):zoom(tzoom):halign(1):valign(1)
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		UpdateCommand = function(self)
			if DLMAN:GetTopScoresOnlyFilter() then
				self:settext(topornah[1])
			else
				self:settext(topornah[2])
			end
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				DLMAN:ToggleTopScoresOnlyFilter()
				ind = 0
				self:GetParent():queuecommand("GetFilteredLeaderboard")
			end
		end
	},
    LoadFont("Common normal") .. {
		-- informational text about online scores
		Name = "RequestStatus",
		InitCommand = function(self)
            self:xy(10,80):zoom(tzoom):halign(0)
		end,
		UpdateCommand = function(self)
			local numberofscores = scoretable ~= nil and #scoretable or 0
			local online = DLMAN:IsLoggedIn()
			if not GAMESTATE:GetCurrentSong() then
				self:settext("")
			elseif not online and scoretable ~= nil and #scoretable == 0 then
				self:settext(translated_info["LoginToView"])
			else
				if scoretable ~= nil and #scoretable == 0 then
					self:settext(translated_info["NoScoresFound"])
				elseif scoretable == nil then
					self:settext("Chart is not ranked")
				else
					self:settext("")
				end
			end
		end,
	},
}

local pleasework

local function makeScoreDisplay(i) --where the magic happens
	local hs

	local o = Def.ActorFrame {
		Name = "Scoredisplay_"..i,
		InitCommand = function(self)
			self:y(initialyScoreDisplay + (scoreYgap * i))
			if i > numscores or hs == nil then
				self:visible(false)
			else
				self:visible(true)
			end
		end,
		UpdateCommand = function(self)
			if scoretable ~= nil then
				hs = scoretable[(i + ind)]
			else
				hs = nil
			end
			if hs and i <= numscores then
				self:visible(true)
				self:playcommand("Display")
			else
				self:visible(false)
			end
		end,
		UIElements.QuadButton(1, 1) .. {-- this is a non functional button to mask buttons behind the box
			InitCommand = function(self)
				self:xy(0, -4):zoomto(500,19):halign(0)
			end,
			DisplayCommand = function(self)
				self:diffuse(color("#111111CC"))
				self:diffusealpha(0.8)
			end,
		},
		LoadFont("Common normal") .. {
			--rank
			InitCommand = function(self)
				self:xy(rankx, -8):zoom(tzoom):halign(0):valign(0)
			end,
			DisplayCommand = function(self)
				self:settextf("%i.", i + ind)
			end
		},
		LoadFont("Common normal") .. {
			--ssr
			InitCommand = function(self)
				self:x(ssrx):zoom(tzoom + 0.05):halign(0.5):valign(1)
			end,
			DisplayCommand = function(self)
				local ssr = hs:GetSkillsetSSR("Overall")
				self:settextf("%.2f", ssr):diffuse(byMSD(ssr))
			end
		},
		LoadFont("Common normal") .. {
			--rate
			InitCommand = function(self)
				self:xy(ratex,-7):zoom(tzoom - 0.05):halign(0.5):valign(0)
			end,
			DisplayCommand = function(self)
				local ratestring = string.format("%.2f", hs:GetMusicRate()):gsub("%.?0$", "") .. "x"
				self:settext(ratestring)
			end,
			ExpandCommand = function(self)
				self:addy(-row2yoff)
			end
		},
		UIElements.TextToolTip(1, 1, "Common Normal") .. {
			Name = "UserNamename" .. i,
			InitCommand = function(self)
				self:x(namex):zoom(tzoom + 0.1):halign(0):valign(1)
			end,
			DisplayCommand = function(self)
				self:settext(hs:GetDisplayName())
				if not hs:GetEtternaValid() then
					self:diffuse(color("#F0EEA6"))
				else
					self:diffuse(getMainColor("positive"))
				end
			end,
			MouseOverCommand = function(self)
				self:diffusealpha(hoverAlpha)
			end,
			MouseOutCommand = function(self)
				self:diffusealpha(1)
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" then
					local urlstringyo = DLMAN:GetHomePage() .. "/users/" .. hs:GetDisplayName()
					GAMESTATE:ApplyGameCommand("urlnoexit," .. urlstringyo)
				end
			end
		},
		UIElements.TextToolTip(1, 1, "Common Normal") .. {
			Name = "UserJudgeSpread" .. i,
			InitCommand = function(self)
                self:x(spreadx):zoom(spreadzoom):halign(0):valign(1)
			end,
			DisplayCommand = function(self)
				self:settext(hs:GetJudgmentString())
				if not hs:GetEtternaValid() then
					self:diffuse(color("#F0EEA6"))
				else
					self:diffuse(getMainColor("positive"))
				end
			end,
			MouseOverCommand = function(self)
				self:diffusealpha(hoverAlpha)
			end,
			MouseOutCommand = function(self)
				self:diffusealpha(1)
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" then
					local urlstringyo = DLMAN:GetHomePage() .. "/users/" .. hs:GetDisplayName() .. "/scores/" .. hs:GetScoreid()
					GAMESTATE:ApplyGameCommand("urlnoexit," .. urlstringyo)
				end
			end,
			CollapseCommand = function(self)
				self:visible(false)
			end,
			ExpandCommand = function(self)
				self:visible(true):addy(-row2yoff)
			end
		},
		LoadFont("Common normal") .. {
			--percent
			Name="NormalText",
			InitCommand = function(self)
				self:x(accx):zoom(tzoom + 0.15):halign(1):valign(1)
			end,
			DisplayCommand = function(self)
				self:settextf("%05.2f%%", notShit.floor(hs:GetWifeScore() * 100, 2)):diffuse(byGrade(hs:GetWifeGrade()))
			end
		},
		LoadFont("Common normal") .. {
			--percent but longer
			Name="LongerText",
			InitCommand = function(self)
				self:x(accx):zoom(tzoom + 0.15):halign(1):valign(1)
				self:visible(false)
			end,
			DisplayCommand = function(self)
				local perc = hs:GetWifeScore() * 100
				self:settextf("%05.4f%%", notShit.floor(perc, 4))
				self:diffuse(byGrade(hs:GetWifeGrade()))
			end
		},
		LoadFont("Common normal") .. {
			--date
			InitCommand = function(self)
                self:x(datex):zoom(datezoom):halign(1):valign(1)
			end,
			DisplayCommand = function(self)
				if IsUsingWideScreen() then
					self:settext(hs:GetDate())
				else
					self:settext(hs:GetDate():sub(1, 10))
				end
			end,
			CollapseCommand = function(self)
				self:visible(false)
			end,
			ExpandCommand = function(self)
				self:visible(true):addy(-row2yoff)
			end
		}
	}
	return o
end

for i = 1, numscores do
	o[#o + 1] = makeScoreDisplay(i)
end


return o