--[[
	Basically rewriting the c++ code to not be total shit so this can also not be total shit.
]] local allowedCustomization = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay
local practiceMode = GAMESTATE:IsPracticeMode()
local jcKeys = tableKeys(colorConfig:get_data().judgment)
local jcT = {} -- A "T" following a variable name will designate an object of type table.
local offsets = {}

for i = 1, #jcKeys do
    jcT[jcKeys[i]] = byJudgment(jcKeys[i])
end
jcT["TapNoteScore_None"] = color("1,1,1,1")

local customs = {}

local jdgT = { -- Table of judgments for the judgecounter
    "TapNoteScore_W1",
    "TapNoteScore_W2",
    "TapNoteScore_W3",
    "TapNoteScore_W4",
    "TapNoteScore_W5",
    "TapNoteScore_Miss",
    "HoldNoteScore_Held",
    "HoldNoteScore_LetGo"
}

local judgmentsHit = {} -- updated in WifePerch
local dvCur
local jdgCur -- Note: only for judgments with OFFSETS, might reorganize a bit later
local tDiff
local wifey
local judgect
local pbtarget
local positive = getMainColor("positive")
local highlight = getMainColor("highlight")
local negative = getMainColor("negative")

local jdgCounts = {} -- Child references for the judge counter

-- We can also pull in some localized aliases for workhorse functions for a modest speed increase
local Round = notShit.round
local Floor = notShit.floor
local diffusealpha = Actor.diffusealpha
local diffuse = Actor.diffuse
local finishtweening = Actor.finishtweening
local linear = Actor.linear
local x = Actor.x
local y = Actor.y
local addx = Actor.addx
local addy = Actor.addy
local Zoomtoheight = Actor.zoomtoheight
local Zoomtowidth = Actor.zoomtowidth
local Zoomm = Actor.zoom
local queuecommand = Actor.queuecommand
local playcommand = Actor.queuecommand
local settext = BitmapText.settext
local Broadcast = MessageManager.Broadcast

-- these dont really work as borders since they have to be destroyed/remade in order to scale width/height
-- however we can use these to at least make centered snap lines for the screens -mina
local function dot(height, x)
    return Def.Quad {
        InitCommand = function(self)
            self:zoomto(dotwidth, height)
            self:addx(x)
        end
    }
end

local function dottedline(len, height, x, y, rot)
    local t = Def.ActorFrame {
        InitCommand = function(self)
            self:xy(x, y):addrotationz(rot)
            if x == 0 and y == 0 then
                self:diffusealpha(0.65)
            end
        end
    }
    local numdots = len / dotwidth
    t[#t + 1] = dot(height, 0)
    for i = 1, numdots / 4 do
        t[#t + 1] = dot(height, i * dotwidth * 2 - dotwidth / 2)
    end
    for i = 1, numdots / 4 do
        t[#t + 1] = dot(height, -i * dotwidth * 2 + dotwidth / 2)
    end
    return t
end

local function DottedBorder(width, height, bw, x, y)
    return Def.ActorFrame {
        Name = "Border",
        InitCommand = function(self)
            self:xy(x, y):visible(false):diffusealpha(0.35)
        end,
        dottedline(width, bw, 0, 0, 0),
        dottedline(width, bw, 0, height / 2, 0),
        dottedline(width, bw, 0, -height / 2, 0),
        dottedline(height, bw, 0, 0, 90),
        dottedline(height, bw, width / 2, 0, 90),
        dottedline(height, bw, -width / 2, 0, 90)
    }
end

local translated_info = {
    ErrorLate = THEME:GetString("ScreenGameplay", "ErrorBarLate"),
    ErrorEarly = THEME:GetString("ScreenGameplay", "ErrorBarEarly"),
    NPS = THEME:GetString("ChordDensityGraph", "NPS"),
    BPM = THEME:GetString("ChordDensityGraph", "BPM")
}

-- Screenwide params
-- ==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
isCentered = PREFSMAN:GetPreference("Center1Player")
local CenterX = SCREEN_CENTER_X
local mpOffset = 0
if not isCentered then
    CenterX = THEME:GetMetric("ScreenGameplay", string.format("PlayerP1%sX", ToEnumShortString(
        GAMESTATE:GetCurrentStyle():GetStyleType())))
    mpOffset = SCREEN_CENTER_X
end
-- ==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

local screen -- the screen after it is loaded

local WIDESCREENWHY = -5
local WIDESCREENWHX = -5

-- error bar things
local errorBarFrameWidth = capWideScale(get43size(MovableValues.ErrorBarWidth), MovableValues.ErrorBarWidth)
local wscale = errorBarFrameWidth / 180

-- differential tracker things
local targetTrackerMode = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).TargetTrackerMode

-- receptor/Notefield things
local Notefield
local noteColumns
local usingReverse

-- guess checking if things are enabled before changing them is good for not having a log full of errors
local enabledErrorBar = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).ErrorBar
local enabledMiniBar = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).MiniProgressBar
local enabledFullBar = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).FullProgressBar
local enabledTargetTracker = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).TargetTracker
local enabledDisplayPercent = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).DisplayPercent
local enabledJudgeCounter = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).JudgeCounter
local leaderboardEnabled = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).leaderboardEnabled and DLMAN:IsLoggedIn()
local isReplay = GAMESTATE:GetPlayerState():GetPlayerController() == "PlayerController_Replay"

local function arbitraryErrorBarValue(value)
    errorBarFrameWidth = capWideScale(get43size(value), value)
    wscale = errorBarFrameWidth / 180
end

local function spaceNotefieldCols(inc)
    if inc == nil then
        inc = 0
    end
    local hCols = math.floor(#noteColumns / 2)
    for i, col in ipairs(noteColumns) do
        col:addx((i - hCols - 1) * inc)
    end
end

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
								     **Wife deviance tracker. Basically half the point of the theme.**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	For every doot there is an equal and opposite scoot.
]]
local t = Def.ActorFrame {
    Name = "WifePerch",
    OnCommand = function(self)
        if allowedCustomization and SCREENMAN:GetTopScreen():GetName() ~= "ScreenGameplaySyncMachine" then
            -- auto enable autoplay
            GAMESTATE:SetAutoplay(true)
        else
            GAMESTATE:SetAutoplay(false)
        end
        -- Discord thingies
        updateDiscordStatus(false)

        -- now playing thing for streamers
        updateNowPlaying()

        screen = SCREENMAN:GetTopScreen()
        usingReverse = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions():UsingReverse()
        Notefield = screen:GetChild("PlayerP1"):GetChild("NoteField")
        Notefield:addy(MovableValues.NotefieldY * (usingReverse and 1 or -1))
        Notefield:addx(MovableValues.NotefieldX)
        noteColumns = Notefield:get_column_actors()
        -- lifebar stuff
        local lifebar = SCREENMAN:GetTopScreen():GetLifeMeter(PLAYER_1)

        if (allowedCustomization) then
            Movable.pressed = false
            Movable.current = "None"
            Movable.DeviceButton_r.element = Notefield
            Movable.DeviceButton_t.element = noteColumns
            Movable.DeviceButton_r.condition = true
            Movable.DeviceButton_t.condition = true
            self:GetChild("LifeP1"):GetChild("Border"):SetFakeParent(lifebar)
            Movable.DeviceButton_j.element = lifebar
            Movable.DeviceButton_j.condition = true
            Movable.DeviceButton_k.element = lifebar
            Movable.DeviceButton_k.condition = true
            Movable.DeviceButton_l.element = lifebar
            Movable.DeviceButton_l.condition = true
            Movable.DeviceButton_n.condition = true
            Movable.DeviceButton_n.DeviceButton_up.arbitraryFunction = spaceNotefieldCols
            Movable.DeviceButton_n.DeviceButton_down.arbitraryFunction = spaceNotefieldCols
        end

        if lifebar ~= nil then
            lifebar:zoomtowidth(MovableValues.LifeP1Width)
            lifebar:zoomtoheight(MovableValues.LifeP1Height)
            lifebar:xy(MovableValues.LifeP1X, MovableValues.LifeP1Y)
            lifebar:rotationz(MovableValues.LifeP1Rotation)
        end

        for i, actor in ipairs(noteColumns) do
            actor:zoomtowidth(MovableValues.NotefieldWidth)
            actor:zoomtoheight(MovableValues.NotefieldHeight)
        end

        spaceNotefieldCols(MovableValues.NotefieldSpacing)
    end,
    DoneLoadingNextSongMessageCommand = function(self)
        -- put notefield y pos back on doneloadingnextsong because playlist courses reset this for w.e reason -mina
        screen = SCREENMAN:GetTopScreen()

        -- nil checks are needed because these don't exist when doneloadingnextsong is sent initially
        -- which is convenient for us since addy -mina
        if screen ~= nil and screen:GetChild("PlayerP1") ~= nil then
            Notefield = screen:GetChild("PlayerP1"):GetChild("NoteField")
            Notefield:addy(MovableValues.NotefieldY * (usingReverse and 1 or -1))
        end
        -- update all stats in gameplay (as if it was a reset) when loading a new song
        -- particularly for playlists
        self:playcommand("PracticeModeReset")
    end,
    JudgmentMessageCommand = function(self, msg)
        tDiff = msg.WifeDifferential
        wifey = Floor(msg.WifePercent * 100) / 100
        jdgct = msg.Val

        if msg.Offset ~= nil then
            dvCur = msg.Offset
            offsets[#offsets + 1] = dvCur

            local offset = math.abs(dvCur)

        else
            dvCur = nil
        end
        if msg.WifePBGoal ~= nil and targetTrackerMode ~= 0 then
            pbtarget = msg.WifePBGoal
            tDiff = msg.WifePBDifferential
        end
        jdgCur = msg.Judgment
        judgmentsHit[jdgCur] = msg.Val
        self:playcommand("SpottedOffset", msg)
    end,
    PracticeModeResetMessageCommand = function(self)
        judgmentsHit = {}
        offsets = {}
        tDiff = 0
        wifey = 0
        jdgct = 0
        dvCur = nil
        jdgCur = nil
        self:playcommand("SpottedOffset")
    end
}

-- lifebard
t[#t + 1] = Def.ActorFrame {
    Name = "LifeP1",
    MovableBorder(200, 5, 1, -35, 0)
}
--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
																	**LaneCover**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	Old scwh lanecover back for now. Equivalent to "screencutting" on ffr; essentially hides notes for a fixed distance before they appear
on screen so you can adjust the time arrows display on screen without modifying their spacing from each other.
]]
if playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).LaneCover then
    t[#t + 1] = LoadActor("lanecover")
end

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 					    	**Player Target Differential: Ghost target rewrite, average score gone for now**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	Point differential to AA.
]]
-- Mostly clientside now. We set our desired target goal and listen to the results rather than calculating ourselves.
local target = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).TargetGoal
GAMESTATE:GetPlayerState():SetTargetGoal(target / 100)

-- We can save space by wrapping the personal best and set percent trackers into one function, however
-- this would make the actor needlessly cumbersome and unnecessarily punish those who don't use the
-- personal best tracker (although everything is efficient enough now it probably wouldn't matter)

-- moved it for better manipulation
local d = Def.ActorFrame {
    Name = "TargetTracker",
    InitCommand = function(self)
        if (allowedCustomization) then
            Movable.DeviceButton_7.element = self
            Movable.DeviceButton_8.element = self
            Movable.DeviceButton_8.Border = self:GetChild("Border")
            Movable.DeviceButton_7.condition = enabledTargetTracker
            Movable.DeviceButton_8.condition = enabledTargetTracker
        end
        self:xy(MovableValues.TargetTrackerX, MovableValues.TargetTrackerY):zoom(MovableValues.TargetTrackerZoom)
    end,
    MovableBorder(100, 13, 1, 0, 0)
}

if targetTrackerMode == 0 then
    d[#d + 1] = LoadFont("Common Normal") .. {
        Name = "PercentDifferential",
        InitCommand = function(self)
            self:halign(0):valign(1)
            if allowedCustomization then
                self:settextf("%5.2f (%5.2f%%)", -100, 100)
                setBorderAlignment(self:GetParent():GetChild("Border"), 0, 1)
                setBorderToText(self:GetParent():GetChild("Border"), self)
            end
            self:settextf("")
        end,
        SpottedOffsetCommand = function(self)
            if tDiff >= 0 then
                diffuse(self, positive)
            else
                diffuse(self, negative)
            end
            self:settextf("%5.2f (%5.2f%%)", tDiff, target)
        end
    }
else
    d[#d + 1] = LoadFont("Common Normal") .. {
        Name = "PBDifferential",
        InitCommand = function(self)
            self:halign(0):valign(1)
            if allowedCustomization then
                self:settextf("%5.2f (%5.2f%%)", -100, 100)
                setBorderAlignment(self:GetParent():GetChild("Border"), 0, 1)
                setBorderToText(self:GetParent():GetChild("Border"), self)
            end
            self:settextf("")
        end,
        SpottedOffsetCommand = function(self, msg)
            if pbtarget then
                if tDiff >= 0 then
                    diffuse(self, color("#00ff00"))
                else
                    diffuse(self, negative)
                end
                self:settextf("%5.2f (%5.2f%%)", tDiff, pbtarget * 100)
            else
                if tDiff >= 0 then
                    diffuse(self, positive)
                else
                    diffuse(self, negative)
                end
                self:settextf("%5.2f (%5.2f%%)", tDiff, target)
            end
        end
    }
end

if enabledTargetTracker then
    t[#t + 1] = d
end

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 					    									**Display Percent**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	Displays the current percent for the score.
]]
-- local cp = Def.ActorFrame {
--     Name = "DisplayPercent",
--     InitCommand = function(self)
--         if (allowedCustomization) then
--             Movable.DeviceButton_w.element = self
--             Movable.DeviceButton_e.element = self
--             Movable.DeviceButton_w.condition = enabledDisplayPercent
--             Movable.DeviceButton_e.condition = enabledDisplayPercent
--             Movable.DeviceButton_w.Border = self:GetChild("Border")
--             Movable.DeviceButton_e.Border = self:GetChild("Border")
--         end
--         self:zoom(MovableValues.DisplayPercentZoom):x(MovableValues.DisplayPercentX):y(MovableValues.DisplayPercentY)
--     end,
--     Def.Quad {
--         InitCommand = function(self)
--             self:zoomto(60, 13):diffuse(color("0,0,0,0.4")):halign(1):valign(0)
--         end
--     },
--     -- Displays your current percentage score
--     LoadFont("Common Large") .. {
--         Name = "DisplayPercent",
--         InitCommand = function(self)
--             self:zoom(0.3):halign(1):valign(0)
--         end,
--         OnCommand = function(self)
--             if allowedCustomization then
--                 self:settextf("%05.2f%%", -10000)
--                 setBorderAlignment(self:GetParent():GetChild("Border"), 1, 0)
--                 setBorderToText(self:GetParent():GetChild("Border"), self)
--             end
--             self:settextf("%05.2f%%", 0)
--         end,
--         SpottedOffsetCommand = function(self)
--             self:settextf("%05.2f%%", wifey)
--         end
--     },
--     MovableBorder(100, 13, 1, 0, 0)
-- }

-- if enabledDisplayPercent then
--     t[#t + 1] = cp
-- end

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
														    	**BPM Display**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	Better optimized frame update bpm display.
]]

-- local BPM
-- local a = GAMESTATE:GetPlayerState():GetSongPosition()
-- local r = GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate() * 60
-- local GetBPS = SongPosition.GetCurBPS

-- local function UpdateBPM(self)
-- 	local bpm = GetBPS(a) * r
-- 	settext(BPM, "BPM " .. Round(bpm, 2))
-- end

-- t[#t + 1] =
-- 	Def.ActorFrame {
-- 	Name = "BPMText",
-- 	InitCommand = function(self)
-- 		if (allowedCustomization) then
-- 			Movable.DeviceButton_x.element = self
-- 			Movable.DeviceButton_c.element = self
-- 			Movable.DeviceButton_x.condition = true
-- 			Movable.DeviceButton_c.condition = true
-- 			Movable.DeviceButton_x.Border = self:GetChild("Border")
-- 			Movable.DeviceButton_c.Border = self:GetChild("Border")
-- 		end
-- 		self:x(MovableValues.BPMTextX):y(MovableValues.BPMTextY):zoom(MovableValues.BPMTextZoom)
-- 		BPM = self:GetChild("BPM")
-- 		if #GAMESTATE:GetCurrentSong():GetTimingData():GetBPMs() > 1 then -- dont bother updating for single bpm files
-- 			self:SetUpdateFunction(UpdateBPM)
-- 			self:SetUpdateRate(0.5)
-- 		else
-- 			BPM:settextf("BPM %5.2f", GetBPS(a) * r) -- i wasn't thinking when i did this, we don't need to avoid formatting for performance because we only call this once -mina
-- 		end
-- 	end,
-- 	LoadFont("Common Normal") ..
-- 		{
-- 			Name = "BPM",
-- 			InitCommand = function(self)
-- 				self:halign(0.5):zoom(0.40)
-- 			end,
-- 			OnCommand = function(self)
-- 				if allowedCustomization then
-- 					setBorderToText(self:GetParent():GetChild("Border"), self)
-- 				end
-- 			end
-- 		},
-- 	DoneLoadingNextSongMessageCommand = function(self)
-- 		self:queuecommand("Init")
-- 	end,
-- 	-- basically a copy of the init
-- 	CurrentRateChangedMessageCommand = function(self)
-- 		r = GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate() * 60
-- 		if #GAMESTATE:GetCurrentSong():GetTimingData():GetBPMs() > 1 then
-- 			self:SetUpdateFunction(UpdateBPM)
-- 			self:SetUpdateRate(0.5)
-- 		else
-- 			BPM:settextf("BPM %5.2f", GetBPS(a) * r)
-- 		end
-- 	end,
-- 	PracticeModeReloadMessageCommand = function(self)
-- 		self:playcommand("CurrentRateChanged")
-- 	end,
-- 	MovableBorder(40, 13, 1, 0, 0)
-- }

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
											    	**Player Score Tracker (replacement for pa counter)**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--]]

local scoreTitleSize = 0.3
local scoreValueSize = 0.3
local scoreElementSpacing = 10
local scoreFrameWidth = 90
local scoreFrameHeight -- initialized later
local scoresTracked = {}
local genericTitleColor = "#C7CEEA"

-- possible feature: scale judgments hit to fit a bar like eval screen?

-- base methods

local function insertElement(name, actorElement)
    actorElement.Name = name
    scoresTracked[#scoresTracked + 1] = {
        Name = name,
        Actor = actorElement
    }
end

local function appendToElement(name, actorElement)

    local appendTo = scoresTracked[name]

    appendTo[#appendTo + 1] = actorElement
end

local function textElement(size, text, hexColor, halignment, xOffset, yOffset)
    return LoadFont("Common normal") .. {
        ResetTextCommand = function(self)
            settext(self, text)
        end,
        InitCommand = function(self)
            Zoomm(self, size)
            diffuse(self, color(hexColor))
            self:halign(halignment)
        end,
        DoneLoadingNextSongMessageCommand = function(self)
            self:queuecommand("ResetText")
        end,
        HandleSetPositionCommand = function(self, params)

            local x = self:GetHAlign() == 1 and scoreFrameWidth / 2 - 5 or -scoreFrameWidth / 2 + 5
            local y = -scoreFrameHeight / 2 + (params["index"] * scoreElementSpacing)

            if xOffset ~= nil then
                x = x + xOffset
            end

            if yOffset ~= nil then
                y = y + yOffset
            end

            self:xy(x, y)
        end
    }
end

local function spottedOffsetTrackerElement(title, initialValue, titleColor, valueColor, trackData)
    return Def.ActorFrame {
        textElement(scoreTitleSize, title, titleColor, 0),
        textElement(scoreValueSize, initialValue, valueColor, 1) .. {
            PracticeModeResetMessageCommand = function(self)
                self:queuecommand("ResetText")
            end,
            SpottedOffsetCommand = function(self, params)

                local count = trackData.CountFunction(params)

                if count == nil then
                    return
                end

                trackData.SetTextFunction(self, count)
            end
        }
    }

end

-- Accuracy

insertElement("Accuracy", spottedOffsetTrackerElement("Accuracy", "0%", genericTitleColor, "#bfd2d9", {
    CountFunction = function()
        return wifey
    end,
    SetTextFunction = function(self, count)
        self:settextf("%05.2f%%", count)
    end
}))

-- judgments hit

for i = 1, #jdgT do
    local color = colorConfig:get_data().judgment[jdgT[i]]

    insertElement(i, spottedOffsetTrackerElement(getShortJudgeStrings(jdgT[i]), "0", color, "#baa6a5", {
        CountFunction = function(self)
            return judgmentsHit[jdgT[i]]
        end,
        SetTextFunction = settext
    }))
end

-- Judge

insertElement("Judge", Def.ActorFrame {
    textElement(scoreTitleSize, "Judge", genericTitleColor, 0),
    textElement(scoreValueSize, "J" .. GetTimingDifficulty(), "#EFBE7D", 1)
})

-- Rate

insertElement("Rate", Def.ActorFrame {
    textElement(scoreTitleSize, "Rate", genericTitleColor, 0),
    textElement(scoreValueSize, "", "#FEE1E8", 1) .. {
        ResetTextCommand = function(self)
            settext(self, string.gsub(getCurRateDisplayString(), "Music", ""))
        end,
        CurrentRateChangedMessageCommand = function(self)
            self:queuecommand("ResetText")
        end
    }
})

-- bpm

local a = GAMESTATE:GetPlayerState():GetSongPosition()
local GetBPS = SongPosition.GetCurBPS

insertElement("BPM", Def.ActorFrame {
    textElement(scoreTitleSize, "BPM", genericTitleColor, 0),
    textElement(scoreValueSize, "0", "#FEE1E8", 1) .. {
        Name = "BPMValue",
        InitCommand = function(self)

            local r = GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate() * 60
            local parent = self:GetParent()

            local function updateBPM()
                local bpm = GetBPS(a) * r
                settext(self, Round(bpm, 2))
            end

            if #GAMESTATE:GetCurrentSong():GetTimingData():GetBPMs() > 1 then
                parent:SetUpdateFunction(updateBPM)
                parent:SetUpdateRate(0.5)
            else
                updateBPM()
            end
        end,
        CurrentRateChangedMessageCommand = function(self)
            self:queuecommand("Init")
        end,
        DoneLoadingNextSongMessageCommand = function(self)
            self:queuecommand("Init")
        end
    }
})

-- Song Left

insertElement("SongLeft", Def.ActorFrame {
    textElement(scoreTitleSize, "Song Left", genericTitleColor, 0),
    textElement(scoreValueSize, "100.00%", "#c8e1cc", 1) .. {
        DoneLoadingNextSongMessageCommand = function(self)

            local lastSecond = GAMESTATE:GetCurrentSteps():GetLastSecond()
            local parent = self:GetParent()

            local function updateSongLeft()

                local remainingPercent = 100 - math.min(math.max(0, GAMESTATE:GetCurMusicSeconds() / lastSecond), 1) *
                                             100.0

                self:settextf("%.2f%%", remainingPercent)
            end

            parent:SetUpdateFunction(updateSongLeft)
            parent:SetUpdateRate(1 / (60 / 4))
        end
    }
})

-- MA/PA

local function ratioTrackerElement(title, titleColor, valueColor, judgeFunctions)
    insertElement(title, spottedOffsetTrackerElement(title, "nan:1", titleColor, valueColor, {
        CountFunction = function()

            local countA = judgeFunctions.JudgeA()
            local countB = judgeFunctions.JudgeB()

            if countA == nil or countB == nil then
                return nil
            end

            return countA / countB
        end,
        SetTextFunction = function(self, count)

            if count == nil then
                return
            end

            self:settextf("%.1f:1", count)
        end
    }))
end

ratioTrackerElement("MA", genericTitleColor, "#A3E1DC", {
    JudgeA = function()
        return judgmentsHit["TapNoteScore_W1"]
    end,
    JudgeB = function()
        return judgmentsHit["TapNoteScore_W2"]
    end
})

ratioTrackerElement("PA", genericTitleColor, "#F6EAC2", {
    JudgeA = function()
        return judgmentsHit["TapNoteScore_W2"]
    end,
    JudgeB = function()
        return judgmentsHit["TapNoteScore_W3"]
    end
})

-- Mean/SD

local function msTrackerElement(title, titleColor, valueColor, func)
    insertElement(title, spottedOffsetTrackerElement(title, "0.00ms", titleColor, valueColor, {
        CountFunction = function()
            return func(offsets)
        end,
        SetTextFunction = function(self, count)
            self:settextf("%.2fms", count)
        end
    }))
end

msTrackerElement("Mean", genericTitleColor, "#EDEAE5", wifeMean)
msTrackerElement("SD", genericTitleColor, "#DFCCF1", wifeSd)

-- marv combo

local acceptedTaps = {
    TapNoteScore_W1 = true,
    TapNoteScore_W2 = true,
}


local scopedCombo = 0

insertElement("ScopedCombo",
    spottedOffsetTrackerElement("MA/PR Combo", "0", genericTitleColor,
        "#A8CCDD", {
            CountFunction = function(params)
                scopedCombo = (params == nil or not acceptedTaps[params.Judgment]) and 0 or scopedCombo + 1
                return scopedCombo
            end,
            SetTextFunction = settext
        }))

-- building the board

scoreFrameHeight = (#scoresTracked + 1) * scoreElementSpacing

local scoreTracker = Def.ActorFrame {
    InitCommand = function(self)
        if (allowedCustomization) then
            Movable.DeviceButton_p.element = self
            Movable.DeviceButton_p.condition = enabledJudgeCounter
        end
        self:xy(MovableValues.JudgeCounterX, MovableValues.JudgeCounterY)
    end,
    OnCommand = function(self)

        local i = 0

        for _, v in pairs(scoresTracked) do
            i = i + 1
            self:GetChild(v.Name):playcommand("HandleSetPosition", {
                index = i
            })
        end

        scoresTracked = nil -- not needed anymore
    end,
    Def.Quad {
        InitCommand = function(self)
            self:zoomto(scoreFrameWidth, scoreFrameHeight):diffuse(color("0,0,0,0.4"))
        end
    },
    MovableBorder(scoreFrameWidth, scoreFrameHeight, 1, 0, 0)
}

for _, v in pairs(scoresTracked) do
    scoreTracker[#scoreTracker + 1] = v.Actor
end

if enabledJudgeCounter then
    t[#t + 1] = scoreTracker
else
    scoresTracked = nil
end

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
											    	**Player judgment counter (aka pa counter)**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	Counts judgments.
--]]
-- User Parameters
-- ==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
-- local spacing = 10 -- Spacing between the judgetypes
-- local frameWidth = 85 -- Width of the Frame
-- local frameHeight = ((#jdgT + 1) * spacing) -- Height of the Frame
-- local judgeFontSize = 0.40 -- Font sizes for different text elements
-- local countFontSize = 0.35
-- local gradeFontSize = 0.45
-- -- ==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

-- local j = Def.ActorFrame {
--     Name = "JudgeCounter",
--     InitCommand = function(self)
--         if (allowedCustomization) then
--             Movable.DeviceButton_p.element = self
--             Movable.DeviceButton_p.condition = enabledJudgeCounter
--         end
--         self:xy(MovableValues.JudgeCounterX, MovableValues.JudgeCounterY)
--     end,
--     OnCommand = function(self)
--         for i = 1, #jdgT do
--             jdgCounts[jdgT[i]] = self:GetChild(jdgT[i])
--         end
--     end,
--     SpottedOffsetCommand = function(self, msg)

--         if jdgCur then

--             if jdgCounts[jdgCur] ~= nil then
--                 settext(jdgCounts[jdgCur], jdgct)
--             end

--             for i = 1, #customs do
--                 jdgCounts[customs[i]]:playcommand("HandleSpottedOffset", msg)
--             end

--         end
--     end,
--     Def.Quad {
--         -- bg
--         InitCommand = function(self)
--             self:zoomto(frameWidth, frameHeight):diffuse(color("0,0,0,0.4"))
--         end
--     },
--     MovableBorder(frameWidth, frameHeight, 1, 0, 0)
-- }

-- local function makeJudgeText(judge, index) -- Makes text
--     return LoadFont("Common normal") .. {
--         InitCommand = function(self)
--             self:xy(-frameWidth / 2 + 5, -frameHeight / 2 + (index * spacing)):zoom(judgeFontSize):halign(0)
--         end,
--         OnCommand = function(self)
--             settext(self, getShortJudgeStrings(judge))
--             diffuse(self, jcT[judge])
--         end
--     }
-- end

-- local function makeJudgeCount(judge, index) -- Makes county things for taps....
--     return LoadFont("Common Normal") .. {
--         Name = judge,
--         InitCommand = function(self)
--             self:xy(frameWidth / 2 - 5, -frameHeight / 2 + (index * spacing)):zoom(countFontSize):halign(1):settext(0)
--                 :diffuse(color("#baa6a5"))
--         end,
--         PracticeModeResetMessageCommand = function(self)
--             self:settext(0)
--         end
--     }
-- end

-- -- Build judgeboard
-- for i = 1, #jdgT do
--     j[#j + 1] = makeJudgeText(jdgT[i], i)
--     j[#j + 1] = makeJudgeCount(jdgT[i], i)
-- end

-- local function insertCustomNew(name)

--     index = #jdgT + 1
--     jdgT[#jdgT + 1] = name
--     customs[#customs + 1] = name

--     judgeText = makeJudgeText(name, index)
--     judgeCount = makeJudgeCount(name, index)

--     judgeText.OnCommand = function(self)
--         self:diffuse(color("#C7CEEA"))
--         self:zoom(judgeFontSize - 0.07)
--         self:playcommand("OnCustom")
--     end

--     judgeCount.OnCommand = function(self)
--         self:playcommand("OnCustom")
--     end

--     j[#j + 1] = judgeText
--     j[#j + 1] = judgeCount

--     return judgeText, judgeCount
-- end

-- local periodicUpdates = {}

-- local function periodicUpdate(self)

--     local periodicUpdateData = periodicUpdates[self:GetName()]
--     local newValue = periodicUpdateData.Current()

--     if newValue ~= newValue or (newValue == math.huge or newValue == -math.huge) then
--         return
--     end

--     local last = periodicUpdateData.LastValue
--     local change = math.abs(newValue - last)
--     local text = self:GetChild("Text")

--     if newValue > last then
--         text:settextf("+%.2f", change)
--     else
--         text:settextf("-%.2f", change)
--     end

--     periodicUpdateData.LastValue = newValue
-- end

-- local function insertPeriodicDifferenceUpdate(judge, valueFunctions)

--     local newName = judge .. "updater"

--     periodicUpdates[newName] = {
--         Current = valueFunctions.Current,
--         LastValue = 0
--     }

--     j[#j + 1] = Def.ActorFrame {
--         Name = newName,
--         InitCommand = function(self)
--             self:SetUpdateFunction(periodicUpdate)
--             self:SetUpdateRate(1 / (60 * 5)) -- every 5 seconds
--         end,
--         LoadFont("Common normal") .. {
--             Name = "Text",
--             InitCommand = function(self)
--                 self:zoom(countFontSize - 0.08):halign(1):diffuse(color("#ab8e8c"))
--                 self:xy(self:GetParent():GetParent():GetChild(judge):GetX() + 25,
--                     self:GetParent():GetParent():GetChild(judge):GetY())
--             end
--         }
--     }

-- end

-- -- Judge
-- local text, count = insertCustomNew("Judge")

-- text.OnCustomCommand = function(self)
--     settext(self, "Judge")
-- end

-- count.OnCustomCommand = function(self)
--     diffuse(self, color("#EFBE7D"))
--     Zoomm(self, countFontSize - 0.05)
--     self:settextf("J%s", GetTimingDifficulty())
-- end
-- -- Judge

-- -- Rate
-- local text, count = insertCustomNew("bpm")

-- text.OnCustomCommand = function(self)
--     settext(self, "Rate")
-- end

-- count.OnCustomCommand = function(self)
--     Zoomm(self, countFontSize - 0.05)
--     settext(self, string.gsub(getCurRateDisplayString(), "Music", "")):diffuse(color("#FEE1E8"))
-- end

-- count.DoneLoadingNextSongMessageCommand = function(self)
--     playcommand(self, "On")
-- end

-- count.CurrentRateChangedMessageCommand = function(self)
--     playcommand(self, "On")
-- end

-- count.PracticeModeResetMessageCommand = function(self)
--     playcommand(self, "On")
-- end
-- -- Rate

-- -- BPM
-- local text, count = insertCustomNew("bpm")
-- local a = GAMESTATE:GetPlayerState():GetSongPosition()
-- local r = GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate() * 60
-- local GetBPS = SongPosition.GetCurBPS

-- function updateCustomBPM()
--     if toUpdate ~= nil then
--         local bpm = GetBPS(a) * r
--         toUpdate:settext(Round(bpm, 2))
--     end
-- end

-- t[#t + 1] = Def.ActorFrame {
--     InitCommand = function(self)
--         updater = self
--     end
-- }

-- text.OnCustomCommand = function(self)
--     settext(self, "BPM")
-- end

-- count.OnCustomCommand = function(self)
--     Zoomm(self, countFontSize - 0.05)
--     diffuse(self, color("#FEE1E8"))
-- end

-- count.DoneLoadingNextSongMessageCommand = function(self)
--     toUpdate = self
--     queuecommand(self, "TheThing")
-- end

-- count.TheThingCommand = function(self)
--     if #GAMESTATE:GetCurrentSong():GetTimingData():GetBPMs() > 1 then
--         updater:SetUpdateFunction(updateCustomBPM)
--         updater:SetUpdateRate(0.5)
--     else
--         updateCustomBPM()
--     end
-- end

-- count.CurrentRateChangedMessageCommand = function(self)
--     toUpdate = self
--     r = GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate() * 60
--     updateCustomBPM(self)
-- end

-- count.PracticeModeResetMessageCommand = function(self)
--     playcommand(self, "CurrentRateChanged")
-- end
-- -- BPM

-- -- Song Percent

-- local text, count = insertCustomNew("songpercent")
-- local percentUpdater
-- local percentToUpdate

-- text.OnCustomCommand = function(self)
--     settext(self, "Song Left")
-- end

-- count.OnCustomCommand = function(self)
--     Zoomm(self, countFontSize - 0.05)
--     diffuse(self, color("#c8e1cc"))
-- end

-- local lastSecond

-- function updateSongPercent(self)
--     if percentToUpdate == nil then
--         return
--     end

--     percentToUpdate:settextf("%.2f%%",
--         100 - math.min(math.max(0, GAMESTATE:GetCurMusicSeconds() / lastSecond), 1) * 100.0)
-- end

-- t[#t + 1] = Def.ActorFrame {
--     InitCommand = function(self)
--         percentUpdater = self
--     end
-- }

-- count.DoneLoadingNextSongMessageCommand = function(self)
--     lastSecond = GAMESTATE:GetCurrentSteps():GetLastSecond()
--     percentToUpdate = self
--     percentUpdater:SetUpdateFunction(updateSongPercent)
--     percentUpdater:SetUpdateRate(1 / (60 / 4))
-- end

-- -- Song Percent

-- -- accuracy

-- local text, count = insertCustomNew("accuracy")

-- text.OnCustomCommand = function(self)
--     settext(self, "Accuracy")
--     -- Zoomm(self, countFontSize - 0.04)
-- end

-- count.OnCustomCommand = function(self)
--     Zoomm(self, countFontSize - 0.05)
--     diffuse(self, color("#bfd2d9"))
-- end

-- count.HandleSpottedOffsetCommand = function(self)
--     self:settextf("%05.2f%%", wifey)
-- end

-- -- accuracy

-- -- MA
-- local text, count = insertCustomNew("MA")

-- text.OnCustomCommand = function(self)
--     settext(self, "MA")
-- end

-- count.OnCustomCommand = function(self)
--     diffuse(self, color("#A3E1DC"))
--     Zoomm(self, countFontSize - 0.05)
-- end

-- count.HandleSpottedOffsetCommand = function(self)
--     self:settextf("%.1f:1", marv / perfect)
-- end

-- insertPeriodicDifferenceUpdate("MA", {
--     Current = function()
--         return marv / perfect
--     end
-- })

-- -- PA
-- local text, count = insertCustomNew("PA")

-- text.OnCustomCommand = function(self)
--     settext(self, "PA")
-- end

-- count.OnCustomCommand = function(self)
--     diffuse(self, color("#F6EAC2"))
--     Zoomm(self, countFontSize - 0.05)
-- end

-- count.HandleSpottedOffsetCommand = function(self)
--     self:settextf("%.1f:1", perfect / great)
-- end

-- insertPeriodicDifferenceUpdate("PA", {
--     Current = function()
--         return perfect / great
--     end
-- })

-- -- Mean
-- local text, count = insertCustomNew("Mean")

-- count.HandleSpottedOffsetCommand = function(self)
--     self:settextf("%5.2fms", wifeMean(offsets))
-- end

-- count.OnCustomCommand = function(self)
--     diffuse(self, color("#EDEAE5"))
--     Zoomm(self, countFontSize - 0.05)
-- end

-- text.OnCustomCommand = function(self)
--     settext(self, "Mean")
-- end

-- insertPeriodicDifferenceUpdate("Mean", {
--     Current = function()
--         return wifeMean(offsets)
--     end
-- })

-- -- Mean

-- -- SD
-- local text, count = insertCustomNew("SD")

-- count.HandleSpottedOffsetCommand = function(self)
--     self:settextf("%5.2fms", wifeSd(offsets))
-- end

-- count.OnCustomCommand = function(self)
--     diffuse(self, color("#DFCCF1"))
--     Zoomm(self, countFontSize - 0.05)
-- end

-- text.OnCustomCommand = function(self)
--     settext(self, "SD")
-- end

-- insertPeriodicDifferenceUpdate("SD", {
--     Current = function()
--         return wifeSd(offsets)
--     end
-- })

-- -- Marv Combo

-- local text, count = insertCustomNew("MarvCombo")
-- local marvCombo = 0

-- text.OnCustomCommand = function(self)
--     settext(self, "Marv Combo")
--     Zoomm(self, judgeFontSize - 0.1)
-- end

-- count.OnCustomCommand = function(self)
--     diffuse(self, byJudgment("TapNoteScore_W1"))
--     Zoomm(self, countFontSize - 0.05)
-- end

-- count.HandleSpottedOffsetCommand = function(self, msg)

--     if msg.Judgment ~= "TapNoteScore_W1" then
--         marvCombo = 0
--     else
--         marvCombo = marvCombo + 1
--     end

--     settext(self, marvCombo)
-- end

-- -- SD

-- -- Now add the completed judgment table to the primary actor frame t if enabled
-- if enabledJudgeCounter then
--     t[#t + 1] = j
-- end

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
														    	**Player ErrorBar**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	Visual display of deviance MovableValues.
--]]
-- User Parameters
-- ==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
local barcount = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).ErrorBarCount -- Number of bars. Older bars will refresh if judgments/barDuration exceeds this value.
local barWidth = 2 -- Width of the ticks.
local barDuration = 0.75 -- Time duration in seconds before the ticks fade out. Doesn't need to be higher than 1. Maybe if you have 300 bars I guess.
if barcount > 50 then
    barDuration = barcount / 50
end -- just procedurally set the duration if we pass 50 bars
-- ==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
local currentbar = 1 -- so we know which error bar we need to update
local ingots = {} -- references to the error bars
local alpha = 0.07 -- ewma alpha
local avg
local lastAvg

-- Makes the error bars. They position themselves relative to the center of the screen based on your dv and diffuse to your judgment value before disappating or refreshing
-- Should eventually be handled by the game itself to optimize performance
function smeltErrorBar(index)
    return Def.Quad {
        Name = index,
        InitCommand = function(self)
            self:xy(MovableValues.ErrorBarX, MovableValues.ErrorBarY):zoomto(barWidth, MovableValues.ErrorBarHeight)
                :diffusealpha(0)
        end,
        UpdateErrorBarCommand = function(self) -- probably a more efficient way to achieve this effect, should test stuff later
            finishtweening(self) -- note: it really looks like shit without the fade out
            diffusealpha(self, 1)
            diffuse(self, jcT[jdgCur])
            if MovableValues and MovableValues.ErrorBarX then
                x(self, MovableValues.ErrorBarX + dvCur * wscale)
                y(self, MovableValues.ErrorBarY)
                Zoomtoheight(self, MovableValues.ErrorBarHeight)
            end
            linear(self, barDuration)
            diffusealpha(self, 0)
        end,
        PracticeModeResetMessageCommand = function(self)
            diffusealpha(self, 0)
        end
    }
end

local e = Def.ActorFrame {
    Name = "ErrorBar",
    InitCommand = function(self)
        if (allowedCustomization) then
            Movable.DeviceButton_5.element = self:GetChildren()
            Movable.DeviceButton_6.element = self:GetChildren()
            Movable.DeviceButton_5.condition = enabledErrorBar ~= 0
            Movable.DeviceButton_6.condition = enabledErrorBar ~= 0
            Movable.DeviceButton_5.Border = self:GetChild("Border")
            Movable.DeviceButton_6.Border = self:GetChild("Border")
            Movable.DeviceButton_6.DeviceButton_left.arbitraryFunction = arbitraryErrorBarValue
            Movable.DeviceButton_6.DeviceButton_right.arbitraryFunction = arbitraryErrorBarValue
        end
        if enabledErrorBar == 1 then
            for i = 1, barcount do -- basically the equivalent of using GetChildren() if it returned unnamed children numerically indexed
                ingots[#ingots + 1] = self:GetChild(i)
            end
        else
            avg = 0
            lastAvg = 0
        end
    end,
    SpottedOffsetCommand = function(self)
        if enabledErrorBar == 1 then
            if dvCur ~= nil then
                currentbar = ((currentbar) % barcount) + 1
                ingots[currentbar]:playcommand("UpdateErrorBar") -- Update the next bar in the queue
            end
        end
    end,
    DootCommand = function(self)
        self:RemoveChild("DestroyMe")
        self:RemoveChild("DestroyMe2")

        -- basically we need the ewma version to exist inside this actor frame
        -- for customize gameplay stuff, however it seems silly to have it running
        -- visibility/nil/type checks if we aren't using it, so we can just remove
        -- it if we're outside customize gameplay and errorbar is set to normal -mina
        if not allowedCustomization and enabledErrorBar == 1 then
            self:RemoveChild("WeightedBar")
        end
    end,
    Def.Quad {
        Name = "WeightedBar",
        InitCommand = function(self)
            if enabledErrorBar == 2 then
                self:xy(MovableValues.ErrorBarX, MovableValues.ErrorBarY):zoomto(barWidth, MovableValues.ErrorBarHeight)
                    :diffusealpha(1):diffuse(getMainColor("enabled"))
            else
                self:visible(false)
            end
        end,
        SpottedOffsetCommand = function(self)
            if enabledErrorBar == 2 and dvCur ~= nil then
                avg = alpha * dvCur + (1 - alpha) * lastAvg
                lastAvg = avg
                self:x(MovableValues.ErrorBarX + avg * wscale)
            end
        end
    },
    Def.Quad {
        Name = "Center",
        InitCommand = function(self)
            self:diffuse(getMainColor("highlight")):xy(MovableValues.ErrorBarX, MovableValues.ErrorBarY):zoomto(2,
                MovableValues.ErrorBarHeight)
        end
    },
    -- Indicates which side is which (early/late) These should be destroyed after the song starts.
    LoadFont("Common Normal") .. {
        Name = "DestroyMe",
        InitCommand = function(self)
            self:xy(MovableValues.ErrorBarX + errorBarFrameWidth / 4, MovableValues.ErrorBarY):zoom(0.35)
        end,
        BeginCommand = function(self)
            self:settext(translated_info["ErrorLate"])
            self:diffusealpha(0):smooth(0.5):diffusealpha(0.5):sleep(1.5):smooth(0.5):diffusealpha(0)
        end
    },
    LoadFont("Common Normal") .. {
        Name = "DestroyMe2",
        InitCommand = function(self)
            self:xy(MovableValues.ErrorBarX - errorBarFrameWidth / 4, MovableValues.ErrorBarY):zoom(0.35)
        end,
        BeginCommand = function(self)
            self:settext(translated_info["ErrorEarly"])
            self:diffusealpha(0):smooth(0.5):diffusealpha(0.5):sleep(1.5):smooth(0.5):diffusealpha(0):queuecommand(
                "Doot")
        end,
        DootCommand = function(self)
            self:GetParent():queuecommand("Doot")
        end
    },
    MovableBorder(MovableValues.ErrorBarWidth, MovableValues.ErrorBarHeight, 1, MovableValues.ErrorBarX,
        MovableValues.ErrorBarY)
}

-- Initialize bars
if enabledErrorBar == 1 then
    for i = 1, barcount do
        e[#e + 1] = smeltErrorBar(i)
    end
end

-- Add the completed errorbar frame to the primary actor frame t if enabled
if enabledErrorBar ~= 0 then
    t[#t + 1] = e
end

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
															   **Player Info**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	Avatar and such, now you can turn it off. Planning to have player mods etc exported similarly to the nowplaying, and an avatar only option
]]
if playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).PlayerInfo then
    t[#t + 1] = LoadActor("playerinfo")
end

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
														       **Full Progressbar**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	Song Completion Meter that doesn't eat 100 fps. Courtesy of simply love. Decided to make the full progress bar and mini progress bar
separate entities. So you can have both, or one or the other, or neither.
]]
-- User params
-- ==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
local width = SCREEN_WIDTH / 2 - 100
local height = 10
local alpha = 0.7
-- ==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
local replaySlider = isReplay and Widg.SliderBase {
    width = width,
    height = height,
    min = GAMESTATE:GetCurrentSteps():GetFirstSecond(),
    visible = true,
    max = GAMESTATE:GetCurrentSteps():GetLastSecond(),
    onInit = function(slider)
        slider.actor:diffusealpha(0)
    end,
    -- Change to onValueChangeEnd if this
    -- lags too much
    onValueChange = function(val)
        SCREENMAN:GetTopScreen():SetSongPosition(val)
    end
} or Def.Actor {}
local p = Def.ActorFrame {
    Name = "FullProgressBar",
    InitCommand = function(self)
        self:xy(MovableValues.FullProgressBarX, MovableValues.FullProgressBarY)
        self:zoomto(MovableValues.FullProgressBarWidth, MovableValues.FullProgressBarHeight)
        if (allowedCustomization) then
            Movable.DeviceButton_9.element = self
            Movable.DeviceButton_0.element = self
            Movable.DeviceButton_9.condition = enabledFullBar
            Movable.DeviceButton_0.condition = enabledFullBar
        end
    end,
    replaySlider,
    Def.Quad {
        InitCommand = function(self)
            self:zoomto(width, height):diffuse(color("#666666")):diffusealpha(alpha)
        end
    },
    Def.SongMeterDisplay {
        InitCommand = function(self)
            self:SetUpdateRate(0.5)
        end,
        StreamWidth = width,
        Stream = Def.Quad {
            InitCommand = function(self)
                self:zoomy(height):diffuse(getMainColor("highlight"))
            end
        }
    },
    LoadFont("Common Normal") .. {
        -- title
        InitCommand = function(self)
            self:zoom(0.35):maxwidth(width * 2)
        end,
        BeginCommand = function(self)
            self:settext(GAMESTATE:GetCurrentSong():GetDisplayMainTitle())
        end,
        DoneLoadingNextSongMessageCommand = function(self)
            self:settext(GAMESTATE:GetCurrentSong():GetDisplayMainTitle())
        end,
        PracticeModeReloadMessageCommand = function(self)
            self:playcommand("Begin")
        end
    },
    LoadFont("Common Normal") .. {
        -- total time
        InitCommand = function(self)
            self:x(width / 2):zoom(0.35):maxwidth(width * 2):halign(1)
        end,
        BeginCommand = function(self)
            local ttime = GetPlayableTime()
            settext(self, SecondsToMMSS(ttime))
            diffuse(self, byMusicLength(ttime))
        end,
        DoneLoadingNextSongMessageCommand = function(self)
            local ttime = GetPlayableTime()
            settext(self, SecondsToMMSS(ttime))
            diffuse(self, byMusicLength(ttime))
        end,
        --- ???? uhhh
        CurrentRateChangedMessageCommand = function(self)
            local ttime = GetPlayableTime()
            settext(self, SecondsToMMSS(ttime))
            diffuse(self, byMusicLength(ttime))
        end,
        PracticeModeReloadMessageCommand = function(self)
            self:playcommand("CurrentRateChanged")
        end
    },
    MovableBorder(width, height, 1, 0, 0)
}

if enabledFullBar then
    t[#t + 1] = p
end

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
														      **Mini Progressbar**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	Song Completion Meter that doesn't eat 100 fps. Courtesy of simply love. Decided to make the full progress bar and mini progress bar
separate entities. So you can have both, or one or the other, or neither.
]]
local width = 34
local height = 4
local alpha = 0.3

local mb = Def.ActorFrame {
    Name = "MiniProgressBar",
    InitCommand = function(self)
        self:xy(MovableValues.MiniProgressBarX, MovableValues.MiniProgressBarY)
        if (allowedCustomization) then
            Movable.DeviceButton_q.element = self
            Movable.DeviceButton_q.condition = enabledMiniBar
            Movable.DeviceButton_q.Border = self:GetChild("Border")
        end
    end,
    Def.Quad {
        InitCommand = function(self)
            self:zoomto(width, height):diffuse(color("#666666")):diffusealpha(alpha)
        end
    },
    Def.Quad {
        InitCommand = function(self)
            self:x(1 + width / 2):zoomto(1, height):diffuse(color("#555555"))
        end
    },
    Def.SongMeterDisplay {
        InitCommand = function(self)
            self:SetUpdateRate(0.5)
        end,
        StreamWidth = width,
        Stream = Def.Quad {
            InitCommand = function(self)
                self:zoomy(height):diffuse(getMainColor("highlight"))
            end
        }
    },
    MovableBorder(width, height, 1, 0, 0)
}

if enabledMiniBar then
    t[#t + 1] = mb
end

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
														    	**Music Rate Display**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
]]

-- t[#t + 1] =
-- 	Def.ActorFrame {
-- 	Name = "MusicRate",
-- 	InitCommand = function(self)
-- 		if (allowedCustomization) then
-- 			Movable.DeviceButton_v.element = self
-- 			Movable.DeviceButton_b.element = self
-- 			Movable.DeviceButton_v.condition = true
-- 			Movable.DeviceButton_b.condition = true
-- 			Movable.DeviceButton_v.Border = self:GetChild("Border")
-- 			Movable.DeviceButton_b.Border = self:GetChild("Border")
-- 		end
-- 		self:xy(MovableValues.MusicRateX, MovableValues.MusicRateY):zoom(MovableValues.MusicRateZoom)
-- 	end,
-- 	LoadFont("Common Normal") ..
-- 	{
-- 		InitCommand = function(self)
-- 			self:zoom(0.35):settext(getCurRateDisplayString())
-- 		end,
-- 		OnCommand = function(self)
-- 			if allowedCustomization then
-- 				setBorderToText(self:GetParent():GetChild("Border"), self)
-- 			end
-- 		end,
-- 		SetRateCommand = function(self)
-- 			self:settext(getCurRateDisplayString())
-- 		end,
-- 		DoneLoadingNextSongMessageCommand = function(self)
-- 			self:playcommand("SetRate")
-- 		end,
-- 		CurrentRateChangedMessageCommand = function(self)
-- 			self:playcommand("SetRate")
-- 		end
-- 	},
-- 	MovableBorder(100, 13, 1, 0, 0)
-- }

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
															**Combo Display**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

]]
local x = 0
local y = 60

-- CUZ WIDESCREEN DEFAULTS SCREAAAAAAAAAAAAAAAAAAAAAAAAAM -mina
if IsUsingWideScreen() then
    y = y - WIDESCREENWHY
    x = x + WIDESCREENWHX
end

-- This just initializes the initial point or not idk not needed to mess with this any more
function ComboTransformCommand(self, params)
    self:x(x)
    self:y(y)
end

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
														  **Judgment Display**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	moving here eventually
]]
--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
															 **NPS Display**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	re-enabling the old nps calc/graph for now
]]
t[#t + 1] = LoadActor("npscalc")

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
															  **NPS graph**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	ditto
]]
--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
															  **Practice Mode**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	stuff
]]
local prevZoom = 0.65
local musicratio = 1

-- hurrrrr nps quadzapalooza -mina
local wodth = capWideScale(get43size(240 / 1.9), 280 / 1.9)
local hidth = 40
local cd
local loopStartPos
local loopEndPos

local function handleRegionSetting(positionGiven)
    -- don't allow a negative region 
    -- internally it is limited to -2
    -- the start delay is 2 seconds, so limit this to 0
    if positionGiven < 0 then
        return
    end

    -- first time starting a region
    if not loopStartPos and not loopEndPos then
        loopStartPos = positionGiven
        MESSAGEMAN:Broadcast("RegionSet")
        return
    end

    -- reset region to bookmark only if double right click
    if positionGiven == loopStartPos or positionGiven == loopEndPos then
        loopEndPos = nil
        loopStartPos = positionGiven
        MESSAGEMAN:Broadcast("RegionSet")
        SCREENMAN:GetTopScreen():ResetLoopRegion()
        return
    end

    -- measure the difference of the new pos from each end
    local startDiff = math.abs(positionGiven - loopStartPos)
    local endDiff = startDiff + 0.1
    if loopEndPos then
        endDiff = math.abs(positionGiven - loopEndPos)
    end

    -- use the diff to figure out which end to move

    -- if there is no end, then you place the end
    if not loopEndPos then
        if loopStartPos < positionGiven then
            loopEndPos = positionGiven
        elseif loopStartPos > positionGiven then
            loopEndPos = loopStartPos
            loopStartPos = positionGiven
        else
            -- this should never happen
            -- but if it does, reset to bookmark
            loopEndPos = nil
            loopStartPos = positionGiven
            MESSAGEMAN:Broadcast("RegionSet")
            SCREENMAN:GetTopScreen():ResetLoopRegion()
            return
        end
    else
        -- closer to the start, move the start
        if startDiff < endDiff then
            loopStartPos = positionGiven
        else
            loopEndPos = positionGiven
        end
    end
    SCREENMAN:GetTopScreen():SetLoopRegion(loopStartPos, loopEndPos)
    MESSAGEMAN:Broadcast("RegionSet", {
        loopLength = loopEndPos - loopStartPos
    })
end

local function duminput(event)
    if event.type == "InputEventType_Release" then
        if event.DeviceInput.button == "DeviceButton_right mouse button" then
            MESSAGEMAN:Broadcast("MouseRightClick")
        end
    elseif event.type == "InputEventType_FirstPress" then
        if event.DeviceInput.button == "DeviceButton_backspace" then
            if loopStartPos ~= nil then
                SCREENMAN:GetTopScreen():SetSongPositionAndUnpause(loopStartPos, 1, true)
            end
        elseif event.button == "EffectUp" then
            SCREENMAN:GetTopScreen():AddToRate(0.05)
        elseif event.button == "EffectDown" then
            SCREENMAN:GetTopScreen():AddToRate(-0.05)
        elseif event.button == "Coin" then
            handleRegionSetting(SCREENMAN:GetTopScreen():GetSongPosition())
        elseif event.DeviceInput.button == "DeviceButton_mousewheel up" then
            if GAMESTATE:IsPaused() then
                local pos = SCREENMAN:GetTopScreen():GetSongPosition()
                local dir = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions():UsingReverse() and 1 or -1
                local nextpos = pos + dir * 0.05
                if loopEndPos ~= nil and nextpos >= loopEndPos then
                    handleRegionSetting(nextpos + 1)
                end
                SCREENMAN:GetTopScreen():SetSongPosition(nextpos, 0, false)
            end
        elseif event.DeviceInput.button == "DeviceButton_mousewheel down" then
            if GAMESTATE:IsPaused() then
                local pos = SCREENMAN:GetTopScreen():GetSongPosition()
                local dir = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions():UsingReverse() and 1 or -1
                local nextpos = pos - dir * 0.05
                if loopEndPos ~= nil and nextpos >= loopEndPos then
                    handleRegionSetting(nextpos + 1)
                end
                SCREENMAN:GetTopScreen():SetSongPosition(nextpos, 0, false)
            end
        end
    end

    return false
end

local function UpdatePreviewPos(self)
    local pos = SCREENMAN:GetTopScreen():GetSongPosition() / musicratio
    self:GetChild("Pos"):zoomto(math.min(math.max(0, pos), wodth), hidth)
    self:queuecommand("Highlight")
end

local pm = Def.ActorFrame {
    Name = "ChartPreview",
    InitCommand = function(self)
        self:xy(MovableValues.PracticeCDGraphX, MovableValues.PracticeCDGraphY):diffusealpha(0.05)
        self:SetUpdateFunction(UpdatePreviewPos)
        cd = self:GetChild("ChordDensityGraph"):visible(true):draworder(1000):y(20)
        if (allowedCustomization) then
            Movable.DeviceButton_z.element = self
            Movable.DeviceButton_z.condition = practiceMode
        end
    end,
    BeginCommand = function(self)
        musicratio = GAMESTATE:GetCurrentSteps():GetLastSecond() / (wodth)
        SCREENMAN:GetTopScreen():AddInputCallback(duminput)
        cd:GetChild("cdbg"):diffusealpha(0)
        self:SortByDrawOrder()
        self:queuecommand("GraphUpdate")
    end,
    PracticeModeReloadMessageCommand = function(self)
        musicratio = GAMESTATE:GetCurrentSteps():GetLastSecond() / wodth
    end,
    Def.Quad {
        Name = "BG",
        InitCommand = function(self)
            self:x(wodth / 2)
            self:diffuse(color("0.05,0.05,0.05,1"))
        end
    },
    Def.Quad {
        Name = "PosBG",
        InitCommand = function(self)
            self:zoomto(wodth, hidth):halign(0):diffuse(color("1,1,1,1")):draworder(900)
        end,
        HighlightCommand = function(self) -- use the bg for detection but move the seek pointer -mina
            if isOver(self) then
                self:GetParent():diffusealpha(1)
                local seek = self:GetParent():GetChild("Seek")
                local seektext = self:GetParent():GetChild("Seektext")
                local cdg = self:GetParent():GetChild("ChordDensityGraph")

                seek:visible(true)
                seektext:visible(true)
                seek:x(INPUTFILTER:GetMouseX() - self:GetParent():GetX())
                seektext:x(INPUTFILTER:GetMouseX() - self:GetParent():GetX() - 4) -- todo: refactor this lmao -mina
                seektext:y(INPUTFILTER:GetMouseY() - self:GetParent():GetY())
                if cdg.npsVector ~= nil and #cdg.npsVector > 0 then
                    local percent = clamp((INPUTFILTER:GetMouseX() - self:GetParent():GetX()) / wodth, 0, 1)
                    local hoveredindex = clamp(math.ceil(cdg.finalNPSVectorIndex * percent),
                        math.min(1, cdg.finalNPSVectorIndex), cdg.finalNPSVectorIndex)
                    local hoverednps = cdg.npsVector[hoveredindex]
                    local td = GAMESTATE:GetCurrentSteps():GetTimingData()
                    local bpm = td:GetBPMAtBeat(td:GetBeatFromElapsedTime(seek:GetX() * musicratio)) * getCurRateValue()
                    seektext:settextf("%0.2f\n%d %s\n%d %s", seek:GetX() * musicratio / getCurRateValue(), hoverednps,
                        translated_info["NPS"], bpm, translated_info["BPM"])
                else
                    seektext:settextf("%0.2f", seek:GetX() * musicratio / getCurRateValue())
                end
            else
                self:GetParent():diffusealpha(0.05)
                self:GetParent():GetChild("Seektext"):visible(false)
                self:GetParent():GetChild("Seek"):visible(false)
            end
        end
    },
    Def.Quad {
        Name = "Pos",
        InitCommand = function(self)
            self:zoomto(0, hidth):diffuse(color("0,1,0,.5")):halign(0):draworder(900)
        end
    }
    -- MovableBorder(wodth+3, hidth+3, 1, (wodth)/2, 0)
}

-- Load the CDGraph with a forced width parameter.
pm[#pm + 1] = LoadActorWithParams("../_chorddensitygraph.lua", {
    width = wodth
})

-- more draw order shenanigans
pm[#pm + 1] = LoadFont("Common Normal") .. {
    Name = "Seektext",
    InitCommand = function(self)
        self:y(8):valign(1):halign(1):draworder(1100):diffuse(color("0.8,0,0")):zoom(0.4)
    end
}

pm[#pm + 1] = UIElements.QuadButton(1, 1) .. {
    Name = "Seek",
    InitCommand = function(self)
        self:zoomto(2, hidth):diffuse(color("1,.2,.5,1")):halign(0.5):draworder(1100)
        self:z(2)
    end,
    MouseDownCommand = function(self, params)
        if params.event == "DeviceButton_left mouse button" then
            local withCtrl = INPUTFILTER:IsControlPressed()
            if withCtrl then
                handleRegionSetting(self:GetX() * musicratio)
            else
                SCREENMAN:GetTopScreen():SetSongPosition(self:GetX() * musicratio, 0, false)
            end
        elseif params.event == "DeviceButton_right mouse button" then
            handleRegionSetting(self:GetX() * musicratio)
        end
    end
}

pm[#pm + 1] = Def.Quad {
    Name = "BookmarkPos",
    InitCommand = function(self)
        self:zoomto(2, hidth):diffuse(color(".2,.5,1,1")):halign(0.5):draworder(1100)
        self:visible(false)
    end,
    SetCommand = function(self)
        self:visible(true)
        self:zoomto(2, hidth):diffuse(color(".2,.5,1,1")):halign(0.5)
        self:x(loopStartPos / musicratio)
    end,
    RegionSetMessageCommand = function(self, params)
        if not params or not params.loopLength then
            self:playcommand("Set")
        else
            self:visible(true)
            self:x(loopStartPos / musicratio):halign(0)
            self:zoomto(params.loopLength / musicratio, hidth):diffuse(color(".7,.2,.7,0.5"))
        end
    end,
    CurrentRateChangedMessageCommand = function(self)
        if not loopEndPos and loopStartPos then
            self:playcommand("Set")
        elseif loopEndPos and loopStartPos then
            self:playcommand("RegionSet", {
                loopLength = (loopEndPos - loopStartPos)
            })
        end
    end,
    PracticeModeReloadMessageCommand = function(self)
        self:playcommand("CurrentRateChanged")
    end
}

if practiceMode and not isReplay then
    t[#t + 1] = pm
    if not allowedCustomization then
        -- enable pausing
        t[#t + 1] = UIElements.QuadButton(1, 1) .. {
            Name = "PauseArea",
            InitCommand = function(self)
                self:halign(0):valign(0)
                self:z(1)
                self:diffusealpha(0)
                self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
            end,
            MouseDownCommand = function(self, params)
                if params.event == "DeviceButton_right mouse button" then
                    local top = SCREENMAN:GetTopScreen()
                    if top then
                        top:TogglePause()
                    end
                end
            end
        }
    end
end

--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
															  **Measure Counter**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	bruh
]]

local measures = {}
local beatcounter = 0
local measure = 1
local thingy = 1
local active = false
mc = Def.ActorFrame {
    InitCommand = function(self)
        self:x(200)
        self:y(200)

        local steps = GAMESTATE:GetCurrentSteps()
        local loot = steps:GetNPSPerMeasure(1)

        local peak = 0
        for i = 1, #loot do
            if loot[i] > peak then

                peak = loot[i]
            end
        end

        local m_len = 0
        local m_spd = 0
        local m_start = 0
        for i = 1, #loot do
            if m_len == 0 then
                m_spd = loot[i]
                m_start = i
            end

            if math.abs(m_spd - loot[i]) < 2 then
                m_len = m_len + 1
                m_spd = (m_spd + loot[i]) / 2
            elseif m_len > 1 and m_spd > peak / 1.6 then
                measures[#measures + 1] = {
                    m_start,
                    m_len,
                    m_spd
                }
                m_len = 0
            else
                m_len = 0
            end
        end
    end,
    LoadFont("Common Normal") .. {
        OnCommand = function(self)
            self:visible(false)
            settext(self, "")

            if measure == measures[thingy][1] then
                playcommand(self, "Dootz")
            end
        end,
        BeatCrossedMessageCommand = function(self)
            if thingy <= #measures then
                beatcounter = beatcounter + 1
                if beatcounter == 4 then
                    measure = measure + 1
                    beatcounter = 0

                    if measure == measures[thingy][1] then
                        playcommand(self, "Dootz")
                    end

                    if measure > measures[thingy][1] + measures[thingy][2] then
                        playcommand(self, "UnDootz")
                        thingy = thingy + 1
                    end

                    if active then
                        playcommand(self, "MeasureCrossed")
                    end
                end
            end
        end,
        DootzCommand = function(self)
            self:visible(true)
            active = true
            settext(self, measure - measures[thingy][1] .. " / " .. measures[thingy][2])
        end,
        MeasureCrossedCommand = function(self)
            settext(self, measure - measures[thingy][1] .. " / " .. measures[thingy][2])
        end,
        UnDootzCommand = function(self)
            self:visible(false)
            active = false
        end
    }
}

-- t[#t + 1] = mc

return t
