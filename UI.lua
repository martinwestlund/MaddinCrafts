local MC = MaddinCrafts

local ROW_HEIGHT = 20
local VISIBLE_ROWS = 15
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
MC.ui.pageOffset = MC.ui.pageOffset or 0

local frame
local professionButtons = {}
local categoryButtons = {}
local recipeRows = {}
local titleText
local statusText
local detailTitle
local detailSource
local detailRequirements
local detailNotes
local detailVerified
local prevButton
local nextButton

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

local function HasRecipes(professionId)
    return type(MC.data) == "table"
        and type(MC.data.recipes) == "table"
        and type(MC.data.recipes[professionId]) == "table"
        and #MC.data.recipes[professionId] > 0
end

local function SelectFirstProfession()
    if HasRecipes(MC.ui.selectedProfession) then
        return
    end

    if type(MC.data) ~= "table" or type(MC.data.professionOrder) ~= "table" then
        MC.ui.selectedProfession = nil
        return
    end

    for _, professionId in ipairs(MC.data.professionOrder) do
        if HasRecipes(professionId) then
            MC.ui.selectedProfession = professionId
            return
        end
    end

    MC.ui.selectedProfession = MC.data.professionOrder[1]
end

local function SetButtonSelected(button, selected)
    if not button then
        return
    end

    if selected then
        button:LockHighlight()
    else
        button:UnlockHighlight()
    end
end

local function SetFontStringText(fontString, text)
    if fontString and fontString.SetText then
        fontString:SetText(text)
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
    if MC.ui.pageOffset >= #recipes then
        MC.ui.pageOffset = 0
    end
    return recipes
end

local function FormatRequirements(recipe)
    if type(recipe) ~= "table" then
        return "Requirements: None"
    end

    local parts = {}
    if recipe.requiredSkill ~= nil then
        if recipe.requiredSkill <= 0 then
            table.insert(parts, "Skill: unknown")
        else
            table.insert(parts, "Skill " .. tostring(recipe.requiredSkill))
        end
    end
    if recipe.faction ~= nil and recipe.faction ~= "" and recipe.faction ~= "Neutral" and recipe.faction ~= "Both" then
        table.insert(parts, "Faction: " .. tostring(recipe.faction))
    end
    if recipe.reputation ~= nil then
        table.insert(parts, "Reputation: " .. tostring(recipe.reputation))
    end

    if #parts == 0 then
        return "Requirements: None"
    end

    return "Requirements: " .. table.concat(parts, ", ")
end

ShowRecipeDetails = function(recipe)
    MC.ui.selectedRecipe = recipe

    if type(recipe) ~= "table" then
        SetFontStringText(detailTitle, "Select a recipe")
        SetFontStringText(detailSource, "Source: -")
        SetFontStringText(detailRequirements, "Requirements: -")
        SetFontStringText(detailNotes, "Notes: -")
        SetFontStringText(detailVerified, "Verified: -")
        return
    end

    SetFontStringText(detailTitle, recipe.name or "Unknown recipe")
    SetFontStringText(detailSource, "Source: " .. tostring(recipe.sourceText or recipe.sourceType or "Unknown"))
    SetFontStringText(detailRequirements, FormatRequirements(recipe))
    SetFontStringText(detailNotes, "Notes: " .. tostring(recipe.notes or "None"))
    SetFontStringText(detailVerified, "Verified: " .. (recipe.verified and "Yes" or "No"))
end

UpdateRecipeList = function()
    local recipes = MC.ui.filteredRecipes or BuildRecipeList()
    local total = #recipes
    local offset = MC.ui.pageOffset or 0
    local state = GetCharacterState()
    local professionId = MC.ui.selectedProfession
    local allForProfession = 0

    if type(MC.data) == "table" and type(MC.data.recipes) == "table" and type(MC.data.recipes[professionId]) == "table" then
        allForProfession = #MC.data.recipes[professionId]
    end

    if professionId == nil then
        SetFontStringText(statusText, "No profession data loaded. Check that the MaddinCrafts/data files are installed.")
    else
        SetFontStringText(statusText, GetProfessionName(professionId) .. ": " .. tostring(total) .. " shown / " .. tostring(allForProfession) .. " total")
    end

    for rowIndex = 1, VISIBLE_ROWS do
        local button = recipeRows[rowIndex]
        local recipe = recipes[offset + rowIndex]
        if recipe then
            local category = MC:GetRecipeCategory(recipe, state)
            button.recipe = recipe
            button:SetText((offset + rowIndex) .. ". " .. (recipe.name or "Unknown recipe") .. " [" .. category .. "]")
            button:Show()
        else
            button.recipe = nil
            button:SetText("")
            button:Hide()
        end
    end

    if prevButton then
        if offset > 0 then prevButton:Enable() else prevButton:Disable() end
    end
    if nextButton then
        if offset + VISIBLE_ROWS < total then nextButton:Enable() else nextButton:Disable() end
    end
end

local function UpdateProfessionButtons()
    for index, button in ipairs(professionButtons) do
        local professionId = button.professionId
        local count = 0
        if type(MC.data) == "table" and type(MC.data.recipes) == "table" and type(MC.data.recipes[professionId]) == "table" then
            count = #MC.data.recipes[professionId]
        end
        button:SetText(GetProfessionName(professionId) .. " (" .. tostring(count) .. ")")
        SetButtonSelected(button, professionId == MC.ui.selectedProfession)
        button:Show()
    end
end

local function UpdateCategoryButtons()
    for _, tab in ipairs(CATEGORY_TABS) do
        SetButtonSelected(categoryButtons[tab.key], tab.key == MC.ui.selectedCategory)
    end
end

UpdateUI = function()
    SelectFirstProfession()
    BuildRecipeList()
    SetFontStringText(titleText, "MaddinCrafts - " .. GetProfessionName(MC.ui.selectedProfession))
    UpdateProfessionButtons()
    UpdateCategoryButtons()
    UpdateRecipeList()

    if MC.ui.selectedRecipe then
        ShowRecipeDetails(MC.ui.selectedRecipe)
    else
        ShowRecipeDetails(nil)
    end
end

local function CreateTextButton(name, parent, width, height, text)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetText(text or "")
    return button
end

local function CreateProfessionButtons(parent)
    local order = MC.data and MC.data.professionOrder or {}
    local visibleIndex = 0

    for _, professionId in ipairs(order) do
        if HasRecipes(professionId) then
            visibleIndex = visibleIndex + 1
            local button = CreateTextButton("MaddinCraftsProfession" .. visibleIndex, parent, 150, 20, GetProfessionName(professionId))
            if visibleIndex == 1 then
                button:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -42)
            else
                button:SetPoint("TOPLEFT", professionButtons[visibleIndex - 1], "BOTTOMLEFT", 0, -3)
            end
            button.professionId = professionId
            button:SetScript("OnClick", function(self)
                MC.ui.selectedProfession = self.professionId
                MC.ui.selectedRecipe = nil
                MC.ui.pageOffset = 0
                UpdateUI()
            end)
            professionButtons[visibleIndex] = button
        end
    end
end

local function CreateCategoryButtons(parent)
    local previous
    for _, tab in ipairs(CATEGORY_TABS) do
        local button = CreateTextButton("MaddinCraftsCategory" .. tab.key, parent, 86, 22, tab.label)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
        else
            button:SetPoint("TOPLEFT", parent, "TOPLEFT", 185, -42)
        end
        button.category = tab.key
        button:SetScript("OnClick", function(self)
            MC.ui.selectedCategory = self.category
            MC.ui.selectedRecipe = nil
            MC.ui.pageOffset = 0
            UpdateUI()
        end)
        categoryButtons[tab.key] = button
        previous = button
    end
end

local function CreateRecipeList(parent)
    for index = 1, VISIBLE_ROWS do
        local row = CreateTextButton("MaddinCraftsRecipeRow" .. index, parent, 335, ROW_HEIGHT, "")
        row:SetNormalFontObject("GameFontNormalSmall")
        row:SetHighlightFontObject("GameFontHighlightSmall")
        if index == 1 then
            row:SetPoint("TOPLEFT", parent, "TOPLEFT", 185, -92)
        else
            row:SetPoint("TOPLEFT", recipeRows[index - 1], "BOTTOMLEFT", 0, -1)
        end
        row:SetScript("OnClick", function(self)
            ShowRecipeDetails(self.recipe)
        end)
        recipeRows[index] = row
    end

    prevButton = CreateTextButton("MaddinCraftsPrevPage", parent, 70, 22, "Prev")
    prevButton:SetPoint("TOPLEFT", recipeRows[VISIBLE_ROWS], "BOTTOMLEFT", 0, -8)
    prevButton:SetScript("OnClick", function()
        MC.ui.pageOffset = math.max(0, (MC.ui.pageOffset or 0) - VISIBLE_ROWS)
        UpdateRecipeList()
    end)

    nextButton = CreateTextButton("MaddinCraftsNextPage", parent, 70, 22, "Next")
    nextButton:SetPoint("LEFT", prevButton, "RIGHT", 8, 0)
    nextButton:SetScript("OnClick", function()
        local total = #(MC.ui.filteredRecipes or {})
        local nextOffset = (MC.ui.pageOffset or 0) + VISIBLE_ROWS
        if nextOffset < total then
            MC.ui.pageOffset = nextOffset
        end
        UpdateRecipeList()
    end)
end

local function CreateDetailPanel(parent)
    local detail = CreateFrame("Frame", "MaddinCraftsDetailPanel", parent)
    detail:SetPoint("TOPLEFT", parent, "TOPLEFT", 535, -92)
    detail:SetWidth(250)
    detail:SetHeight(390)

    detailTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detailTitle:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
    detailTitle:SetWidth(235)
    detailTitle:SetJustifyH("LEFT")

    detailSource = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailSource:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -12)
    detailSource:SetWidth(235)
    detailSource:SetJustifyH("LEFT")

    detailRequirements = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailRequirements:SetPoint("TOPLEFT", detailSource, "BOTTOMLEFT", 0, -12)
    detailRequirements:SetWidth(235)
    detailRequirements:SetJustifyH("LEFT")

    detailNotes = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailNotes:SetPoint("TOPLEFT", detailRequirements, "BOTTOMLEFT", 0, -12)
    detailNotes:SetWidth(235)
    detailNotes:SetJustifyH("LEFT")

    detailVerified = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailVerified:SetPoint("TOPLEFT", detailNotes, "BOTTOMLEFT", 0, -12)
    detailVerified:SetWidth(235)
    detailVerified:SetJustifyH("LEFT")
end

local function CreateMainFrame()
    frame = CreateFrame("Frame", "MaddinCraftsFrame", UIParent)
    frame:SetWidth(810)
    frame:SetHeight(470)
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
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
    titleText:SetText("MaddinCrafts")

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", frame, "TOPLEFT", 185, -70)
    statusText:SetWidth(560)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("Loading recipe data...")

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

SLASH_MADDINCRAFTS1 = "/maddincrafts"
SLASH_MADDINCRAFTS2 = "/mc"
SLASH_MADDINCRAFTS3 = "/mcrafts"
SlashCmdList["MADDINCRAFTS"] = function()
    MC:ToggleUI()
end
