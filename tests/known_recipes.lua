local RECIPE_ITEM_ID = 6948

local function stripColorCodes(text)
    if not text then
        return nil
    end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function isTooltipLineKnown(line)
    if not line then
        return false
    end

    if Enum.TooltipDataLineType.RestrictedSpellKnown and line.type == Enum.TooltipDataLineType.RestrictedSpellKnown then
        return true
    end

    local leftText = stripColorCodes(line.leftText)
    return (ITEM_SPELL_KNOWN and leftText == ITEM_SPELL_KNOWN) or leftText == "Already known"
end

local function tooltipHasKnownLine(tooltipInfo)
    if not tooltipInfo or not tooltipInfo.lines then
        return false
    end

    for _, line in next, tooltipInfo.lines do
        if isTooltipLineKnown(line) then
            return true
        end
    end

    return false
end

local recipeTooltipTitlePrefixes = {
    "Plans:",
    "Recipe:",
    "Pattern:",
    "Formula:",
    "Technique:",
    "Schematic:",
    "Design:",
    "Manual:",
    "Tome:",
}

local function tooltipLineStartsWithRecipePrefix(leftText)
    for _, prefix in next, recipeTooltipTitlePrefixes do
        if leftText:sub(1, #prefix) == prefix then
            return true
        end
    end

    return false
end

local function tooltipLineLooksLikeRecipe(leftText)
    if not leftText then
        return false
    end

    if tooltipLineStartsWithRecipePrefix(leftText) then
        return true
    end

    return leftText:find("Teaches you how to craft", 1, true) ~= nil
end

local function tooltipLooksLikeRecipe(tooltipInfo)
    if not tooltipInfo or not tooltipInfo.lines then
        return false
    end

    for _, line in next, tooltipInfo.lines do
        local leftText = stripColorCodes(line.leftText)
        if tooltipLineLooksLikeRecipe(leftText) then
            return true
        end
    end

    return false
end

local function getTooltipInfo(itemId, merchantIndex)
    if merchantIndex and C_TooltipInfo.GetMerchantItem then
        local tooltipInfo = C_TooltipInfo.GetMerchantItem(merchantIndex)
        if tooltipInfo and tooltipInfo.lines then
            return tooltipInfo
        end
    end

    return C_TooltipInfo.GetItemByID(itemId)
end

local function isRecipe(itemId, merchantIndex)
    local classId = select(6, C_Item.GetItemInfoInstant(itemId))
    if classId == Enum.ItemClass.Recipe then
        return true
    end

    return tooltipLooksLikeRecipe(getTooltipInfo(itemId, merchantIndex))
end

local function isRecipeCollected(itemId, merchantIndex)
    local tooltipInfo = getTooltipInfo(itemId, merchantIndex)
    return tooltipHasKnownLine(tooltipInfo)
end

local function validateRecipeHideCollected(itemId, merchantIndex)
    if isRecipe(itemId, merchantIndex) then
        return not isRecipeCollected(itemId, merchantIndex)
    end
    return true
end

local function validateRecipesOnly(itemId, merchantIndex)
    if not isRecipe(itemId, merchantIndex) then
        return false
    end
    return not isRecipeCollected(itemId, merchantIndex)
end

local function withRecipeStubs(fn)
    local originalGetItemInfoInstant = C_Item.GetItemInfoInstant
    local originalGetItemByID = C_TooltipInfo.GetItemByID
    local originalGetMerchantItem = C_TooltipInfo.GetMerchantItem

    C_Item.GetItemInfoInstant = function(itemId, ...)
        if itemId == RECIPE_ITEM_ID then
            return nil, nil, nil, nil, nil, Enum.ItemClass.Tradegoods, 0
        end
        return originalGetItemInfoInstant(itemId, ...)
    end

    C_TooltipInfo.GetItemByID = function(itemId, ...)
        if itemId == RECIPE_ITEM_ID then
            return {
                lines = {
                    {leftText = "Plans: Test Recipe"},
                    {leftText = "Teaches you how to craft a test item."},
                },
            }
        end
        return originalGetItemByID(itemId, ...)
    end

    C_TooltipInfo.GetMerchantItem = function(slot, ...)
        if slot == 1 then
            return {
                lines = {
                    {leftText = "Plans: Known Test Recipe"},
                    {leftText = "Teaches you how to craft a test item."},
                    {leftText = ITEM_SPELL_KNOWN or "Already known"},
                },
            }
        elseif slot == 2 then
            return {
                lines = {
                    {leftText = "Plans: Unknown Test Recipe"},
                    {leftText = "Teaches you how to craft a test item."},
                },
            }
        end
        return originalGetMerchantItem(slot, ...)
    end

    local ok, err = pcall(fn)

    C_Item.GetItemInfoInstant = originalGetItemInfoInstant
    C_TooltipInfo.GetItemByID = originalGetItemByID
    C_TooltipInfo.GetMerchantItem = originalGetMerchantItem

    if not ok then
        error(err, 0)
    end
end

test("known merchant recipes are hidden when the item class is not Recipe", function()
    withRecipeStubs(function()
        assertTrue(isRecipe(RECIPE_ITEM_ID, 1))
        assertTrue(isRecipeCollected(RECIPE_ITEM_ID, 1))
        assertFalse(isRecipeCollected(RECIPE_ITEM_ID, 2))

        assertFalse(validateRecipeHideCollected(RECIPE_ITEM_ID, 1))
        assertFalse(validateRecipesOnly(RECIPE_ITEM_ID, 1))
        assertTrue(validateRecipesOnly(RECIPE_ITEM_ID, 2))
    end)
end)
