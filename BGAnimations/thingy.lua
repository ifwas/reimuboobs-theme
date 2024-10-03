local frameX = 680
local frameY = 36.5
local frameWidth = SCREEN_WIDTH * 0.4
local frameHeight = 390
local YesNoChoices = {THEME:GetString("OptionNames", "Off"), THEME:GetString("OptionNames", "On")}
local textOptionNameX = frameX - 50
local hoverTriangleAlpha = 0.7
local OptionsPerPage = 1
local OptionGap = 30


local optionItems = {
    ShowBanners = themeConfig:get_data().global.ShowBanners
}

local optionNamesTrans = {
    ShowBanners = THEME:GetString("OptionTitles", "ShowBanners")
}

--got angry at trying to make a recursive theme option function
--so i'll just add them manually atm (even thought most prob it'll end up as some sort of debug theme menu)

local t = Def.ActorFrame {
    Name = "QuickOptions",
    BeginCommand = function(self)
        self:xy(500,0)
    end,
    EnteringQuickMessageCommand = function(self)
        self:bouncebegin(0.2):xy(0, 0)
    end,
    ExitQuickMessageCommand = function(self)
        self:bouncebegin(0.2):xy(500, 0)
    end
}

--quadbutton
t[#t + 1] = UIElements.QuadButton(1, 1) .. {
	InitCommand = function(self)
		self:xy(frameX,frameY):zoomto(frameWidth, frameHeight):valign(0):diffuse(getMainColor("frames")):diffusealpha(0.7)
	end
}

t[#t + 1] =  LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(frameX,frameY + 10):zoom(0.5):valign(0)
        self:settext("Quick Options")
	end
}

t[#t + 1] =  LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(textOptionNameX,frameY + 50):zoom(0.2):halign(1)
        self:settext("Show Banners")
	end
}

t[#t + 1] =  LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(textOptionNameX,frameY + 65):zoom(0.2):halign(1)
        self:settext("Show Wheel Banners")
	end
}

t[#t + 1] =  LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(textOptionNameX,frameY + 80):zoom(0.2):halign(1)
        self:settext("Show Offset in ScoreTab")
	end
}



t[#t + 1] =  LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(textOptionNameX + 100,frameY + 50):zoom(0.2):halign(1)
        self:settext("optionChoice")
	end,
    BeginCommand = function(self)
        local optionchoice = themeConfig:get_data().global.ShowBanners
        if optionchoice then
            self:settext(YesNoChoices[2])
        else
            self:settext(YesNoChoices[1])
        end
    end,
    OptionUpdatedMessageCommand = function(self)
        if BannersEnabled() then
        self:settext(YesNoChoices[2])
        else
        self:settext(YesNoChoices[1])
        end
    end
}

t[#t + 1] =  LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(textOptionNameX + 100,frameY + 80):zoom(0.2):halign(1)
        self:settext("optionChoice")
	end,
    BeginCommand = function(self)
        local optionchoice = themeConfig:get_data().global.ShowOffsetScoreTab
        if optionchoice then
            self:settext(YesNoChoices[2])
        else
            self:settext(YesNoChoices[1])
        end
    end,
    OptionUpdatedMessageCommand = function(self)
        if themeConfig:get_data().global.ShowOffsetScoreTab then
        self:settext(YesNoChoices[2])
        else
        self:settext(YesNoChoices[1])
        end
    end
}


t[#t + 1] = UIElements.SpriteButton(1, 1) .. {
    Name = "TriangleRowBannerOptionRight",
    Texture = THEME:GetPathG("", "_triangle"),
    InitCommand = function(self)
        self:xy(textOptionNameX + 105, frameY + 50):zoom(0.2):diffusealpha(1)
        self:rotationz(90)
    end,
    MouseOverCommand = function(self)
        self:diffusealpha(hoverTriangleAlpha)
    end,
    MouseOutCommand = function(self)
        self:diffusealpha(1)
    end,
    MouseDownCommand = function(self, params)
        local preference = themeConfig:get_data().global.ShowBanners
        local value
        if params.event == "DeviceButton_left mouse button" then
            if preference then
                value = false
            else
                value = true
            end

            SOUND:PlayOnce(THEME:GetPathS("MusicWheel","change"))
            themeConfig:get_data().global.ShowBanners = value
            themeConfig:set_dirty()
            themeConfig:save()
            MESSAGEMAN:Broadcast("OptionUpdated")
        end
    end
}

t[#t + 1] = UIElements.SpriteButton(1, 1) .. {
    Name = "TriangleRowScoreOptionRight",
    Texture = THEME:GetPathG("", "_triangle"),
    InitCommand = function(self)
        self:xy(textOptionNameX + 105, frameY + 80):zoom(0.2):diffusealpha(1)
        self:rotationz(90)
    end,
    MouseOverCommand = function(self)
        self:diffusealpha(hoverTriangleAlpha)
    end,
    MouseOutCommand = function(self)
        self:diffusealpha(1)
    end,
    MouseDownCommand = function(self, params)
        local preference = themeConfig:get_data().global.ShowOffsetScoreTab
        local value
        if params.event == "DeviceButton_left mouse button" then
            if preference then
                value = false
            else
                value = true
            end

            SOUND:PlayOnce(THEME:GetPathS("MusicWheel","change"))
            themeConfig:get_data().global.ShowOffsetScoreTab = value
            themeConfig:set_dirty()
            themeConfig:save()
            MESSAGEMAN:Broadcast("OptionUpdated")
        end
    end
}

return t