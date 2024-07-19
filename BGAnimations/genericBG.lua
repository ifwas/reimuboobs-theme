t = Def.ActorFrame { }

t[#t + 1] = LoadActor(THEME:GetPathG("", "_OptionsScreen")) ..  {
	OnCommand = function(self)
		self:FullScreen():zoom(0.445)
	end
}

return t
