local t = Def.ActorFrame {}
local inMulti = Var("LoadingScreen") == "ScreenNetEvaluation"

if GAMESTATE:GetNumPlayersEnabled() == 1 then
	if inMulti then
		t[#t + 1] = LoadActor("MPscoreboard")
	else
		t[#t + 1] = LoadActor("scoreboard")
	end
end



--this REALLY needs a rewrite, at least until the 5th test client releases

--[[
	This needs a rewrite so that there is a single point of entry for choosing the displayed score, rescoring it, and changing its judge.
	We "accidentally" started using inconsistent methods of communicating between actors and files due to lack of code design.
	The primary rescore function is hiding in the function responsible for displaying the graphs, which may or may not be called by random code everywhere.
]]

local translated_info = {
	CCOn = THEME:GetString("ScreenEvaluation", "ChordCohesionOn"),
	MAPARatio = THEME:GetString("ScreenEvaluation", "MAPARatio")
}

-- im going to cry
local aboutToForceWindowSettings = false

local function scaleToJudge(scale)
	scale = notShit.round(scale, 2)
	local scales = ms.JudgeScalers
	local out = 4
	for k,v in pairs(scales) do
		if v == scale then
			out = k
		end
	end
	return out
end

local hoverAlpha = 0.8
local judge = PREFSMAN:GetPreference("SortBySSRNormPercent") and 4 or GetTimingDifficulty()
local judge2 = judge
local score = SCOREMAN:GetMostRecentScore()
if not score then
	score = SCOREMAN:GetTempReplayScore()
end
local dvt = {}
local totalTaps = 0
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()

local frameX = 573
local frameY = 150 
local frameWidth = SCREEN_CENTER_X - capWideScale(get43size(150),160)
local linearvariable = 1.3

-- dont default to using custom windows and dont persist that state
-- custom windows are meant to be used as a thing you occasionally check, not the primary way to play the game
local usingCustomWindows = false

--ScoreBoard
local judges = {
	"TapNoteScore_W1",
	"TapNoteScore_W2",
	"TapNoteScore_W3",
	"TapNoteScore_W4",
	"TapNoteScore_W5",
	"TapNoteScore_Miss"
}

t[#t+1] = Def.ActorFrame {
	Name = "SongInfo",

	LoadFont("Common Large") .. {
		Name = "SongTitle",
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, 20):diffusealpha(1)
			self:zoom(0.33)
			self:maxwidth(capWideScale(250 / 0.25, 400 / 0.25))
		end,
		BeginCommand = function(self)
			self:queuecommand("Set")
		end,
		SetCommand = function(self)
			self:settext(GAMESTATE:GetCurrentSong():GetDisplayMainTitle())
		end,
	},
	LoadFont("Common Large") .. {
		Name = "SongArtist",
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, 35):diffusealpha(1)
			self:zoom(0.2)
			self:maxwidth(180 / 0.25)
		end,
		BeginCommand = function(self)
			self:queuecommand("Set")
		end,
		SetCommand = function(self)
			self:settext(GAMESTATE:GetCurrentSong():GetDisplayArtist())	
		end,
	},
	LoadFont("Common Large") .. {
		Name = "Subtitle",
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X + capWideScale(get43size(150),0), SCREEN_BOTTOM - 13)
			self:zoom(0.25)
			self:maxwidth(capWideScale(500 / 0.25, 500 / 0.25))
		end,
		BeginCommand = function(self)
			self:queuecommand("Set")
		end,
		SetCommand = function(self)
			if GAMESTATE:GetCurrentSong():GetDisplaySubTitle() == "" then
			   self:settext("")
		    else
			   self:settext("''"..GAMESTATE:GetCurrentSong():GetDisplaySubTitle().. "''")
		    end
		end,
	},
	LoadFont("Common Large") .. {
		Name = "AuthorSim", --thanks for the idea oniichan42
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, 50)
			self:zoom(0.23)
			self:maxwidth(capWideScale(250 / 0.25, 180 / 0.25))
			self:diffuse(getMainColor("positive"))
		end,
		BeginCommand = function(self)
			self:queuecommand("Set")
		end,
		SetCommand = function(self)
			self:settext("By: " ..GAMESTATE:GetCurrentSong():GetOrTryAtLeastToGetSimfileAuthor())
		end,
	},
}

-- a helper to get the radar value for a score and fall back to playerstagestats if that fails
local function gatherRadarValue(radar, score)
    local n = score:GetRadarValues():GetValue(radar)
    if n == -1 then
        return pss:GetRadarActual():GetValue(radar)
    end
    return n
end

local function getRescoreElements(score)
	local o = {}
	o["dvt"] = dvt
    o["totalHolds"] = pss:GetRadarPossible():GetValue("RadarCategory_Holds") + pss:GetRadarPossible():GetValue("RadarCategory_Rolls")
	o["holdsHit"] = gatherRadarValue("RadarCategory_Holds", score) + gatherRadarValue("RadarCategory_Rolls", score)
	o["holdsMissed"] = o["totalHolds"] - o["holdsHit"]
    o["minesHit"] = pss:GetRadarPossible():GetValue("RadarCategory_Mines") - gatherRadarValue("RadarCategory_Mines", score)
	o["totalTaps"] = totalTaps
	return o
end
local lastSnapshot = nil

local function scoreBoard(pn, position)
	local dvtTmp = {}
	local tvt = {}
	dvt = {}
	totalTaps = 0

	local function setupNewScoreData(score)
		local replay = usingCustomWindows and REPLAYS:GetActiveReplay() or score:GetReplay()
		replay:LoadAllData()
		local dvtTmp = replay:GetOffsetVector()
		local tvt = replay:GetTapNoteTypeVector()
		-- if available, filter out non taps from the deviation list
		-- (hitting mines directly without filtering would make them appear here)
		if tvt ~= nil and #tvt > 0 then
			dvt = {}
			for i, d in ipairs(dvtTmp) do
				local ty = tvt[i]
				if ty == "TapNoteType_Tap" or ty == "TapNoteType_HoldHead" or ty == "TapNoteType_Lift" then
					dvt[#dvt+1] = d
				end
			end
		else
			dvt = dvtTmp
		end

		totalTaps = 0
		for k, v in ipairs(judges) do
			totalTaps = totalTaps + score:GetTapNoteScore(v)
		end
	end
	setupNewScoreData(score)

	-- we removed j1-3 so uhhh this stops things lazily
	local function clampJudge()
		if judge < 4 then judge = 4 end
		if judge > 9 then judge = 9 end
	end
	clampJudge()

	local t = Def.ActorFrame {
		Name = "ScoreDisplay",
		BeginCommand = function(self)
			if position == 1 then
				self:x(SCREEN_WIDTH - (frameX * 2) - frameWidth)
			end
			if PREFSMAN:GetPreference("SortBySSRNormPercent") then
				judge = 4
				judge2 = judge
				-- you ever hack something so hard?
				aboutToForceWindowSettings = true
				MESSAGEMAN:Broadcast("ForceWindow", {judge=4})
				MESSAGEMAN:Broadcast("RecalculateGraphs", {judge=4})
			else
				judge = scaleToJudge(SCREENMAN:GetTopScreen():GetReplayJudge())
				clampJudge()
				judge2 = judge
				MESSAGEMAN:Broadcast("ForceWindow", {judge=judge})
				MESSAGEMAN:Broadcast("RecalculateGraphs", {judge=judge})
			end
		end,
		ChangeScoreCommand = function(self, params)
			if params.score then
				score = params.score
				if usingCustomWindows then
					-- this is done very carefully to rescore a newly selected score once for wife3 and once for custom rescoring
					unloadCustomWindowConfig()
					usingCustomWindows = false
					setupNewScoreData(score)
					MESSAGEMAN:Broadcast("ScoreChanged")
					usingCustomWindows = true
					loadCurrentCustomWindowConfig()
					setupNewScoreData(score)
				else
					setupNewScoreData(score)
				end
			end

			if usingCustomWindows then
				lastSnapshot = REPLAYS:GetActiveReplay():GetLastReplaySnapshot()
				self:playcommand("MoveCustomWindowIndex", {direction = 0})
			else
				MESSAGEMAN:Broadcast("ScoreChanged")
			end
		end,
		UpdateNetEvalStatsMessageCommand = function(self)
			local s = SCREENMAN:GetTopScreen():GetHighScore()
			if s then
				score = s
			end
			local replay = score:GetReplay()
			replay:LoadAllData()
			local dvtTmp = replay:GetOffsetVector()
			local tvt = replay:GetTapNoteTypeVector()
			-- if available, filter out non taps from the deviation list
			-- (hitting mines directly without filtering would make them appear here)
			if tvt ~= nil and #tvt > 0 then
				dvt = {}
				for i, d in ipairs(dvtTmp) do
					local ty = tvt[i]
					if ty == "TapNoteType_Tap" or ty == "TapNoteType_HoldHead" or ty == "TapNoteType_Lift" then
						dvt[#dvt+1] = d
					end
				end
			else
				dvt = dvtTmp
			end
			totalTaps = 0
			for k, v in ipairs(judges) do
				totalTaps = totalTaps + score:GetTapNoteScore(v)
			end
			MESSAGEMAN:Broadcast("ScoreChanged")
		end,

		Def.Quad {
			Name = "DisplayBG",
			InitCommand = function(self)
				self:xy(frameX - 5, frameY + 25)
				self:zoomto(frameWidth + 12, SCREEN_WIDTH / 3.3)
				self:halign(0):valign(0)
				self:diffuse(getMainColor("frames")):diffusealpha(0.65)
			end,
		},
		Def.ActorFrame {
			Name = "CustomScoringDisplay",
			InitCommand = function(self)
				self:xy(frameX - 5, frameY + 49)
				self:visible(usingCustomWindows)
			end,
			ToggleCustomWindowsMessageCommand = function(self)
				if inMulti then return end
				usingCustomWindows = not usingCustomWindows

				self:visible(usingCustomWindows)
				self:GetParent():GetChild("WifeDisplay"):visible(not usingCustomWindows)
				if not usingCustomWindows then
					unloadCustomWindowConfig()
					MESSAGEMAN:Broadcast("UnloadedCustomWindow")
					MESSAGEMAN:Broadcast("RecalculateGraphs", {judge=judge})
					self:GetParent():playcommand("ChangeScore", {score = score})
					MESSAGEMAN:Broadcast("SetFromDisplay", {score = score})
					MESSAGEMAN:Broadcast("ForceWindow", {judge=judge})
				else
					loadCurrentCustomWindowConfig()
					MESSAGEMAN:Broadcast("RecalculateGraphs", {judge=judge})
					lastSnapshot = REPLAYS:GetActiveReplay():GetLastReplaySnapshot()
					self:playcommand("Set")
					MESSAGEMAN:Broadcast("LoadedCustomWindow")
				end
			end,
			EndCommand = function(self)
				unloadCustomWindowConfig()
			end,
			MoveCustomWindowIndexMessageCommand = function(self, params)
				if not usingCustomWindows then return end
				moveCustomWindowConfigIndex(params.direction)
				loadCurrentCustomWindowConfig()
				MESSAGEMAN:Broadcast("RecalculateGraphs", {judge=judge})
				lastSnapshot = REPLAYS:GetActiveReplay():GetLastReplaySnapshot()
				self:playcommand("Set")
				MESSAGEMAN:Broadcast("LoadedCustomWindow")
			end,
			CodeMessageCommand = function(self, params)
				if inMulti then return end
				if params.Name == "Coin" then
					self:playcommand("ToggleCustomWindows")
				end
				if not usingCustomWindows then return end
				if params.Name == "PrevJudge" then
					MESSAGEMAN:Broadcast("MoveCustomWindowIndex", {direction=-1})
				elseif params.Name == "NextJudge" then
					MESSAGEMAN:Broadcast("MoveCustomWindowIndex", {direction=1})
				end
			end,

			UIElements.QuadButton(1, 1) .. {
				Name = "BG",
				InitCommand = function(self)
					self:zoomto(capWideScale(get43size(235),235), 25)
					self:halign(0):valign(1)
					self:diffusealpha(0)
				end,
				MouseClickCommand = function(self, params)
					if self:IsVisible() and usingCustomWindows then
						if params.event ~= "DeviceButton_left mouse button" then
							moveCustomWindowConfigIndex(1)
						else
							moveCustomWindowConfigIndex(-1)
						end
						loadCurrentCustomWindowConfig()
						MESSAGEMAN:Broadcast("RecalculateGraphs", {judge=judge})
						lastSnapshot = REPLAYS:GetActiveReplay():GetLastReplaySnapshot()
						self:GetParent():playcommand("Set")
						MESSAGEMAN:Broadcast("LoadedCustomWindow")
					end
				end,
			},
			LoadFont("Common Large") .. {
				Name = "CustomPercent",
				InitCommand = function(self)
					self:xy(8, -4)
					self:zoom(0.37)
					self:halign(0):valign(1)
					self:maxwidth(550)
				end,
				SetCommand = function(self)
					self:diffuse(getGradeColor(score:GetWifeGrade()))
					-- 2 billion should be the last noterow always. just interested in the final score.
					local wife = lastSnapshot:GetWifePercent() * 100
					if wife > 99 then
						self:settextf(
							"%05.4f%% (%s)",
							notShit.floor(wife, 4), getCurrentCustomWindowConfigName()
						)
					else
						self:settextf(
							"%05.2f%% (%s)",
							notShit.floor(wife, 2), getCurrentCustomWindowConfigName()
						)
					end
				end,
			},
		},
		LoadFont("Common Large") .. {
			Name = "MSDDisplay",
			InitCommand = function(self)
				self:xy(frameX + 2, frameY + 50)
				self:zoom(0.37)
				self:halign(0):valign(0)
				self:maxwidth(200)
			end,
			BeginCommand = function(self)
				self:queuecommand("Set")
			end,
			ScoreChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			SetCommand = function(self)
				local top = SCREENMAN:GetTopScreen()
				local rate
				if top:GetName() == "ScreenNetEvaluation" then
					rate = score:GetMusicRate()
				else
					rate = top:GetReplayRate()
					if not rate then rate = getCurRateValue() end
				end
				rate = notShit.round(rate,3)
				local meter = GAMESTATE:GetCurrentSteps():GetMSD(rate, 1)
				if meter < 10 then
					self:settextf("%4.2f", meter)
				else
					self:settextf("%5.2f", meter)
				end
				self:diffuse(byMSD(meter))
			end,
		},
		LoadFont("Common Large") .. {
			Name = "SSRDisplay",
			InitCommand = function(self)
				self:xy(frameWidth + frameX + 5, frameY + 50)
				self:zoom(0.37)
				self:halign(1):valign(0)
				self:maxwidth(200)
			end,
			BeginCommand = function(self)
				self:queuecommand("Set")
			end,
			ScoreChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			SetCommand = function(self)
				local meter = score:GetSkillsetSSR("Overall")
				self:settextf("%5.2f", meter)
				self:diffuse(byMSD(meter))
			end,
		},
		LoadFont("Common Large") .. {
			Name = "DifficultyName",
			InitCommand = function(self)
				self:xy(frameWidth + frameX + 4, frameY + 38)
				self:zoom(0.23)
				self:halign(1):valign(0)
				self:maxwidth(200)
			end,
			BeginCommand = function(self)
				self:queuecommand("Set")
			end,
			SetCommand = function(self)
				local steps = GAMESTATE:GetCurrentSteps()
				local diff = getDifficulty(steps:GetDifficulty())
				self:settext(getShortDifficulty(diff))
				self:diffuse(getDifficultyColor(GetCustomDifficulty(steps:GetStepsType(), steps:GetDifficulty())))
			end,
		},
		Def.Quad {
			InitCommand = function(self)
				self:xy(frameX + capWideScale(get43size(250),35), frameY - 90)
				self:zoomto(80,25)
				self:diffuse(getMainColor("frames"))
			end
		},
		LoadFont("Common Large") .. {
			Name = "RateString",
			InitCommand = function(self)
				self:xy(frameX + capWideScale(get43size(250),35), frameY - 90)
				self:zoom(0.3)
				self:halign(0.5)
				self:diffuse(getMainColor("positive"))
				self:queuecommand("Set")
			end,
			ScoreChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			SetCommand = function(self)
				local top = SCREENMAN:GetTopScreen()
				local rate
				if top:GetName() == "ScreenNetEvaluation" then
					rate = score:GetMusicRate()
				else
					rate = top:GetReplayRate()
					if not rate then rate = getCurRateValue() end
				end
				rate = notShit.round(rate,3)
				local ratestr = getRateString(rate)
				if ratestr == "1x" then
					self:settext("Rate: 1.0x")
				else
					self:settext("Rate: " .. ratestr)
				end
			end,
		},
		Def.ActorFrame {
			Name = "WifeDisplay",
			ForceWindowMessageCommand = function(self, params)
				self:playcommand("Set")
			end,
			UIElements.QuadButton(1, 1) .. {
				Name = "MouseHoverBG",
				InitCommand = function(self)
					self:xy(frameX + 3, frameY + 37)
					self:zoomto(capWideScale(320,490)/2.2,20)
					self:halign(0):valign(0)
					self:diffusealpha(0)
				end,
				MouseOverCommand = function(self)
					if self:IsVisible() then
						self:GetParent():GetChild("NormalText"):visible(false)
						self:GetParent():GetChild("LongerText"):visible(true)
					end
				end,
				MouseOutCommand = function(self)
					if self:IsVisible() then
						self:GetParent():GetChild("NormalText"):visible(true)
						self:GetParent():GetChild("LongerText"):visible(false)
					end
				end,
				MouseClickCommand = function(self)
					if inMulti then return end
					if self:IsVisible() then
						MESSAGEMAN:Broadcast("ToggleCustomWindows")
					end
				end,
			},
			LoadFont("Common Large") .. {
				Name = "NormalText",
				InitCommand = function(self)
					self:xy(frameX + 3, frameY + 32)
					self:zoom(0.37)
					self:halign(0):valign(0)
					self:maxwidth(550)
					self:visible(true)
				end,
				BeginCommand = function(self)
					self:queuecommand("Set")
				end,
				SetCommand = function(self)
					local wv = score:GetWifeVers()
					local js = judge ~= 9 and judge or "ustice"
					local rescoretable = getRescoreElements(score)
					local rescorepercent = getRescoredWife3Judge(3, judge, rescoretable)
					wv = 3 -- this should really only be applicable if we can convert the score
					local ws = "Wife" .. wv .. " J"
					self:diffuse(getGradeColor(score:GetWifeGrade()))
					self:settextf(
						"%05.2f%% (%s)",
						notShit.floor(rescorepercent, 2), ws .. js
					)
				end,
				ScoreChangedMessageCommand = function(self)
					self:queuecommand("Set")
				end,
				CodeMessageCommand = function(self, params)
					if usingCustomWindows then
						return
					end

					local rescoretable = getRescoreElements(score)
					local rescorepercent = 0
					local ws = "Wife3" .. " J"
					if params.Name == "PrevJudge" and judge > 4 then
						judge = judge - 1
						clampJudge()
						rescorepercent = getRescoredWife3Judge(3, judge, rescoretable)
						local pct = notShit.floor(rescorepercent, 2)
						self:diffuse(getGradeColor(GetGradeFromPercent(pct/100)))
						self:settextf(
							"%05.2f%% (%s)", pct, ws .. judge
						)
						MESSAGEMAN:Broadcast("RecalculateGraphs", {judge = judge})
					elseif params.Name == "NextJudge" and judge < 9 then
						judge = judge + 1
						clampJudge()
						rescorepercent = getRescoredWife3Judge(3, judge, rescoretable)
						local js = judge ~= 9 and judge or "ustice"
						local pct = notShit.floor(rescorepercent, 2)
						self:diffuse(getGradeColor(GetGradeFromPercent(pct/100)))
						self:settextf(
							"%05.2f%% (%s)", pct, ws .. js
						)
						MESSAGEMAN:Broadcast("RecalculateGraphs", {judge = judge})
					end
					if params.Name == "ResetJudge" then
						judge = GetTimingDifficulty()
						clampJudge()
						self:playcommand("Set")
						MESSAGEMAN:Broadcast("RecalculateGraphs", {judge = judge})
					end
				end,
			},
			LoadFont("Common Large") ..	{-- high precision rollover
				Name = "LongerText",
				InitCommand = function(self)
					self:xy(frameX + 3, frameY + 32)
					self:zoom(0.37)
					self:halign(0):valign(0)
					self:maxwidth(550)
					self:visible(false)
				end,
				BeginCommand = function(self)
					self:queuecommand("Set")
				end,
				SetCommand = function(self)
					local wv = score:GetWifeVers()
					local js = judge ~= 9 and judge or "ustice"
					local rescoretable = getRescoreElements(score)
					local rescorepercent = getRescoredWife3Judge(3, judge, rescoretable)
					wv = 3 -- this should really only be applicable if we can convert the score
					local ws = "Wife" .. wv .. " J"
					self:diffuse(getGradeColor(score:GetWifeGrade()))
					self:settextf(
						"%05.4f%% (%s)",
						notShit.floor(rescorepercent, 4), ws .. js
					)
				end,
				ScoreChangedMessageCommand = function(self)
					self:queuecommand("Set")
				end,
				CodeMessageCommand = function(self, params)
					if usingCustomWindows then
						return
					end

					local rescoretable = getRescoreElements(score)
					local rescorepercent = 0
					local wv = score:GetWifeVers()
					local ws = "Wife3" .. " J"
					if params.Name == "PrevJudge" and judge2 > 4 then
						judge2 = judge2 - 1
						rescorepercent = getRescoredWife3Judge(3, judge2, rescoretable)
						local pct = notShit.floor(rescorepercent, 4)
						self:diffuse(getGradeColor(GetGradeFromPercent(pct/100)))
						self:settextf(
							"%05.4f%% (%s)", pct, ws .. judge2
						)
					elseif params.Name == "NextJudge" and judge2 < 9 then
						judge2 = judge2 + 1
						rescorepercent = getRescoredWife3Judge(3, judge2, rescoretable)
						local js = judge2 ~= 9 and judge2 or "ustice"
						local pct = notShit.floor(rescorepercent, 4)
						self:diffuse(getGradeColor(GetGradeFromPercent(pct/100)))
						self:settextf(
							"%05.4f%% (%s)", pct, ws .. js
						)
					end
					if params.Name == "ResetJudge" then
						judge2 = GetTimingDifficulty()
						self:playcommand("Set")
					end
				end,
			},
		},
		LoadFont("Common Large") .. {
			Name = "ChordCohesionIndicator",
			InitCommand = function(self)
				self:xy(frameX + 3, frameY + 210)
				self:zoom(0.25)
				self:halign(0)
				self:maxwidth(capWideScale(get43size(100), 160)/0.25)
				self:settext(translated_info["CCOn"])
				self:visible(false)
			end,
			BeginCommand = function(self)
				self:queuecommand("Set")
			end,
			ScoreChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			SetCommand = function(self)
				if score:GetChordCohesion() then
					self:visible(true)
				else
					self:visible(false)
				end
			end,
		},
	}

	local function judgmentBar(judgmentIndex, judgmentName)
		local t = Def.ActorFrame {
			Name = "JudgmentBar"..judgmentName,
			BeginCommand = function(self)
				if aboutToForceWindowSettings then
					self.jcount = 0
				else
					self.jcount = score:GetTapNoteScore(judgmentName)
				end
			end,
			ForceWindowMessageCommand = function(self, params)
				self.jcount = getRescoredJudge(dvt, judge, judgmentIndex)
				self:playcommand("Set")
			end,
			LoadedCustomWindowMessageCommand = function(self)
				self.jcount = lastSnapshot:GetJudgments()[judgmentName:gsub("TapNoteScore_", "")]
				self:playcommand("Set")
			end,
			ScoreChangedMessageCommand = function(self)
				self.jcount = getRescoredJudge(dvt, judge, judgmentIndex)
				self:playcommand("Set")
			end,
			CodeMessageCommand = function(self, params)
				if usingCustomWindows then return end
				if params.Name == "PrevJudge" or params.Name == "NextJudge" then
					self.jcount = getRescoredJudge(dvt, judge, judgmentIndex)
				elseif params.Name == "ResetJudge" then
					self.jcount = score:GetTapNoteScore(judgmentName)
				end
				self:playcommand("Set")
			end,

			Def.Quad {
				Name = "BG",
				InitCommand = function(self)
					self:xy(frameX, frameY + 80 + ((judgmentIndex - 1) * 22))
					self:zoomto(frameWidth, 18)
					self:halign(0)
					self:diffuse(byJudgment(judgmentName))
					self:diffusealpha(0.5)
				end,
			},
			Def.Quad {
				Name = "Fill",
				InitCommand = function(self)
					self:xy(frameX, frameY + 80 + ((judgmentIndex - 1) * 22))
					self:zoomto(0, 18)
					self:halign(0)
					self:diffuse(byJudgment(judgmentName))
					self:diffusealpha(0.5)
				end,
				BeginCommand = function(self)
					self:glowshift()
					self:effectcolor1(color("1,1,1," .. tostring(score:GetTapNoteScore(judgmentName) / totalTaps * 0.4)))
					self:effectcolor2(color("1,1,1,0"))

					if aboutToForceWindowSettings then return end

					self:sleep(0.2)
					self:smooth(1.5)
					self:playcommand("Set")
				end,
				SetCommand = function(self)
					self:finishtweening()
					self:bounceend(0.2)
					self:zoomx(frameWidth * self:GetParent().jcount / totalTaps)
				end,
			},
			LoadFont("Common Large") .. {
				Name = "NameShadow",
				InitCommand = function(self)
					self:xy(frameX + 10, frameY + 80.5 + ((judgmentIndex - 1) * 22))
					self:zoom(0.25)
					self:halign(0)
					self:diffuse(getMainColor("frames"))
				end,
				BeginCommand = function(self)
					if aboutToForceWindowSettings then return end
					self:queuecommand("Set")
				end,
				SetCommand = function(self)
					if usingCustomWindows then
						self:settext(getCustomWindowConfigJudgmentName(judgmentName))
					else
						self:settext(getJudgeStrings(judgmentName))
					end
				end,
			},
			LoadFont("Common Large") .. {
				Name = "Name",
				InitCommand = function(self)
					self:xy(frameX + 10, frameY + 79.3 + ((judgmentIndex - 1) * 22))
					self:zoom(0.25)
					self:halign(0)
				end,
				BeginCommand = function(self)
					if aboutToForceWindowSettings then return end
					self:queuecommand("Set")
				end,
				SetCommand = function(self)
					if usingCustomWindows then
						self:settext(getCustomWindowConfigJudgmentName(judgmentName))
					else
						self:settext(getJudgeStrings(judgmentName))
					end
				end,
			},
			LoadFont("Common Large") .. {
				Name = "CountShadow",
				InitCommand = function(self)
					self:xy(frameX + frameWidth - 40, frameY + 80.8 + ((judgmentIndex - 1) * 22))
					self:zoom(0.3)
					self:halign(1)
					self:diffuse(getMainColor("frames"))
				end,
				BeginCommand = function(self)
					if aboutToForceWindowSettings then return end
					self:queuecommand("Set")
				end,
				SetCommand = function(self)
					self:settext(self:GetParent().jcount)
				end,
			},
			LoadFont("Common Large") .. {
				Name = "Count",
				InitCommand = function(self)
					self:xy(frameX + frameWidth - 40, frameY + 79.3 + ((judgmentIndex - 1) * 22))
					self:zoom(0.3)
					self:halign(1)
				end,
				BeginCommand = function(self)
					if aboutToForceWindowSettings then return end
					self:queuecommand("Set")
				end,
				SetCommand = function(self)
					self:settext(self:GetParent().jcount)
				end,
			},
			LoadFont("Common Normal") .. {
				Name = "Percentage",
				InitCommand = function(self)
					self:xy(frameX + frameWidth - 38, frameY + 79.7 + ((judgmentIndex - 1) * 22))
					self:zoom(0.3)
					self:halign(0)
				end,
				BeginCommand = function(self)
					if aboutToForceWindowSettings then return end
					self:queuecommand("Set")
				end,
				SetCommand = function(self)
					self:settextf("(%03.2f%%)", self:GetParent().jcount / totalTaps * 100)
				end,
			}
		}
		return t
	end

	local jc = Def.ActorFrame {
		Name = "JudgmentBars",
	}
	for i, v in ipairs(judges) do
		jc[#jc+1] = judgmentBar(i, v)
	end
	t[#t+1] = jc

	--[[
	The following section first adds the ratioText and the maRatio. Then the paRatio is added and positioned. The right
	values for maRatio and paRatio are then filled in. Finally ratioText and maRatio are aligned to paRatio.
	--]]
	local ratioText, maRatio, paRatio, marvelousTaps, perfectTaps, greatTaps
	t[#t+1] = Def.ActorFrame {
		Name = "MAPARatioContainer",

		LoadFont("Common Large") .. {
			Name = "Text",
			InitCommand = function(self)
				ratioText = self
				self:settextf("%s:", translated_info["MAPARatio"])
				self:zoom(0.25):halign(1)
			end
		},
		LoadFont("Common Large") .. {
			Name = "MAText",
			InitCommand = function(self)
				maRatio = self
				self:zoom(0.25):halign(1):diffuse(byJudgment(judges[1]))
			end
		},
		LoadFont("Common Large") .. {
			Name = "PAText",
			InitCommand = function(self)
				paRatio = self
				self:xy(frameWidth + frameX, frameY + 210)
				self:zoom(0.25)
				self:halign(1)
				self:diffuse(byJudgment(judges[2]))

				marvelousTaps = score:GetTapNoteScore(judges[1])
				perfectTaps = score:GetTapNoteScore(judges[2])
				greatTaps = score:GetTapNoteScore(judges[3])
				self:playcommand("Set")
			end,
			SetCommand = function(self)

				-- Fill in maRatio and paRatio
				maRatio:settextf("%.1f:1", marvelousTaps / perfectTaps)
				paRatio:settextf("%.1f:1", perfectTaps / greatTaps)

				-- Align ratioText and maRatio to paRatio (self)
				maRatioX = paRatio:GetX() - paRatio:GetZoomedWidth() - 10
				maRatio:xy(maRatioX, paRatio:GetY())

				ratioTextX = maRatioX - maRatio:GetZoomedWidth() - 10
				ratioText:xy(ratioTextX, paRatio:GetY())
				if score:GetChordCohesion() == true then
					maRatio:maxwidth(maRatio:GetZoomedWidth()/0.25)
					self:maxwidth(self:GetZoomedWidth()/0.25)
					ratioText:maxwidth(capWideScale(get43size(65), 85)/0.27)
				end
			end,
			CodeMessageCommand = function(self, params)
				if usingCustomWindows then
					return
				end

				if params.Name == "PrevJudge" or params.Name == "NextJudge" then
						marvelousTaps = getRescoredJudge(dvt, judge, 1)
						perfectTaps = getRescoredJudge(dvt, judge, 2)
						greatTaps = getRescoredJudge(dvt, judge, 3)
					self:playcommand("Set")
				end
				if params.Name == "ResetJudge" then
					marvelousTaps = score:GetTapNoteScore(judges[1])
					perfectTaps = score:GetTapNoteScore(judges[2])
					greatTaps = score:GetTapNoteScore(judges[3])
					self:playcommand("Set")
				end
			end,
			ForceWindowMessageCommand = function(self)
				marvelousTaps = getRescoredJudge(dvt, judge, 1)
				perfectTaps = getRescoredJudge(dvt, judge, 2)
				greatTaps = getRescoredJudge(dvt, judge, 3)
				self:playcommand("Set")
			end,
			ScoreChangedMessageCommand = function(self)
				self:playcommand("ForceWindow")
			end,
			LoadedCustomWindowMessageCommand = function(self)
				marvelousTaps = lastSnapshot:GetJudgments()["W1"]
				perfectTaps = lastSnapshot:GetJudgments()["W2"]
				greatTaps = lastSnapshot:GetJudgments()["W3"]
				self:playcommand("Set")
			end,
		},
	}

	local radars = {"Holds", "Mines", "Rolls", "Lifts", "Fakes"}
	local radars_translated = {
		Holds = THEME:GetString("RadarCategory", "Holds"),
		Mines = THEME:GetString("RadarCategory", "Mines"),
		Rolls = THEME:GetString("RadarCategory", "Rolls"),
		Lifts = THEME:GetString("RadarCategory", "Lifts"),
		Fakes = THEME:GetString("RadarCategory", "Fakes")
	}
	local function radarEntry(i)
		return Def.ActorFrame {
			Name = "Radar"..radars[i],

			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:xy(frameX + 20, frameY + 220 + 10 * i)
					self:zoom(0.4)
					self:halign(0)
					self:settext(radars_translated[radars[i]])
				end,
			},
			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:xy(frameX + 120, frameY + 220 + 10 * i)
					self:zoom(0.4)
					self:halign(1)
				end,
				BeginCommand = function(self)
					self:queuecommand("Set")
				end,
				SetCommand = function(self)
					self:settextf(
						"%03d/%03d",
						gatherRadarValue("RadarCategory_" .. radars[i], score),
						score:GetRadarPossible():GetValue("RadarCategory_" .. radars[i])
					)
				end,
				ScoreChangedMessageCommand = function(self)
					self:queuecommand("Set")
				end,
			},
		}
	end
	local rb = Def.ActorFrame {
		Name = "RadarContainer",
		Def.Quad {
			Name = "BG",
			InitCommand = function(self)
				self:xy(frameX - 5, frameY + 1006):zoomto(frameWidth / 2 - 10, 56.5) --the game straight up refuses to work if i delete this so i'll just put it too high
				self:halign(0):valign(0)
				self:diffuse(getMainColor("tabs"))
			end,
		},
	}
	for i = 1, #radars do
		rb[#rb+1] = radarEntry(i)
	end
	t[#t+1] = rb

	local function scoreStatistics(score)
		local replay = usingCustomWindows and REPLAYS:GetActiveReplay() or score:GetReplay()
		replay:LoadAllData()
		local tracks = replay:GetTrackVector()
		local dvtTmp = replay:GetOffsetVector() or {}
		local devianceTable = {}
		local types = replay:GetTapNoteTypeVector()

		local cbl = 0
		local cbr = 0
		local cbm = 0
		local tst = ms.JudgeScalers
		local tso = tst[judge]
		local ncol = GAMESTATE:GetCurrentSteps():GetNumColumns() - 1
		local middleCol = ncol/2

		-- if available, filter out non taps from the deviation list
		-- (hitting mines directly without filtering would make them appear here)
		if types ~= nil and #types > 0 then
			devianceTable = {}
			for i, d in ipairs(dvtTmp) do
				local ty = types[i]
				if ty == "TapNoteType_Tap" or ty == "TapNoteType_HoldHead" or ty == "TapNoteType_Lift" then
					devianceTable[#devianceTable+1] = d
				end
			end
		else
			devianceTable = dvtTmp
		end

		for i = 1, #devianceTable do
			if tracks[i] then
				if math.abs(devianceTable[i]) > tso * 90 then
					if tracks[i] < middleCol then
						cbl = cbl + 1
					elseif tracks[i] > middleCol then
						cbr = cbr + 1
					else
						cbm = cbm + 1
					end
				end
			end
		end
		local smallest, largest = wifeRange(devianceTable)

		-- this needs to match the statValues table below
		return {
			wifeMean(devianceTable),
			wifeSd(devianceTable),
			largest,
			cbl,
			cbr,
			cbm
		}
	end

	-- stats stuff
	local replay = score:GetReplay()
	replay:LoadAllData()
	local tracks = replay:GetTrackVector()
	local dvtTmp = replay:GetOffsetVector()
	local devianceTable = {}
	local types = replay:GetTapNoteTypeVector() or {}
	local cbl = 0
	local cbr = 0
	local cbm = 0

	-- basic per-hand stats to be expanded on later
	local tst = ms.JudgeScalers
	local tso = tst[judge]
	local ncol = GAMESTATE:GetCurrentSteps():GetNumColumns() - 1 -- cpp indexing -mina
	local middleCol = ncol/2

	-- if available, filter out non taps from the deviation list
	-- (hitting mines directly without filtering would make them appear here)
	if types ~= nil and #types > 0 then
		devianceTable = {}
		for i, d in ipairs(dvtTmp) do
			local ty = types[i]
			if ty == "TapNoteType_Tap" or ty == "TapNoteType_HoldHead" or ty == "TapNoteType_Lift" then
				devianceTable[#devianceTable+1] = d
			end
		end
	else
		devianceTable = dvtTmp
	end

	if devianceTable ~= nil then
		for i = 1, #devianceTable do
			if tracks[i] then	-- we dont load track data when reconstructing eval screen apparently so we have to nil check -mina
				if math.abs(devianceTable[i]) > tso * 90 then
					if tracks[i] < middleCol then
						cbl = cbl + 1
					elseif tracks[i] > middleCol then
						cbr = cbr + 1
					else
						cbm = cbm + 1
					end
				end
			end
		end

		local smallest, largest = wifeRange(devianceTable)
		local statNames = {
			THEME:GetString("ScreenEvaluation", "Mean"),
			THEME:GetString("ScreenEvaluation", "StandardDev"),
			THEME:GetString("ScreenEvaluation", "LargestDev"),
			THEME:GetString("ScreenEvaluation", "LeftCB"),
			THEME:GetString("ScreenEvaluation", "RightCB"),
			THEME:GetString("ScreenEvaluation", "MiddleCB")
		}
		local statValues = {
			wifeMean(devianceTable),
			wifeSd(devianceTable),
			largest,
			cbl,
			cbr,
			cbm
		}
		-- if theres a middle lane, display its cbs too
		local lines = ((ncol+1) % 2 == 0) and #statNames-1  or #statNames
		local tzoom = lines == 5 and 0.4 or 0.3
		local ySpacing = lines == 5 and 10 or 8.5
		local function statsLine(i)
			return Def.ActorFrame {
				Name = "StatLine"..statNames[i],
				LoadFont("Common Normal") .. {
					Name = "StatText",
					InitCommand = function(self)
						self:xy(frameX + capWideScale(get43size(200), 143), frameY + 220 + ySpacing * i)
						self:zoom(tzoom)
						self:halign(0)
						self:settext(statNames[i])
					end,
				},
				LoadFont("Common Normal") .. {
					Name=i,
					InitCommand = function(self)
						self:queuecommand("Set")
					end,
					SetCommand = function(self, params)
						local statValues = scoreStatistics(params ~= nil and params.score or score)
						if i < 4 then
							self:xy(frameWidth + capWideScale(get43size(0),560), frameY + 220 + ySpacing * i)
							self:zoom(tzoom)
							self:halign(1)
							self:settextf("%5.2fms", statValues[i])
						else
							self:xy(frameWidth + capWideScale(get43size(0),560), frameY + 220 + ySpacing * i)
							self:zoom(tzoom)
							self:halign(1)
							self:settext(statValues[i])
						end
					end,
					ChangeScoreCommand = function(self, params)
						self:queuecommand("Set", {score=params.score})
					end,
					LoadedCustomWindowMessageCommand = function(self)
						self:queuecommand("Set")
					end,
					CodeMessageCommand = function(self, params)
						if usingCustomWindows then
							return
						end

						if i > 3 and (params.Name == "PrevJudge" or params.Name == "NextJudge") then
							self:queuecommand("Set")
						end
					end,
					ForceWindowMessageCommand = function(self)
						self:queuecommand("Set")
					end,
				},
			}
		end

		local sl = Def.ActorFrame {
			Name = "ScoreStatsContainer",
			Def.Quad {
				Name = "BG",
				InitCommand = function(self)
					self:diffuse(getMainColor("tabs"))
					self:xy(frameWidth + 25, frameY + 2226) -- too lazy to remove the container soooo i'll just put it rlly high, maybe i will remove it one day if im not that lazy -ifwas
					self:zoomto(frameWidth / 2 + 10, 56.5) -- 56.5 original value
					self:halign(1):valign(0)
				end,
			},
		}
		for i = 1, lines do
			sl[#sl+1] = statsLine(i)
		end
		t[#t+1] = sl
	end

	

-- life graph
	local function GraphDisplay()
		return Def.ActorFrame {
			Def.GraphDisplay {
				InitCommand = function(self)
					self:Load("GraphDisplay")
				end,
				BeginCommand = function(self)
					local ss = SCREENMAN:GetTopScreen():GetStageStats()
					self:Set(ss, ss:GetPlayerStageStats())
					self:diffusealpha(0.7)
					self:GetChild("Line"):diffusealpha(0)
					self:zoom(0.65)
					self:xy(capWideScale(get43size(0),96), 220)
					self:zoomto(403, 30)
				end,
				ScoreChangedMessageCommand = function(self)
					if score and judge then
						self:playcommand("RecalculateGraphs", {judge=judge})
					end
				end,
				RecalculateGraphsMessageCommand = function(self, params)
					-- called by the end of a codemessagecommand somewhere else
					if not ms.JudgeScalers[params.judge] then return end
					local success = SCREENMAN:GetTopScreen():RescoreReplay(SCREENMAN:GetTopScreen():GetStageStats():GetPlayerStageStats(), ms.JudgeScalers[params.judge], score, usingCustomWindows and currentCustomWindowConfigUsesOldestNoteFirst())
					if not success then ms.ok("Retard you broke something lmao") return end
					self:playcommand("Begin")
					MESSAGEMAN:Broadcast("SetComboGraph")
				end,
			},
		}
	end

	-- combo graph
	local function ComboGraph()
		return Def.ActorFrame {
			Def.ComboGraph {
				InitCommand = function(self)
					self:Load("ComboGraph")
				end,
				BeginCommand = function(self)
					local ss = SCREENMAN:GetTopScreen():GetStageStats()
					self:Set(ss, ss:GetPlayerStageStats())
					self:zoom(0.65)
					self:xy(capWideScale(get43size(0),118), 190)
					self:zoomto(403, 10)
				end,
				SetComboGraphMessageCommand = function(self)
					self:Clear()
					self:Load("ComboGraph")
					self:playcommand("Begin")
				end,
			},
		}
	end

	t[#t + 1] = StandardDecorationFromTable("GraphDisplay" .. ToEnumShortString(PLAYER_1), GraphDisplay())
	t[#t + 1] = StandardDecorationFromTable("ComboGraph" .. ToEnumShortString(PLAYER_1), ComboGraph())

	return t
end

--this is so badly coded, don't do this, i only did this because i was tired
local tabindex = "local"

t[#t + 1] = UIElements.QuadButton(1, 1) .. {
	Name = "TabBGOnline",
	InitCommand = function(self)
		self:xy(168, SCREEN_CENTER_Y - 4):zoomto(50, 20):diffusecolor(getMainColor("frames")):diffusealpha(0.7):valign(1)
	end,
	MouseDownCommand = function(self, params)
		if params.event == "DeviceButton_left mouse button" and tabindex == "local" then
			MESSAGEMAN:Broadcast("ChangingTabToScore")
			self:diffusecolor(Brightness(getMainColor("positive"),0.3)):diffusealpha(0.5)
			self:linear(0.2):zoomto(50,25)
		end
	end,
	ExitTabScoreMessageCommand = function(self)
		tabindex = "local"
		self:diffusecolor(getMainColor("frames")):diffusealpha(0.7)
		self:linear(0.2):zoomto(50,20)
	end
}

t[#t + 1] = LoadFont("Common Large") .. {
	Name="TestEventLeaderboard",
	InitCommand = function(self)
		self:xy(155, SCREEN_CENTER_Y - 10):halign(0):valign(1):zoom(0.2):diffuse(getMainColor("positive"))
		self:settextf("Online")
	end,
	ChangingTabToScoreMessageCommand = function(self)
		self:linear(0.2):xy(155, SCREEN_CENTER_Y - 15)
	end,
	ExitTabScoreMessageCommand = function(self)
		self:linear(0.2):xy(155, SCREEN_CENTER_Y - 10)
	end
}

t[#t + 1] = UIElements.QuadButton(1, 1) .. {
	Name = "TabBGOffline",
	InitCommand = function(self)
		self:xy(118, SCREEN_CENTER_Y - 4):zoomto(50, 25):diffusecolor(Brightness(getMainColor("positive"),0.3)):diffusealpha(0.5):valign(1)
	end,
	ChangingTabToScoreMessageCommand = function(self)
		tabindex = "online"
		self:diffusecolor(getMainColor("frames")):diffusealpha(0.7)
		self:linear(0.2):zoomto(50,20)
	end,
	MouseDownCommand = function(self, params)
		if params.event == "DeviceButton_left mouse button" and tabindex == "online" then
			MESSAGEMAN:Broadcast("ExitTabScore")
			self:diffusecolor(Brightness(getMainColor("positive"),0.3)):diffusealpha(0.5)
			self:linear(0.2):zoomto(50,25)
		end
	end
}

t[#t + 1] = LoadFont("Common Large") .. {
	Name="TestEventExitLead",
	InitCommand = function(self)
		self:xy(107, SCREEN_CENTER_Y - 15):halign(0):valign(1):zoom(0.2):diffuse(getMainColor("positive"))
		self:settextf("Local")
	end,
	ChangingTabToScoreMessageCommand = function(self)
		self:linear(0.2):xy(107, SCREEN_CENTER_Y - 10)
	end,
	ExitTabScoreMessageCommand = function(self)
		self:linear(0.2):xy(107, SCREEN_CENTER_Y - 15)
	end
}

if GAMESTATE:IsPlayerEnabled() then
	t[#t + 1] = scoreBoard(PLAYER_1, 0)
end

t[#t + 1] = LoadActor("onlinething")
t[#t + 1] = LoadActor("../_xoon2")
t[#t + 1] = LoadActor("../offsetplot")
t[#t + 1] = LoadActor("../_volumecontrol")
updateDiscordStatus(true)

return t
