return LoadFont("Common normal") ..
	{
		InitCommand = function(self)
			self:zoom(0.4):diffuse(color("#FFFFFF")):maxwidth((25))
		end
	}
