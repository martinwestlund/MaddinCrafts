local MC = MaddinCrafts

function MC:IsDebugEnabled()
    return type(MaddinCraftsDB) == "table" and MaddinCraftsDB.debug == true
end

function MC:Debug(message)
    if not self:IsDebugEnabled() then
        return
    end

    local text = "|cff33ff99MaddinCrafts|r " .. tostring(message)

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end
