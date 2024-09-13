--todo: make mouse inputs actually work

local t = Def.ActorFrame {}

local EventVolumeControl = false
local bgThingX = SCREEN_CENTER_X + 270
local bgThingY = SCREEN_CENTER_Y + 170
local VolumeIndicator

local VolumeThing = 100

--credits to jole for implementing the code to make the volume control work in the first place
--volume control
function volControlBind(event)
    local AltPressed = INPUTFILTER:IsBeingPressed("left alt")
 

    --kb only atm
    --[[]]
    if AltPressed and event.DeviceInput.button == "DeviceButton_w" then
        curGameVolume = clamp(curGameVolume + 0.05, 0, 1)
        SOUND:SetVolume(curGameVolume)
        MESSAGEMAN:Broadcast("volumeChanged")

    end
    if AltPressed and event.DeviceInput.button == "DeviceButton_q" then
        curGameVolume = clamp(curGameVolume - 0.05, 0, 1)
        SOUND:SetVolume(curGameVolume)
        MESSAGEMAN:Broadcast("volumeChanged")
    end
end

t[#t+1] = Def.ActorFrame {
    Name = "VolumeIndicator",
    Def.Quad {
        Name = "BG",
        InitCommand = function(self)
            self:xy(SCREEN_CENTER_X + capWideScale(get43size(255),270), SCREEN_CENTER_Y + 170)
            self:zoomto(250, 50)
            self:diffuse(getMainColor("tabs")):diffusealpha(0)
        end,
        volumeChangedMessageCommand = function(self)
            self:stoptweening()
            self:smooth(0.3):diffusealpha(1):sleep(0.1):smooth(0.3):smooth(0.2):diffusealpha(0)
        end,
    },
}


t[#t + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
    Name = "Name",
    InitCommand = function(self)
        self:halign(0)
        self:xy(SCREEN_CENTER_X + capWideScale(get43size(148),180), SCREEN_CENTER_Y + 160):diffusealpha(0)
        self:zoom(0.65)
        self:maxwidth(capWideScale(360,800))
        self:maxheight(22)
        self:settextf("%.0f",curGameVolume * 100)
    end,
    volumeChangedMessageCommand = function(self)
        self:settextf("%.0f",curGameVolume * 100)
        self:sleep(2) --wait
        self:stoptweening()
        self:smooth(0.3):diffusealpha(1):sleep(0.1):smooth(0.3):smooth(0.2):diffusealpha(0)
    end,
    }

--thingy for making vol control inputs work
t[#t + 1] = UIElements.QuadButton(-2000, 1) .. {
    Name = "volume control",
    OnCommand = function(self)
        --off screen just in case it conflicts with anything
        self:xy(0,0)
        self:zoomto(1,1)
        self:visible(true)
        SCREENMAN:GetTopScreen():AddInputCallback(volControlBind)
    end,
    volumeChangedMessageCommand = function(self)
        self:sleep(3)
    end,
}

--thingy for making vol control inputs work
t[#t + 1] = UIElements.QuadButton(-2000, 1) .. {
    Name = "volumeoff",
    OnCommand = function(self)
        --off screen just in case it conflicts with anything
        self:xy(0,0)
        self:zoomto(1,1)
        self:visible(false)
    end,
    EnteringSongMessageCommand = function(self)
        self:visible(true)
        SCREENMAN:GetTopScreen():AddInputCallback(volControlBindOff)
    end
}




t[#t+1] = Def.ActorFrame {
    Name = "VolumeIndicatorBar",
    Def.Quad {
        Name = "BG",
        InitCommand = function(self)
            self:halign(0)
            self:xy(SCREEN_CENTER_X + capWideScale(get43size(106),150), SCREEN_CENTER_Y + 180)
            self:zoomto(235 * curGameVolume, 2)
            self:diffuse(getMainColor("positive"))
            self:diffusealpha(0)
        end,
        volumeChangedMessageCommand = function(self)
            self:stoptweening()
            self:zoomto(235 * curGameVolume, 2):finishtweening()
            self:smooth(0.3):diffusealpha(1):sleep(0.1):smooth(0.3):smooth(0.2):diffusealpha(0)
        end,
    },
}

t[#t+1] = Def.ActorFrame {
    Name = "VolumeIndicatorIcon",
    Def.Sprite {
        Name = "volumeicon",
        Texture=THEME:GetPathG("","volume");
        InitCommand = function(self)
            self:xy(SCREEN_CENTER_X + capWideScale(get43size(120),164), SCREEN_CENTER_Y + 160):diffusealpha(0)
            self:zoom(0.45)
        end,
        volumeChangedMessageCommand = function(self)
            self:stoptweening()
            self:smooth(0.3):diffusealpha(1):sleep(0.1):smooth(0.3):smooth(0.2):diffusealpha(0)
        end,
    },
}



curGameVolume = PREFSMAN:GetPreference("SoundVolume")
return t