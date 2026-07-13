local MC = MaddinCrafts

local professions = {
    { id = "ALCHEMY", name = "Alchemy", enabled = true, category = "profession" },
    { id = "BLACKSMITHING", name = "Blacksmithing", enabled = true, category = "profession" },
    { id = "ENCHANTING", name = "Enchanting", enabled = true, category = "profession" },
    { id = "ENGINEERING", name = "Engineering", enabled = true, category = "profession" },
    { id = "HERBALISM", name = "Herbalism", enabled = true, category = "gathering" },
    { id = "INSCRIPTION", name = "Inscription", enabled = false, category = "profession", notes = "Present in WotLK but disabled until Ascension support is verified." },
    { id = "JEWELCRAFTING", name = "Jewelcrafting", enabled = false, category = "profession", notes = "Present in WotLK but disabled until Ascension support is verified." },
    { id = "LEATHERWORKING", name = "Leatherworking", enabled = true, category = "profession" },
    { id = "MINING", name = "Mining", enabled = true, category = "gathering" },
    { id = "SKINNING", name = "Skinning", enabled = true, category = "gathering" },
    { id = "TAILORING", name = "Tailoring", enabled = true, category = "profession" },
    { id = "COOKING", name = "Cooking", enabled = true, category = "secondary" },
    { id = "FIRST_AID", name = "First Aid", enabled = true, category = "secondary" },
    { id = "FISHING", name = "Fishing", enabled = true, category = "secondary" },
    { id = "WOODCUTTING", name = "Woodcutting", enabled = true, category = "ascension" },
    { id = "WOODWORKING", name = "Woodworking", enabled = true, category = "ascension" },
}

for _, profession in ipairs(professions) do
    MC:RegisterProfession(profession)
end
