local lastclick = GetTimeSinceStart()
local requiredtimegap = 0.1

local t = Def.ActorFrame {}

--if you uncomment this you'll lose 300fps
--[[
t[#t+1] = Def.Sprite {
    InitCommand = function(self)
		self:fadeleft(0)
		self:halign(0.9)
		self:zoomto(120,60)
		self:x(20)
		self:y(-2)
		self:diffusealpha(1)
		end,
		SetMessageCommand = function(self,params)
			local song = params.Song
            local pack = params.Pack
			local focus = params.HasFocus
			local bnpath = nil
			local pkpath = nil

			if song then
				bnpath = params.Song:GetBannerPath()
				if not bnpath then
					bnpath = THEME:GetPathG("Common", "fallback wheelbanner")
				end
				self:Load(bnpath)
				self:zoomto(60,30)
            else
                bnpath = SONGMAN:GetSongGroupBannerPath()
                if not bnpath then
					bnpath = THEME:GetPathG("Common", "fallback wheelbanner")
				end
                self:Load(bnpath)
				self:zoomto(60,30)
			end

			--This does nothing. Maybe I need a different file for this
			if pack then
				pkpath = WHEELDATA:GetFolderBanner()
				if not pkpath then
					pkpath = THEME:GetPathG("Common", "fallback wheelbanner")
				end
				self:Load(pkpath)
				self:zoomto(120,60)
			end

			if focus then
				self:diffusealpha(1)
			else
				self:diffusealpha(0.4)
			end
		end
};
]]
t[#t+1] = Def.ActorFrame {
    UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:halign(0)
			self:xy(0,0)
			self:diffusealpha(0)
			self:zoomto(854, 38)
		end,
        SetCommand = function(self, params)
            self.index = params.DrawIndex
        end,
		MouseDownCommand = function(self, params)
            if params.event == "DeviceButton_left mouse button" then
                local now = GetTimeSinceStart()
                if now - lastclick < requiredtimegap then return end
                lastclick = now

                local numwheelitems = 15
                local middle = math.ceil(15 / 2)
                local top = SCREENMAN:GetTopScreen()
                local we = top:GetMusicWheel()
                if we then
                    local dist = self.index - middle
                    if dist == 0 and we:IsSettled() then
                        -- clicked current item
                        top:SelectCurrent()
                    else
                        local itemtype = we:MoveAndCheckType(self.index - middle)
                        we:Move(0)
                        if itemtype == "WheelItemDataType_Section" then
                            -- clicked a group
                            top:SelectCurrent()
                        end
                    end
                end
            elseif params.event == "DeviceButton_right mouse button" then
                -- right click opens playlists
                local tind = getTabIndex()
	    		setTabIndex(7)
    			MESSAGEMAN:Broadcast("TabChanged", {from = tind, to = 7})
            end
		end,
	},
}

return t