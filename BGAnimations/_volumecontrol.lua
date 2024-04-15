local t = Def.ActorFrame {}

local EventVolumeControl = false

--credits to jole for implementing the code to make the volume control work in the first place
--volume control
function volControlBind(event)
    local AltPressed = INPUTFILTER:IsBeingPressed("left alt")

    --mouse
    if AltPressed and event.DeviceInput.button == "DeviceButton_mousewheel up" then
        curGameVolume = clamp(curGameVolume + 0.025, 0, 1)
        SOUND:SetVolume(curGameVolume)
    end
    if AltPressed and event.DeviceInput.button == "DeviceButton_mousewheel down" then
        curGameVolume = clamp(curGameVolume - 0.025, 0, 1)
        SOUND:SetVolume(curGameVolume)
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

curGameVolume = PREFSMAN:GetPreference("SoundVolume")

--thingy for making vol control inputs work
t[#t + 1] = UIElements.QuadButton(-2000, 1) .. {
    Name = "volume control",
    OnCommand = function(self)
        --off screen just in case it conflicts with anything
        self:xy(-2,-2)
        self:zoomto(1,1)
        self:diffusealpha(0)
        SCREENMAN:GetTopScreen():AddInputCallback(volControlBind)
    end
}

return t