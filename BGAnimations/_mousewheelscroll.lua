local moving = false
local whee
local pressingtab = false
local top

local function scrollInput(event)
	if top:GetName() == "ScreenSelectmusic" then
		if top:GetSelectionState() == 2 then
			return
		end	
	elseif event.DeviceInput.button == "DeviceButton_tab" then
		if event.type == "InputEventType_FirstPress" then
			pressingtab = true
		elseif event.type == "InputEventType_Release" then
			pressingtab = false
		end
	elseif event.type == "InputEventType_FirstPress"then
		if event.DeviceInput.button == "DeviceButton_mousewheel up" then
			moving = true
			if pressingtab == true and not whee:IsSettled() then
				whee:Move(-2)
			else
				whee:Move(-1)
			end
		elseif event.DeviceInput.button == "DeviceButton_mousewheel down" then
			moving = true
			if pressingtab == true and not whee:IsSettled() then
				whee:Move(2)
			else
				whee:Move(1)
			end
		end
	elseif moving == true then
		whee:Move(0)
		moving = false
	end
	
	return false
end

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

--you broke it retard, congrats
local t = Def.ActorFrame {
	BeginCommand = function(self)
		whee = SCREENMAN:GetTopScreen():GetMusicWheel()
		top = SCREENMAN:GetTopScreen()
		if event.DeviceInput.button ==  "left alt" then
		top:AddInputCallback(volControlBind)
		else
		top:AddInputCallback(scrollInput)
		end
		self:visible(false)

	end
}


return t
