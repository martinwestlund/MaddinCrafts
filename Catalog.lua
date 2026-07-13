local MC = MaddinCrafts

local MIN_REPUTATION_STANDING = 1

local function TableHasTruthyValue(tableValue, key)
    return type(tableValue) == "table" and key ~= nil and tableValue[key] == true
end

local function IsNeutralFaction(faction)
    return faction == nil or faction == "" or faction == "Neutral" or faction == "Both"
end

local function HasCorrectFaction(recipe, state)
    if IsNeutralFaction(recipe.faction) then
        return true
    end

    if type(state) ~= "table" then
        return false
    end

    return recipe.faction == state.faction or recipe.faction == state.localizedFaction
end

local function GetProfessionName(professionId)
    if type(MC.data) ~= "table" or type(MC.data.professions) ~= "table" then
        return professionId
    end

    local profession = MC.data.professions[professionId]
    if type(profession) == "table" and profession.name then
        return profession.name
    end

    return professionId
end

local function GetProfessionRank(recipe, state)
    if type(state) ~= "table" or type(state.professions) ~= "table" then
        return nil
    end

    local professionId = recipe.profession
    local professionName = GetProfessionName(professionId)
    local profession = state.professions[professionId] or state.professions[professionName]

    if type(profession) == "table" then
        return profession.rank
    end

    if type(profession) == "number" then
        return profession
    end

    return nil
end

local function HasRequiredSkill(recipe, state)
    if recipe.requiredSkill == nil then
        return true
    end

    if recipe.requiredSkill <= 0 then
        return false
    end

    local rank = GetProfessionRank(recipe, state)
    if rank == nil then
        return false
    end

    return rank >= recipe.requiredSkill
end

local function GetReputationRequirement(recipe)
    local reputation = recipe.reputation
    if reputation == nil then
        return nil, nil
    end

    if type(reputation) == "number" then
        return recipe.reputationFaction or recipe.factionName, reputation
    end

    if type(reputation) == "string" then
        return reputation, MIN_REPUTATION_STANDING
    end

    if type(reputation) == "table" then
        return reputation.name or reputation.faction or reputation.factionName,
            reputation.standing or reputation.minStanding or reputation.standingID or reputation.standingId or reputation.requiredStanding
    end

    return nil, nil
end

local function HasRequiredReputation(recipe, state)
    local reputationName, requiredStanding = GetReputationRequirement(recipe)
    if reputationName == nil or requiredStanding == nil then
        return true
    end

    if type(state) ~= "table" or type(state.reputations) ~= "table" then
        return false
    end

    local reputation = state.reputations[reputationName]
    if type(reputation) == "table" then
        return (reputation.standing or 0) >= requiredStanding
    end

    if type(reputation) == "number" then
        return reputation >= requiredStanding
    end

    return false
end

function MC:IsLearned(recipe, state)
    if type(recipe) ~= "table" or type(state) ~= "table" then
        return false
    end

    if TableHasTruthyValue(state.learnedItemIds, recipe.recipeItemId) then
        return true
    end

    if TableHasTruthyValue(state.learnedSpellIds, recipe.teachesSpellId) then
        return true
    end

    if TableHasTruthyValue(state.learnedRecipes, recipe.recipeItemId) or TableHasTruthyValue(state.learnedRecipes, recipe.teachesSpellId) then
        return true
    end

    if type(state.learnedRecipeNames) == "table" and recipe.name ~= nil and state.learnedRecipeNames[recipe.name] == true then
        return true
    end

    return false
end

function MC:IsAvailable(recipe, state)
    if type(recipe) ~= "table" then
        return false
    end

    state = state or {}

    if self:IsLearned(recipe, state) then
        return false
    end

    if recipe.sourceType == "SOURCE_PENDING" then
        return false
    end

    return HasRequiredSkill(recipe, state)
        and HasCorrectFaction(recipe, state)
        and HasRequiredReputation(recipe, state)
end

function MC:GetRecipeCategory(recipe, state)
    if self:IsLearned(recipe, state) then
        return "learned"
    end

    if self:IsAvailable(recipe, state) then
        return "available"
    end

    return "unlearned"
end

function MC:GetProfessionProgress(professionId, state)
    local progress = {
        total = 0,
        learned = 0,
        available = 0,
        unlearned = 0,
    }

    if type(MC.data) ~= "table" or type(MC.data.recipes) ~= "table" then
        return progress
    end

    local recipes = MC.data.recipes[professionId]
    if type(recipes) ~= "table" then
        return progress
    end

    for _, recipe in ipairs(recipes) do
        local category = self:GetRecipeCategory(recipe, state)
        progress.total = progress.total + 1
        progress[category] = progress[category] + 1
    end

    return progress
end

function MC:GetOverallProgress(state)
    local progress = {
        total = 0,
        learned = 0,
        available = 0,
        unlearned = 0,
        professions = {},
    }

    if type(MC.data) ~= "table" or type(MC.data.recipes) ~= "table" then
        return progress
    end

    local professionOrder = MC.data.professionOrder or {}
    for _, professionId in ipairs(professionOrder) do
        local professionProgress = self:GetProfessionProgress(professionId, state)
        progress.professions[professionId] = professionProgress
        progress.total = progress.total + professionProgress.total
        progress.learned = progress.learned + professionProgress.learned
        progress.available = progress.available + professionProgress.available
        progress.unlearned = progress.unlearned + professionProgress.unlearned
    end

    for professionId in pairs(MC.data.recipes) do
        if progress.professions[professionId] == nil then
            local professionProgress = self:GetProfessionProgress(professionId, state)
            progress.professions[professionId] = professionProgress
            progress.total = progress.total + professionProgress.total
            progress.learned = progress.learned + professionProgress.learned
            progress.available = progress.available + professionProgress.available
            progress.unlearned = progress.unlearned + professionProgress.unlearned
        end
    end

    return progress
end

function MC:DebugCatalogSummary(state)
    local progress = self:GetOverallProgress(state or (self.state and self.state.character) or self.state)
    local message = "Catalog: " .. progress.learned .. "/" .. progress.total .. " learned, "
        .. progress.available .. " available, " .. progress.unlearned .. " unlearned"

    if self.Debug then
        self:Debug(message)
    elseif print then
        print("MaddinCrafts " .. message)
    end

    return progress
end
