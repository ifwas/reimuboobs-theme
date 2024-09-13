local frameX = 680
local frameY = 36.5
local frameWidth = SCREEN_WIDTH * 0.4
local frameHeight = 390
local optionItems = {["Main"] = "Speed,RateList,NoteSk,RS,PRAC,CG,ScrollDir,Center,Persp"}


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
		self:xy(frameX,frameY + 10):zoom(0.5):valign(0):diffusealpha(0.7)
        self:settext("Quick Options")
	end
}

return t