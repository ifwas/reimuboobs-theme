local t = Def.ActorFrame {}
t[#t + 1] = LoadActor("_volumecontrol")
local AltPressed = INPUTFILTER:IsBeingPressed("left alt")

curGameVolume = PREFSMAN:GetPreference("SoundVolume")


--the only thing missing here are the animations, other than that it's almost functional -ifwas

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
				self:xy(SCREEN_CENTER_X + 270, SCREEN_CENTER_Y + 180)
				self:zoomto(capWideScale(curGameVolume,235), 2)
				self:diffuse(getMainColor("positive"))
			end,
			OnCommand = function(self)
				self:zoomto(capWideScale(curGameVolume,235), 2)
			end,
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

return t