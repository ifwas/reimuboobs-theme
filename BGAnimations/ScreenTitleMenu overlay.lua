local t = Def.ActorFrame {}

--[[ I WILL FIX THIS I SWEAR
if showVisualizer then
	local vis = audioVisualizer:new {
		x = SCREEN_LEFT,
		y = SCREEN_BOTTOM,
		maxHeight = 30,
		
		freqIntervals = audioVisualizer.multiplyIntervals(audioVisualizer.defaultIntervals, 25),
		color = getMainColor("positive"),
		onBarUpdate = function(self)
			--[
			self:diffusetopedge(getMainColor("frames"))
			self:diffusebottomedge(getMainColor("positive"))
			self:halign(1)
			self:diffusealpha(0.5)
			--]]
			--[[
			self:diffuselowerleft()
			self:diffuseupperleft()
			self:diffuselowerright()
			self:diffuseupperright()
			--]]
		--end
	--}]
	
    --t[#t + 1] = vis
--end




t[#t + 1] = LoadActor("_volumecontrol")
t[#t+1] = LoadActor(THEME:GetPathG("", "_crashUploadOptIn"))

t[#t + 1] = LoadActor("_xoon3")
t[#t + 1] = LoadActor("_cursor")
return t
