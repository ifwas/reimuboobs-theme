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
 

    --mouse
    if AltPressed and event.DeviceInput.button == "DeviceButton_mousewheel up" then
        curGameVolume = clamp(curGameVolume + 0.05, 0, 1)
        SOUND:SetVolume(curGameVolume)
        MESSAGEMAN:Broadcast("volumeChanged")

    end
    if AltPressed and event.DeviceInput.button == "DeviceButton_mousewheel down" then
        curGameVolume = clamp(curGameVolume - 0.05, 0, 1)
        SOUND:SetVolume(curGameVolume)
        MESSAGEMAN:Broadcast("volumeChanged")
    end



    --kb
    --this doesn't ignore other actions that depend on arrow keys so i'll just leave this out
    -- if AltPressed and event.DeviceInput.button == "DeviceButton_up" then
    --     curGameVolume = clamp(curGameVolume + 0.025, 0, 1)
    --     SOUND:SetVolume(curGameVolume)
    -- end
    -- if AltPressed and event.DeviceInput.button == "DeviceButton_down" then
    --     curGameVolume = clamp(curGameVolume - 0.025, 0, 1)
    --     SOUND:SetVolume(curGameVolume)
    -- end
end



t[#t + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
    Name = "Name",
    InitCommand = function(self)
        self:halign(0)
        self:xy(SCREEN_CENTER_X + 185, SCREEN_CENTER_Y + 162)
        self:zoom(0.65)
        self:maxwidth(capWideScale(360,800))
        self:maxheight(22)
        self:diffuse(ButtonColor)
        self:settextf("%f",curGameVolume * 100)
    end,
    volumeChangedMessageCommand = function(self)
        self:settextf("%.0f",curGameVolume * 100)
        self:sleep(3) --wait
        
    end,
    }

--thingy for making vol control inputs work
t[#t + 1] = UIElements.QuadButton(-2000, 1) .. {
    Name = "volume control",
    OnCommand = function(self)
        --off screen just in case it conflicts with anything
        self:xy(0,0)
        self:zoomto(1,1)
        SCREENMAN:GetTopScreen():AddInputCallback(volControlBind)
    end,

    volumeChangedMessageCommand = function(self)
        self:sleep(3)
    end
}

t[#t+1] = Def.ActorFrame {
    Name = "VolumeIndicator",
    Def.Quad {
        Name = "BG",
        InitCommand = function(self)
            self:xy(SCREEN_CENTER_X + 270, SCREEN_CENTER_Y + 170)
            self:zoomto(250, 50)
            self:diffuse(getMainColor("tabs"))
        end,
    },
}

t[#t+1] = Def.ActorFrame {
    Name = "VolumeIndicatorBar",
    Def.Quad {
        Name = "BG",
        InitCommand = function(self)
            self:halign(0)
            self:xy(SCREEN_CENTER_X + 155, SCREEN_CENTER_Y + 180)
            self:zoomto(235 * curGameVolume, 2)
            self:diffuse(getMainColor("positive"))
        end,
        volumeChangedMessageCommand = function(self)
            self:zoomto(235 * curGameVolume, 2)
        end
    },
}

t[#t+1] = Def.ActorFrame {
    Name = "VolumeIndicatorIcon",
    Def.Sprite {
        Name = "volumeicon",
        Texture=THEME:GetPathG("","volume");
        InitCommand = function(self)
            self:xy(SCREEN_CENTER_X + 165, SCREEN_CENTER_Y + 162)
            self:zoom(0.45)
        end,
    },
}

curGameVolume = PREFSMAN:GetPreference("SoundVolume")
return t