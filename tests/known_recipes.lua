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

local function getTooltipInfo(itemId, merchantIndex)
    if merchantIndex and C_TooltipInfo.GetMerchantItem then
        local tooltipInfo = C_TooltipInfo.GetMerchantItem(merchantIndex)
        if tooltipInfo and tooltipInfo.lines then
            return tooltipInfo
        end
    end

    return C_TooltipInfo.GetItemByID(itemId)
end

local function isRecipeCollected(itemId, merchantIndex)
    local tooltipInfo = getTooltipInfo(itemId, merchantIndex)
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

local function withRecipeStubs(fn)
    local originalGetItemInfoInstant = C_Item.GetItemInfoInstant
    local originalGetItemByID = C_TooltipInfo.GetItemByID
    local originalGetMerchantItem = C_TooltipInfo.GetMerchantItem

    C_Item.GetItemInfoInstant = function(itemId, ...)
        if itemId == RECIPE_ITEM_ID then
            return nil, nil, nil, nil, nil, Enum.ItemClass.Recipe, 0
        end
        return originalGetItemInfoInstant(itemId, ...)
    end

    C_TooltipInfo.GetItemByID = function(itemId, ...)
        if itemId == RECIPE_ITEM_ID then
            return {
                lines = {
                    {leftText = "Plans: Test Recipe"},
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
                    {leftText = ITEM_SPELL_KNOWN or "Already known"},
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

test("known merchant recipes are hidden by the Recipes filter", function()
    withRecipeStubs(function()
        assertFalse(isRecipeCollected(RECIPE_ITEM_ID))
        assertTrue(isRecipeCollected(RECIPE_ITEM_ID, 1))
    end)
end)
