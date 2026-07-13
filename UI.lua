local MC = MaddinCrafts

local ROW_HEIGHT = 22
local VISIBLE_ROWS = 16
local CATEGORY_TABS = {
    { key = "overall", label = "Overall" },
    { key = "learned", label = "Learned" },
    { key = "available", label = "Available" },
    { key = "unlearned", label = "Unlearned" },
}

MC.ui = MC.ui or {}
MC.ui.selectedProfession = MC.ui.selectedProfession or nil
MC.ui.selectedCategory = MC.ui.selectedCategory or "overall"
MC.ui.selectedRecipe = MC.ui.selectedRecipe or nil
MC.ui.filteredRecipes = MC.ui.filteredRecipes or {}

local frame
local professionButtons = {}
local categoryButtons = {}
local recipeRows = {}
local recipeScroll
local titleText
local detailTitle
local detailSource
local detailRequirements
local detailNotes
local detailVerified

local function GetCharacterState()
    if type(MC.state) == "table" and type(MC.state.character) == "table" then
        return MC.state.character
    end

    return {}
end

local function GetProfessionName(professionId)
    local profession = MC.data and MC.data.professions and MC.data.professions[professionId]
    if type(profession) == "table" and profession.name then
        return profession.name
    end

    return tostring(professionId or "Unknown")
end

local function SelectFirstProfession()
    if MC.ui.selectedProfession ~= nil then
        return
    end

    if type(MC.data) ~= "table" or type(MC.data.professionOrder) ~= "table" then
        return
    end

    MC.ui.selectedProfession = MC.data.professionOrder[1]
end

local function SetButtonChecked(button, checked)
    if button and button.SetChecked then
        button:SetChecked(checked)
    end
end

local UpdateUI
local UpdateRecipeList
local ShowRecipeDetails

local function BuildRecipeList()
    local recipes = {}
    local professionId = MC.ui.selectedProfession
    local category = MC.ui.selectedCategory
    local state = GetCharacterState()

    if type(MC.data) ~= "table" or type(MC.data.recipes) ~= "table" or professionId == nil then
        MC.ui.filteredRecipes = recipes
        return recipes
    end

    local sourceRecipes = MC.data.recipes[professionId] or {}
    for _, recipe in ipairs(sourceRecipes) do
        if category == "overall" or MC:GetRecipeCategory(recipe, state) == category then
            table.insert(recipes, recipe)
        end
    end

    MC.ui.filteredRecipes = recipes
    return recipes
end

local function FormatRequirements(recipe)
    if type(recipe) ~= "table" then
        return "Requirements: None"
    end

    local parts = {}
    if recipe.requiredSkill ~= nil then
        table.insert(parts, "Skill " .. tostring(recipe.requiredSkill))
    end
    if recipe.faction ~= nil and recipe.faction ~= "" and recipe.faction ~= "Neutral" and recipe.faction ~= "Both" then
        table.insert(parts, "Faction: " .. tostring(recipe.faction))
    end
    if recipe.reputation ~= nil then
        if type(recipe.reputation) == "table" then
            table.insert(parts, "Reputation: " .. tostring(recipe.reputation.name or recipe.reputation.faction or recipe.reputation.factionName or "required"))
        else
            table.insert(parts, "Reputation: " .. tostring(recipe.reputation))
        end
    end

    if #parts == 0 then
        return "Requirements: None"
    end

    return "Requirements: " .. table.concat(parts, ", ")
end

ShowRecipeDetails = function(recipe)
    MC.ui.selectedRecipe = recipe

    if type(recipe) ~= "table" then
        detailTitle:SetText("Select a recipe")
        detailSource:SetText("Source: -")
        detailRequirements:SetText("Requirements: -")
        detailNotes:SetText("Notes: -")
        detailVerified:SetText("Verified: -")
        return
    end

    detailTitle:SetText(recipe.name or "Unknown recipe")
    detailSource:SetText("Source: " .. tostring(recipe.sourceText or recipe.sourceType or "Unknown"))
    detailRequirements:SetText(FormatRequirements(recipe))
    detailNotes:SetText("Notes: " .. tostring(recipe.notes or "None"))
    detailVerified:SetText("Verified: " .. (recipe.verified and "Yes" or "No"))
end

UpdateRecipeList = function()
    local recipes = MC.ui.filteredRecipes or BuildRecipeList()
    local offset = FauxScrollFrame_GetOffset(recipeScroll) or 0
    local state = GetCharacterState()

    FauxScrollFrame_Update(recipeScroll, #recipes, VISIBLE_ROWS, ROW_HEIGHT)

    for rowIndex = 1, VISIBLE_ROWS do
        local button = recipeRows[rowIndex]
        local recipe = recipes[offset + rowIndex]
        if recipe then
            local category = MC:GetRecipeCategory(recipe, state)
            button.recipe = recipe
            button:SetText((recipe.name or "Unknown recipe") .. " [" .. category .. "]")
            button:Show()
        else
            button.recipe = nil
            button:Hide()
        end
    end
end

local function UpdateProfessionButtons()
    if type(MC.data) ~= "table" or type(MC.data.professionOrder) ~= "table" then
        return
    end

    for index, professionId in ipairs(MC.data.professionOrder) do
        local button = professionButtons[index]
        if button then
            button:SetText(GetProfessionName(professionId))
            SetButtonChecked(button, professionId == MC.ui.selectedProfession)
            button:Show()
        end
    end
end

local function UpdateCategoryButtons()
    for _, tab in ipairs(CATEGORY_TABS) do
        SetButtonChecked(categoryButtons[tab.key], tab.key == MC.ui.selectedCategory)
    end
end

UpdateUI = function()
    SelectFirstProfession()
    BuildRecipeList()
    titleText:SetText("MaddinCrafts - " .. GetProfessionName(MC.ui.selectedProfession))
    UpdateProfessionButtons()
    UpdateCategoryButtons()
    UpdateRecipeList()

    if MC.ui.selectedRecipe then
        ShowRecipeDetails(MC.ui.selectedRecipe)
    else
        ShowRecipeDetails(nil)
    end
end

local function CreateProfessionButtons(parent)
    if type(MC.data) ~= "table" or type(MC.data.professionOrder) ~= "table" then
        return
    end

    for index, professionId in ipairs(MC.data.professionOrder) do
        local button = CreateFrame("CheckButton", "MaddinCraftsProfession" .. index, parent, "UIRadioButtonTemplate")
        button:SetWidth(150)
        button:SetHeight(20)
        if index == 1 then
            button:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -38)
        else
            button:SetPoint("TOPLEFT", professionButtons[index - 1], "BOTTOMLEFT", 0, -2)
        end
        button:SetText(GetProfessionName(professionId))
        button.professionId = professionId
        button:SetScript("OnClick", function(self)
            MC.ui.selectedProfession = self.professionId
            MC.ui.selectedRecipe = nil
            UpdateUI()
        end)
        professionButtons[index] = button
    end
end

local function CreateCategoryButtons(parent)
    local previous
    for _, tab in ipairs(CATEGORY_TABS) do
        local button = CreateFrame("CheckButton", "MaddinCraftsCategory" .. tab.key, parent, "UIRadioButtonTemplate")
        button:SetWidth(100)
        button:SetHeight(20)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        else
            button:SetPoint("TOPLEFT", parent, "TOPLEFT", 180, -38)
        end
        button:SetText(tab.label)
        button.category = tab.key
        button:SetScript("OnClick", function(self)
            MC.ui.selectedCategory = self.category
            MC.ui.selectedRecipe = nil
            UpdateUI()
        end)
        categoryButtons[tab.key] = button
        previous = button
    end
end

local function CreateRecipeList(parent)
    recipeScroll = CreateFrame("ScrollFrame", "MaddinCraftsRecipeScroll", parent, "FauxScrollFrameTemplate")
    recipeScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 180, -68)
    recipeScroll:SetWidth(260)
    recipeScroll:SetHeight(VISIBLE_ROWS * ROW_HEIGHT)
    recipeScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, UpdateRecipeList)
    end)

    for index = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", "MaddinCraftsRecipeRow" .. index, parent)
        row:SetWidth(250)
        row:SetHeight(ROW_HEIGHT)
        row:SetNormalFontObject("GameFontNormalSmall")
        row:SetHighlightFontObject("GameFontHighlightSmall")
        row:SetText("Recipe")
        if index == 1 then
            row:SetPoint("TOPLEFT", recipeScroll, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", recipeRows[index - 1], "BOTTOMLEFT", 0, 0)
        end
        row:SetScript("OnClick", function(self)
            ShowRecipeDetails(self.recipe)
        end)
        recipeRows[index] = row
    end
end

local function CreateDetailPanel(parent)
    local detail = CreateFrame("Frame", "MaddinCraftsDetailPanel", parent)
    detail:SetPoint("TOPLEFT", parent, "TOPLEFT", 455, -68)
    detail:SetWidth(245)
    detail:SetHeight(360)

    detailTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detailTitle:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
    detailTitle:SetWidth(235)
    detailTitle:SetJustifyH("LEFT")

    detailSource = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailSource:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -12)
    detailSource:SetWidth(235)
    detailSource:SetJustifyH("LEFT")

    detailRequirements = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailRequirements:SetPoint("TOPLEFT", detailSource, "BOTTOMLEFT", 0, -10)
    detailRequirements:SetWidth(235)
    detailRequirements:SetJustifyH("LEFT")

    detailNotes = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailNotes:SetPoint("TOPLEFT", detailRequirements, "BOTTOMLEFT", 0, -10)
    detailNotes:SetWidth(235)
    detailNotes:SetJustifyH("LEFT")

    detailVerified = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailVerified:SetPoint("TOPLEFT", detailNotes, "BOTTOMLEFT", 0, -10)
    detailVerified:SetWidth(235)
    detailVerified:SetJustifyH("LEFT")
end

local function CreateMainFrame()
    frame = CreateFrame("Frame", "MaddinCraftsFrame", UIParent)
    frame:SetWidth(720)
    frame:SetHeight(450)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()

    titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -14)
    titleText:SetText("MaddinCrafts")

    local close = CreateFrame("Button", "MaddinCraftsCloseButton", frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    CreateProfessionButtons(frame)
    CreateCategoryButtons(frame)
    CreateRecipeList(frame)
    CreateDetailPanel(frame)
    ShowRecipeDetails(nil)

    MC.ui.frame = frame
end

function MC:ShowUI()
    if not frame then
        CreateMainFrame()
    end
    UpdateUI()
    frame:Show()
end

function MC:HideUI()
    if frame then
        frame:Hide()
    end
end

function MC:ToggleUI()
    if not frame then
        CreateMainFrame()
    end

    if frame:IsShown() then
        self:HideUI()
    else
        self:ShowUI()
    end
end

CreateMainFrame()

SLASH_MADDINCRAFTS1 = "/maddincrafts"
SLASH_MADDINCRAFTS2 = "/mc"
SLASH_MADDINCRAFTS3 = "/mcrafts"
SlashCmdList["MADDINCRAFTS"] = function()
    MC:ToggleUI()
end
