local MC = MaddinCrafts

MC.state = MC.state or {}

local WOTLK_EVENTS = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "TRADE_SKILL_SHOW",
    "TRADE_SKILL_UPDATE",
    "CHAT_MSG_SKILL",
}

local function EnsureSavedVariables()
    if type(MaddinCraftsDB) ~= "table" then
        MaddinCraftsDB = {}
    end

    if type(MaddinCraftsDB.characters) ~= "table" then
        MaddinCraftsDB.characters = {}
    end

    MC.db = MaddinCraftsDB
    return MaddinCraftsDB
end

local function GetCharacterKey()
    local name = "Unknown"
    if UnitName then
        name = UnitName("player") or name
    end

    local realm = "Unknown"
    if GetRealmName then
        realm = GetRealmName() or realm
    end

    return realm .. " - " .. name
end

local function EnsureCharacterState()
    local db = EnsureSavedVariables()
    local key = GetCharacterKey()

    if type(db.characters[key]) ~= "table" then
        db.characters[key] = {}
    end

    local character = db.characters[key]
    if type(character.learnedRecipes) ~= "table" then
        character.learnedRecipes = {}
    end
    if type(character.professions) ~= "table" then
        character.professions = {}
    end
    if type(character.reputations) ~= "table" then
        character.reputations = {}
    end

    MC.state.characterKey = key
    MC.state.character = character
    return character
end

local function ExtractIdFromLink(link)
    if type(link) ~= "string" then
        return nil
    end

    local spellId = string.match(link, "spell:(%d+)")
    if spellId then
        return tonumber(spellId), "spell"
    end

    local itemId = string.match(link, "item:(%d+)")
    if itemId then
        return tonumber(itemId), "item"
    end

    return nil
end

MC.ExtractIdFromLink = ExtractIdFromLink

function MC:ScanFaction()
    local character = EnsureCharacterState()
    local faction, localizedFaction = nil, nil

    if UnitFactionGroup then
        faction, localizedFaction = UnitFactionGroup("player")
    end

    character.faction = faction or "Unknown"
    character.localizedFaction = localizedFaction or character.faction
    MC.state.faction = character.faction

    return character.faction
end

function MC:ScanReputations()
    local character = EnsureCharacterState()
    local reputations = {}

    if GetNumFactions and GetFactionInfo then
        for index = 1, GetNumFactions() do
            local name, _, standingID, bottomValue, topValue, earnedValue, _, _, isHeader, isCollapsed, _, _, _, factionID = GetFactionInfo(index)

            if name and not isHeader then
                reputations[name] = {
                    id = factionID,
                    standing = standingID or 0,
                    bottom = bottomValue or 0,
                    top = topValue or 0,
                    earned = earnedValue or 0,
                }
            elseif name and isHeader and not isCollapsed then
                reputations[name] = {
                    isHeader = true,
                    standing = standingID or 0,
                    bottom = bottomValue or 0,
                    top = topValue or 0,
                    earned = earnedValue or 0,
                }
            end
        end
    end

    character.reputations = reputations
    MC.state.reputations = reputations
    return reputations
end

local function IsTrackedProfessionName(name)
    if type(name) ~= "string" or type(MC.data) ~= "table" or type(MC.data.professions) ~= "table" then
        return false
    end

    for _, profession in pairs(MC.data.professions) do
        if profession.name == name then
            return true
        end
    end

    return false
end

local function ScanSkillLineProfessions(professions)
    if not GetNumSkillLines or not GetSkillLineInfo then
        return
    end

    for index = 1, GetNumSkillLines() do
        local skillName, isHeader, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank = GetSkillLineInfo(index)
        if skillName and not isHeader and IsTrackedProfessionName(skillName) then
            professions[skillName] = {
                rank = (skillRank or 0) + (skillModifier or 0),
                maxRank = skillMaxRank or 0,
            }
        end
    end
end

function MC:ScanProfessions()
    local character = EnsureCharacterState()
    local professions = {}
    local hasProfessionApi = GetProfessions and GetProfessionInfo
    local hasSkillLineApi = GetNumSkillLines and GetSkillLineInfo

    if hasProfessionApi then
        local professionIndexes = { GetProfessions() }
        for _, professionIndex in ipairs(professionIndexes) do
            if professionIndex then
                local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(professionIndex)
                if name then
                    professions[name] = {
                        rank = rank or 0,
                        maxRank = maxRank or 0,
                        skillLine = skillLine,
                    }
                end
            end
        end
    end

    if hasSkillLineApi and not next(professions) then
        ScanSkillLineProfessions(professions)
    end

    if not hasProfessionApi and not hasSkillLineApi then
        professions.unknown = {
            rank = 0,
            maxRank = 0,
            unknown = true,
        }
    end

    character.professions = professions
    MC.state.professions = professions
    return professions
end

function MC:ScanTradeSkillWindow()
    local character = EnsureCharacterState()

    if not GetNumTradeSkills or not GetTradeSkillInfo then
        return character.learnedRecipes
    end

    for index = 1, GetNumTradeSkills() do
        local _, skillType = GetTradeSkillInfo(index)
        if skillType ~= "header" then
            local recipeLink = nil
            if GetTradeSkillRecipeLink then
                recipeLink = GetTradeSkillRecipeLink(index)
            end

            local id, idType = ExtractIdFromLink(recipeLink)
            if id then
                character.learnedRecipes[id] = true
                if idType == "spell" then
                    character.learnedSpellIds = character.learnedSpellIds or {}
                    character.learnedSpellIds[id] = true
                elseif idType == "item" then
                    character.learnedItemIds = character.learnedItemIds or {}
                    character.learnedItemIds[id] = true
                end
            end
        end
    end

    MC.state.learnedRecipes = character.learnedRecipes
    return character.learnedRecipes
end

function MC:ScanPlayerState()
    self:ScanFaction()
    self:ScanReputations()
    self:ScanProfessions()
    return MC.state.character
end

function MC:OnStateEvent(event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= self.name then
            return
        end
        EnsureCharacterState()
        return
    end

    if event == "PLAYER_LOGIN" then
        self:ScanPlayerState()
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
        self:ScanTradeSkillWindow()
    elseif event == "CHAT_MSG_SKILL" then
        self:ScanProfessions()
    end
end

local stateFrame = CreateFrame("Frame")
for _, event in ipairs(WOTLK_EVENTS) do
    stateFrame:RegisterEvent(event)
end
stateFrame:SetScript("OnEvent", function(_, event, ...)
    MC:OnStateEvent(event, ...)
end)
