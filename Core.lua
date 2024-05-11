---@class RemixGemHelperPrivate
local Private = select(2, ...)

local const = Private.constants
local gemUtil = Private.GemUtil
local cache = Private.Cache

for itemID in pairs(const.GEM_SOCKET_TYPE) do
    cache:CacheItemInfo(itemID)
end

local function createExtractBtn(parent)
    ---@class ExtractButton : Button
    ---@field UpdateInfo fun(self:ExtractButton, infoType:"SOCKET"|"BAG", infoIndex:number, infoSlot:number, infoGemType:"Meta"|"Cogwheel"|"Tinker"|"Prismatic"|"Primordial")
    local btn = CreateFrame("Button", nil, parent, "InsecureActionButtonTemplate")
    btn:SetScript("PreClick", function(self)
        if not self.info then return end
        local info = self.info
        if info.type == "SOCKET" then
            SocketInventoryItem(info.index)
        elseif info.type == "BAG" then
            local equipSlot, equipSocket = gemUtil.GetFreeSocket(info.gemType)
            C_Container.PickupContainerItem(info.index, info.slot)
            SocketInventoryItem(equipSlot)
            info.gemSlot = equipSocket
        end
    end)
    btn:SetScript("PostClick", function(self)
        if not self.info then return end
        local info = self.info
        if info.type == "SOCKET" then
            ClickSocketButton(info.slot)
        elseif info.type == "BAG" then
            ClearCursor()
            if not info.gemSlot then
                UIErrorsFrame:AddExternalErrorMessage("You don't have a valid free Slot for this Gem")
                CloseSocketInfo()
                return
            end
            C_Container.PickupContainerItem(info.index, info.slot)
            ClickSocketButton(info.gemSlot)
            AcceptSockets()
        end
        CloseSocketInfo()
    end)
    btn:SetAllPoints()
    btn:RegisterForClicks("AnyDown")
    btn:SetAttribute("type", "macro")

    function btn:UpdateInfo(infoType, infoIndex, infoSlot, infoGemType)
        self.info = {
            type = infoType,
            index = infoIndex,
            slot = infoSlot,
            gemType = infoGemType,
            gemSlot = 0,
        }
        local txt = ""
        if infoType == "SOCKET" then
            txt = "/cast " .. const.EXTRACT_GEM_SPELL
            if infoGemType == "Primordial" then
                txt = "/click ExtraActionButton1"
            end
        end
        self:SetAttribute("macrotext", txt)
    end

    return btn
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    eventFrame:UnregisterAllEvents()
    ---@class GemsFrame : Frame
    ---@field CloseButton Button
    ---@field SetTitle fun(self:GemsFrame, title:string)
    ---@field Inset Frame
    ---@field TopTileStreaks Frame
    local gems = CreateFrame("Frame", nil, CharacterStatsPane, "ButtonFrameTemplate")
    gems:SetTitle("Remix Gems Manager")
    gems:RegisterEvent("BAG_UPDATE_DELAYED")
    gems:SetWidth(300)
    gems:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMRIGHT")
    gems:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT")

    ButtonFrameTemplate_HidePortrait(gems)
    gems.CloseButton:Hide()
    gems.Inset:ClearAllPoints()
    gems.Inset:SetPoint("TOP", 0, -65)
    gems.Inset:SetPoint("BOTTOM", 0, 35)
    gems.Inset:SetPoint("LEFT", 20, 0)
    gems.Inset:SetPoint("RIGHT", -20, 0)

    ---@class SearchFrame : EditBox
    ---@field Instructions FontString
    local search = CreateFrame("EditBox", nil, gems, "InputBoxInstructionsTemplate")
    search.Instructions:SetText("Search Gems")
    search:ClearFocus()
    search:SetAutoFocus(false)
    search:SetPoint("TOPRIGHT", gems.TopTileStreaks, -5, -15)
    search:SetPoint("BOTTOMLEFT", gems.TopTileStreaks, "BOTTOM", 0, 15)

    ---@class Dropdown : Frame
    ---@field SetValue fun(self:Dropdown, ...:any)
    ---@field Text FontString
    local dropDown = CreateFrame("Frame", nil, gems, "UIDropDownMenuTemplate")
    dropDown:SetPoint("TOPLEFT", gems.TopTileStreaks, -10, -10)
    dropDown:SetPoint("RIGHT", search, "LEFT", -15, 0)
    function dropDown:UpdateSelection(selection)
        self.selection = selection
        self.Text:SetText(gemUtil.GetSocketTypeName(selection))
        CloseDropDownMenus()
    end

    local version = gems:CreateFontString(nil, "ARTWORK", "GameFontDisableSmallLeft")
    version:SetPoint("BOTTOMLEFT", 22, 15)
    version:SetText(string.format("v%s By Rasu", const.ADDON_VERSION))

    UIDropDownMenu_Initialize(dropDown, function(self)
        local info = UIDropDownMenu_CreateInfo()
        for i = 0, #const.SOCKET_TYPES_INDEX do
            info.func = self.SetValue
            info.arg1 = i
            info.checked = dropDown.selection == i
            info.text = gemUtil.GetSocketTypeName(i)
            UIDropDownMenu_AddButton(info)
        end
        dropDown:UpdateSelection(dropDown.selection or 0)
    end)

    ---@class ScrollBox : Frame
    ---@field GetScrollPercentage fun(self:ScrollBox)
    ---@field SetScrollPercentage fun(self:ScrollBox, percentage:number)
    local scrollBox = CreateFrame("Frame", nil, gems, "WowScrollBoxList")
    scrollBox:SetAllPoints(gems.Inset)

    ---@class MinimalScrollBar : EventFrame
    ---@field SetHideIfUnscrollable fun(self:MinimalScrollBar, state:boolean)
    local scrollBar = CreateFrame("EventFrame", nil, gems, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 5, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT")
    scrollBar:SetHideIfUnscrollable(true)

    local scrollView = CreateScrollBoxListLinearView()
    scrollView:SetElementInitializer("BackDropTemplate", function(frame, data)
        ---@class GemListEntry : Frame
        ---@field Name FontString
        ---@field Icon Texture
        ---@field Highlight Texture
        ---@field Stripe Texture
        ---@field Extract ExtractButton
        ---@field initialized boolean
        ---@field index number
        ---@field isHeader boolean|?
        ---@field id number|?
        ---@cast frame GemListEntry
        local index = data.index
        local isHeader = data.isHeader or false
        local icon = data.icon
        local name = data.text

        if not frame.initialized then
            local font = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
            font:SetPoint("LEFT", 5, 0)
            frame.Name = font

            local texture = frame:CreateTexture(nil, "OVERLAY")
            texture:SetPoint("RIGHT", -5, 0)
            texture:SetSize(16, 16)
            frame.Icon = texture

            local highlight = frame:CreateTexture()
            highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            highlight:SetPoint("BOTTOMLEFT", 5, 0)
            highlight:SetPoint("TOPRIGHT", -5, 0)
            frame.Highlight = highlight
            highlight:Hide()

            local stripe = frame:CreateTexture()
            stripe:SetColorTexture(1, 1, 1, .08)
            stripe:SetPoint("BOTTOMLEFT", 5, 0)
            stripe:SetPoint("TOPRIGHT", -5, 0)
            frame.Stripe = stripe

            local extractButton = createExtractBtn(frame)
            frame.Extract = extractButton

            frame:SetScript("OnEnter", function(self)
                self.Highlight:Show()
                if self.id then
                    GameTooltip:ClearLines()
                    GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
                    GameTooltip:SetHyperlink("item:" .. self.id)
                    GameTooltip:Show()
                end
            end)

            frame:SetScript("OnLeave", function(self)
                self.Highlight:Hide()
                if self.id then
                    GameTooltip:Hide()
                end
            end)

            extractButton:HookScript("OnEnter", function()
                frame:GetScript("OnEnter")(frame)
            end)
            extractButton:HookScript("OnLeave", function()
                frame:GetScript("OnLeave")(frame)
            end)

            frame.initialized = true
        end

        frame.Name:SetText(name)
        frame.Name:SetFontObject("GameFontHighlightLeft")
        frame.Icon:SetTexture(icon)
        if (isHeader) then
            frame.Name:SetFontObject("GameFontNormal")
            frame.Extract:Hide()
        else
            frame.Extract:Show()
            local exInf = data.info
            frame.Extract:UpdateInfo(
                exInf.type,
                exInf.index,
                exInf.slot,
                exInf.gemType
            )
            local state, color
            if exInf.type == "SOCKET" then
                state, color = "Socketed", const.COLORS.POSITIVE
            else
                state, color = "In Bag", const.COLORS.NEGATIVE
            end
            frame.Name:SetText(string.format("%s (%s)", data.name, color:WrapTextInColorCode(state)))
        end

        frame.index = index
        frame.isHeader = isHeader
        frame.id = data.id
        frame.Stripe:SetShown(data.index % 2 == 1)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, scrollView)

    scrollView:SetElementExtent(20)

    function scrollView:UpdateTree(data)
        if not data then return end
        local scrollPercent = scrollBox:GetScrollPercentage()
        self:Flush()
        local dataProvider = CreateDataProvider()
        self:SetDataProvider(dataProvider)
        for category, categoryData in pairs(data) do
            if #categoryData > 0 then
                dataProvider:Insert({ text = category, isHeader = true, icon = const.SOCKET_TYPE_INFO[category].icon, index = 0 })
                sort(categoryData, function(a, b)
                    return a.itemID > b.itemID
                end)
                for itemIndex, itemInfo in ipairs(categoryData) do
                    local cachedInfo = cache:GetItemInfo(itemInfo.itemID)
                    dataProvider:Insert({
                        id = itemInfo.itemID,
                        icon = cachedInfo.icon,
                        name = cachedInfo.name,
                        index =
                            itemIndex,
                        info = itemInfo
                    })
                end
            end
        end
        scrollBox:SetScrollPercentage(scrollPercent or 1)
    end

    function dropDown:SetValue(selIndex)
        dropDown:UpdateSelection(selIndex)
        scrollView:UpdateTree(gemUtil:GetFilteredGems(dropDown.selection))
    end

    search:HookScript("OnTextChanged", function(self)
        scrollView:UpdateTree(gemUtil:GetFilteredGems(dropDown.selection, self:GetText() or ""))
    end)

    gems:SetScript("OnEvent", function(_, event)
        if event == "BAG_UPDATE_DELAYED" then
            scrollView:UpdateTree(gemUtil:GetFilteredGems(dropDown.selection, search:GetText() or ""))
        end
    end)


    scrollView:UpdateTree(gemUtil:GetFilteredGems(dropDown.selection))
end)
