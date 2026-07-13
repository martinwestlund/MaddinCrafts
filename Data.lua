local MC = MaddinCrafts

MC.data = MC.data or {}
MC.data.professions = MC.data.professions or {}
MC.data.professionOrder = MC.data.professionOrder or {}
MC.data.recipes = MC.data.recipes or {}
MC.data.recipeSchema = {
    "id",
    "name",
    "profession",
    "requiredSkill",
    "sourceType",
    "sourceText",
    "recipeItemId",
    "teachesSpellId",
    "faction",
    "reputation",
    "phase",
    "verified",
    "notes",
}

local REQUIRED_RECIPE_FIELDS = {
    "id",
    "name",
    "profession",
    "requiredSkill",
    "sourceType",
    "sourceText",
    "phase",
    "verified",
}

function MC:Warn(message)
    local text = "|cffff9933MaddinCrafts|r " .. tostring(message)

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

function MC:RegisterProfession(profession)
    if type(profession) ~= "table" or profession.id == nil then
        self:Warn("Skipping profession with missing id")
        return
    end

    if self.data.professions[profession.id] == nil then
        table.insert(self.data.professionOrder, profession.id)
    end

    self.data.professions[profession.id] = profession
end

function MC:RegisterRecipes(professionId, recipes)
    if self.data.recipes[professionId] == nil then
        self.data.recipes[professionId] = {}
    end

    for _, recipe in ipairs(recipes) do
        if recipe.profession == nil then
            recipe.profession = professionId
        end
        table.insert(self.data.recipes[professionId], recipe)
    end
end

function MC:ValidateRecipe(recipe, index, professionId)
    local isValid = true

    if type(recipe) ~= "table" then
        self:Warn("Invalid recipe record in " .. tostring(professionId) .. " at " .. tostring(index))
        return false
    end

    for _, field in ipairs(REQUIRED_RECIPE_FIELDS) do
        if recipe[field] == nil or recipe[field] == "" then
            self:Warn("Recipe " .. tostring(recipe.id or index) .. " missing required field: " .. field)
            isValid = false
        end
    end

    if recipe.profession ~= nil and self.data.professions[recipe.profession] == nil then
        self:Warn("Recipe " .. tostring(recipe.id or index) .. " uses unknown profession: " .. tostring(recipe.profession))
        isValid = false
    end

    return isValid
end

function MC:ValidateData()
    for _, professionId in ipairs(self.data.professionOrder) do
        local profession = self.data.professions[professionId]
        if profession == nil or profession.name == nil or profession.name == "" then
            self:Warn("Profession " .. tostring(professionId) .. " missing required field: name")
        end
    end

    for professionId, recipes in pairs(self.data.recipes) do
        if self.data.professions[professionId] == nil then
            self:Warn("Recipe table uses unknown profession: " .. tostring(professionId))
        end

        for index, recipe in ipairs(recipes) do
            self:ValidateRecipe(recipe, index, professionId)
        end
    end
end
