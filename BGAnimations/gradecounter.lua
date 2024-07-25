-- pls don't look at this mess -steffen
-- haha i looked at it lolol

local t = Def.ActorFrame {}

local fontColor = color("#FFFFFF") -- getMainColor("positive")
local fontZoom = 0.45

local xPos = 100
local xGap = 5

local yPos = 37.5
local yGap = 11.5

-- cache values so we only parse the xml once
local basePath = PROFILEMAN:GetProfileDir(1)
local saveFile = basePath .. "grade_counter.txt"

-- the visual in the lower right displaying the values
local function CreateGradeDisplay(tier, index)
    return Def.ActorFrame {
        -- tier display
        LoadFont("Common Normal") .. {
            OnCommand = function(self)
                self:xy(SCREEN_CENTER_X + SCREEN_CENTER_X / 2.5 + xPos + xGap, SCREEN_BOTTOM - yPos + yGap * index):halign(0):valign(1):zoom(fontZoom)
                self:settext(getGradeStrings(tier) .. "")
                self:diffuse(getGradeColor(tier))
            end
        },
        -- numbers display
        LoadFont("Common Normal") .. {
            OnCommand = function(self)
                local valueToDisplay = -1
                if index == 0 then valueToDisplay = GRADECOUNTERSTORAGE.AAAA end
                if index == 1 then valueToDisplay = GRADECOUNTERSTORAGE.AAA end
                if index == 2 then valueToDisplay = GRADECOUNTERSTORAGE.AA end
                if index == 3 then valueToDisplay = GRADECOUNTERSTORAGE.A end

                self:xy(SCREEN_CENTER_X + SCREEN_CENTER_X / 2.5 + xPos, SCREEN_BOTTOM - yPos + yGap * index):halign(1):valign(1):zoom(fontZoom)
				self:diffuse(fontColor)
				self:settext(valueToDisplay)
            end
        }
    }
end

-- write grade count into "cache file"
local function StoreGrades(aaaa, aaa, aa, a)
    local content = string.format("%d\n%d\n%d\n%d\n", aaaa, aaa, aa, a)
    File.Write(saveFile, content)
end

-- read grade counts from "cache file"
local function RetrieveGrades()
    local content = File.Read(saveFile)
    if not content then
        return false, 0, 0, 0, 0
    end

    local aaaa, aaa, aa, a = content:match("(%d+)%s*(%d+)%s*(%d+)%s*(%d+)")
    if not (aaaa and aaa and aa and a) then
        return false, 0, 0, 0, 0
    end

    return true, tonumber(aaaa), tonumber(aaa), tonumber(aa), tonumber(a)
end

-- code for parsing the xml
-- really dirty but haven't had any problems with it
local function Trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function ParseXML(xml)
    local grades = {}
    local pattern = "<Score.-<Grade>(.-)</Grade>.-</Score>"

    for grade in xml:gmatch(pattern) do
        local trimmedGrade = Trim(grade)
        if trimmedGrade ~= "" then
            grades[#grades + 1] = trimmedGrade
        end
    end

    return grades
end

local function CountGrade(tiers, grades)
    local count = 0
    for _, grade in ipairs(grades) do
        for _, tier in ipairs(tiers) do
            if grade == tier then
                count = count + 1
                break
            end
        end
    end
    return count
end

-- object? dunno lua terms to store gradecounts so we don't have to read the file multiple times in CreateGradeDisplay - LoadFont - OnCommand
if not GRADECOUNTERSTORAGE then
    GRADECOUNTERSTORAGE={
        AAAA = 0,
        AAA = 0,
        AA = 0,
        A = 0
    }
end

-- increments and store in "cache file"
function GRADECOUNTERSTORAGE:increment(grade)
    if grade == "AAAA" then self.AAAA = self.AAAA + 1 end
    if grade == "AAA" then self.AAA = self.AAA + 1 end
    if grade == "AA" then self.AA = self.AA + 1 end
    if grade == "A" then self.A = self.A + 1 end

    StoreGrades(self.AAAA, self.AAA, self.AA, self.A)
end

-- parse the xml if there's no cache file
-- creates the cache file and sets the values
function GRADECOUNTERSTORAGE:init()
   
    local success, aaaa, aaa, aa, a = RetrieveGrades()
   
    if not success then
        local xmlData = File.Read(basePath .. "Etterna.xml")
        local grades = ParseXML(xmlData)

        aaaa = CountGrade({"Tier01", "Tier02", "Tier03", "Tier04"}, grades)
        aaa = CountGrade({"Tier05", "Tier06", "Tier07"}, grades)
        aa = CountGrade({"Tier08", "Tier09", "Tier10"}, grades)
        a = CountGrade({"Tier11", "Tier12", "Tier13"}, grades)

        StoreGrades(aaaa, aaa, aa, a)
    end

    self.AAAA = aaaa
    self.AAA = aaa
    self.AA = aa
    self.A = a
end

-- well, well, well... just read the file every time the actor gets loaded
-- too lazy to change
-- still better than reading the file 4 times tbh
GRADECOUNTERSTORAGE:init()

-- these actors will read the values from GRADECOUNTERSTORAGE
-- make sure it's initialized with the correct values to be displayed here

t[#t + 1] = CreateGradeDisplay("Grade_Tier04", 0)
t[#t + 1] = CreateGradeDisplay("Grade_Tier07", 1)
t[#t + 1] = CreateGradeDisplay("Grade_Tier10", 2)
t[#t + 1] = CreateGradeDisplay("Grade_Tier13", 3)

return t