local hideFancyElements = themeConfig:get_data().global.HideFancyParticles
local t = Def.ActorFrame{};
if hideFancyElements then return t; end

local Params = { 
	NumParticles = 69,
	VelocityXMin = -500,
	VelocityXMax = 500,
	VelocityYMin = -500,
	VelocityYMax = 500,
--	ZoomMin = 0.2,
--	ZoomMax = 0.4,
	ZoomMin = 0.1,
	ZoomMax = 0.2,
	VelocityZMin = 0,
	VelocityZMax = 0,
	BobRateZMin = 0,
	BobRateZMax = 0.1,
	SpinZ = 0,
	BobZ = 52,
	File = "4",
};

local tParticleInfo = {}

for i=1,Params.NumParticles do
	tParticleInfo[i] = {
		X = math.random(Params.VelocityXMin, Params.VelocityXMax),
		Y = Params.VelocityYMin ~= Params.VelocityYMax and math.random(Params.VelocityYMin, Params.VelocityYMax) or Params.VelocityYMin,
		Z = Params.VelocityZMin ~= Params.VelocityZMax and math.random(Params.VelocityZMin, Params.VelocityZMax) or Params.VelocityZMin,
		Zoom = math.random(Params.ZoomMin*1000,Params.ZoomMax*1000) / 1000,
		BobZRate = math.random(Params.BobRateZMin*1000,Params.BobRateZMax*1000) / 1000,
		Age = 0,
	};
	t[#t+1] = LoadActor( Params.File )..{
	Name="Particle"..i;
		InitCommand=function(self)
		self:basezoom(tParticleInfo[i].Zoom);
		self:x(math.random(SCREEN_LEFT+(self:GetWidth()/2),SCREEN_RIGHT-(self:GetWidth()/2)));
		self:y(math.random(SCREEN_TOP+(self:GetHeight()/2),SCREEN_BOTTOM-(self:GetHeight()/2)));
		self:z(math.random(-64,0));
	end;
		OnCommand=function(self)
		 self:diffusealpha(1):spin()
		end;
	};
end

local function UpdateParticles(self,DeltaTime)
	tParticles = self:GetChildren();
	for i=1, Params.NumParticles do
		local p = tParticles["Particle"..i];
		local vX = tParticleInfo[i].X;
		local vY = tParticleInfo[i].Y;
		local vZ = tParticleInfo[i].Z;
		tParticleInfo[i].Age = tParticleInfo[i].Age + DeltaTime;
		p:x(p:GetX() + (vX * DeltaTime));
		p:y(p:GetY() + (vY * DeltaTime));
		p:z(p:GetZ() + (vZ * DeltaTime));
		if p:GetX() > SCREEN_RIGHT + (p:GetWidth()/2 - p:GetZ()) then
			p:x(SCREEN_LEFT - (p:GetWidth()/2));
		elseif p:GetX() < SCREEN_LEFT - (p:GetWidth()/2 - p:GetZ()) then
			p:x(SCREEN_RIGHT + (p:GetWidth()/2));
		end
		if p:GetY() > SCREEN_BOTTOM + (p:GetHeight()/2 - p:GetZ()) then
			p:y(SCREEN_TOP - (p:GetHeight()/2));
		elseif p:GetY() < SCREEN_TOP - (p:GetHeight()/2 - p:GetZ()) then
			p:y(SCREEN_BOTTOM + (p:GetHeight()/2));
		end
	end;
end;

t.InitCommand = function(self)
 self:fov(90):SetUpdateFunction(UpdateParticles)
end;

return t;
