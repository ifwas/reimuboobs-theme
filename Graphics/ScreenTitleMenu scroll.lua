local gc = Var("GameCommand")

return Def.ActorFrame {
	LoadFont("Common Normal") .. {
		Text=THEME:GetString("ScreenTitleMenu",gc:GetText()),
		OnCommand=function(self)
			self:xy(SCREEN_CENTER_X - 200, -72):align(0.5,0.5):zoom(0.5)
		end,
		GainFocusCommand=function(self)
			self:diffusealpha(1)
		end,
		LoseFocusCommand=function(self)
			self:diffusealpha(0.5)
		end
	}


}
