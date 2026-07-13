local ADDON_NAME = ...

MaddinCrafts = MaddinCrafts or {}
local MC = MaddinCrafts

MC.name = ADDON_NAME or "MaddinCrafts"

local function EnsureSavedVariables()
    if type(MaddinCraftsDB) ~= "table" then
        MaddinCraftsDB = {}
    end

    if MaddinCraftsDB.debug == nil then
        MaddinCraftsDB.debug = false
    end

    MC.db = MaddinCraftsDB
end

function MC:OnAddonLoaded(addonName)
    if addonName ~= self.name then
        return
    end

    EnsureSavedVariables()

    if self.ValidateData then
        self:ValidateData()
    end

    self:Debug("Loaded")
end
