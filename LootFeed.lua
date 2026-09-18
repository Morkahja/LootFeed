-- Vanilla 1.12 / Lua 5.0: deliberately uses legacy event globals and APIs.
local root = CreateFrame("Frame", "LootFeedFrame", UIParent)
local anchor = CreateFrame("Frame", "LootFeedAnchor", UIParent)
local rows, active, queue, patterns = {}, {}, {}, {}
local ready, unlocked, hovered, demo = false, false, nil, nil
local clock, nextInsert = 0, 0
local W, H, GAP, LIMIT = 270, 40, 5, 5
local COMPACT_SCALE = 0.9
local questScan = CreateFrame("GameTooltip", "LootFeedQuestScan", UIParent, "GameTooltipTemplate")
local defaults = { x = -48, y = 100, scale = 1, duration = 6, direction = "down", mute = false }

local function Say(s) DEFAULT_CHAT_FRAME:AddMessage("|cff75d9c5Loot Feed:|r " .. s) end
local function Place()
    anchor:ClearAllPoints()
    anchor:SetScale(LootFeedDB.scale)
    anchor:SetPoint("TOPRIGHT", UIParent, "RIGHT", LootFeedDB.x, LootFeedDB.y)
end

-- Match the client's translated self-loot formats, never another player's loot.
local function Compile(fmt)
    if not fmt then return nil end
    local p = string.gsub(fmt, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    p = string.gsub(p, "%%%%s", ".+")
    p = string.gsub(p, "%%%%d", "%%d+")
    return "^" .. p .. "$"
end
local function Personal(message)
    if not message then return false end
    for _, p in ipairs(patterns) do
        if string.find(message, p) then return true end
    end
    return false
end
local function MoneyIcon(message)
    -- Normalize all denominations to copper before choosing the icon.
    local text = string.lower(message or "")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    local units = {{GOLD or "Gold", 10000}, {SILVER or "Silver", 100}, {COPPER or "Copper", 1}}
    local copper = 0
    for _, unit in ipairs(units) do
        local name = string.gsub(string.lower(unit[1]), "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        for amount in string.gfind(text, "(%d+)%s*" .. name) do
            copper = copper + tonumber(amount) * unit[2]
        end
    end
    -- Verified visually from this Vanilla client's interface.MPQ:
    -- 01 gold, 03 silver, 05 copper (02/04/06 are alternate stacks).
    if copper >= 10000 then return "Interface\\Icons\\INV_Misc_Coin_01" end
    if copper >= 100 then return "Interface\\Icons\\INV_Misc_Coin_03" end
    return "Interface\\Icons\\INV_Misc_Coin_05"
end
local function IsQuestItem(link)
    if not link then return false end
    local _, _, item = string.find(link, "|H(.-)|h")
    if not item then return false end
    questScan:SetOwner(UIParent, "ANCHOR_NONE")
    questScan:ClearLines()
    questScan:SetHyperlink(item)
    local found = false
    for i = 1, questScan:NumLines() do
        local line = getglobal("LootFeedQuestScanTextLeft" .. i)
        if line and line:GetText() == (ITEM_BIND_QUEST or "Quest Item") then found = true; break end
    end
    questScan:Hide()
    return found
end
local function Refresh(row)
    local _, _, name = string.find(row.link or "", "%[(.-)%]")
    local _, _, id = string.find(row.link or "", "item:(%d+)")
    local itemName, itemLink, quality, level, kind, subtype, stack, equip, texture
    if id then itemName, itemLink, quality, level, kind, subtype, stack, equip, texture = GetItemInfo(tonumber(id)) end
    row.icon:SetTexture(texture or row.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    if row.link then row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    else row.icon:SetTexCoord(0, 1, 0, 1) end
    row.label:SetText(itemName or name or row.text or "Loot")
    local quest = IsQuestItem(row.link)
    row.quest:SetText(quest and (ITEM_BIND_QUEST or "Quest Item") or "")
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", 46, quest and 7 or 0)
    row.label:SetWidth(row.roll and W-162 or W-96)
    if row.roll then
        row.dice:Show(); row.winner:SetText(row.roll.winner or (row.roll.done and "Ended" or "Rolling"))
    else row.dice:Hide(); row.winner:SetText("") end
    local _, _, hex = string.find(row.link or "", "|c%x%x(%x%x%x%x%x%x)")
    local r, g, b = 0.92, 0.84, 0.62
    if hex then r = tonumber(string.sub(hex, 1, 2), 16)/255; g = tonumber(string.sub(hex, 3, 4), 16)/255; b = tonumber(string.sub(hex, 5, 6), 16)/255 end
    row.label:SetTextColor(r, g, b)
    row.edge:SetTexture(r, g, b, 0.9)
    row.count:SetText(not row.roll and row.amount > 1 and ("x" .. row.amount) or "")
    row.cached = texture ~= nil or row.link == nil
end
local function MakeRow(index)
    -- A stationary holder keeps the pop centered as the content scales.
    local holder = CreateFrame("Frame", nil, anchor)
    holder:SetWidth(W*COMPACT_SCALE); holder:SetHeight(H*COMPACT_SCALE)
    local row = CreateFrame("Button", "LootFeedRow" .. index, holder)
    row.holder = holder
    row:SetPoint("CENTER", holder, "CENTER", 0, 0)
    row:SetScale(COMPACT_SCALE)
    row:SetWidth(W); row:SetHeight(H); row:EnableMouse(true)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row); bg:SetTexture(0.025, 0.035, 0.045, 0.78)
    row.edge = row:CreateTexture(nil, "ARTWORK")
    row.edge:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0); row.edge:SetWidth(2); row.edge:SetHeight(H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", row, "LEFT", 7, 0); row.icon:SetWidth(30); row.icon:SetHeight(30)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", row, "LEFT", 46, 0); row.label:SetWidth(W-96); row.label:SetJustifyH("LEFT")
    row.quest = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.quest:SetPoint("LEFT", row, "LEFT", 46, -9)
    row.quest:SetTextColor(1, 0.82, 0.2)
    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.winner = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.winner:SetPoint("RIGHT", row, "RIGHT", -35, 0)
    row.winner:SetWidth(70); row.winner:SetJustifyH("RIGHT")
    row.dice = CreateFrame("Button", nil, row)
    row.dice:SetWidth(24); row.dice:SetHeight(28)
    row.dice:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.dice:EnableMouse(true)
    -- Draw a five-pip die directly; no client-specific texture paths.
    local die = row.dice:CreateTexture(nil,"ARTWORK")
    die:SetWidth(18); die:SetHeight(18); die:SetPoint("CENTER",row.dice,"CENTER",0,0)
    die:SetTexture(0.95,0.85,0.55,1)
    for _, pos in ipairs({{-5,5},{5,5},{0,0},{-5,-5},{5,-5}}) do
        local pip=row.dice:CreateTexture(nil,"OVERLAY")
        pip:SetWidth(3); pip:SetHeight(3); pip:SetPoint("CENTER",row.dice,"CENTER",pos[1],pos[2])
        pip:SetTexture(0.12,0.10,0.06,1)
    end
    row.dice:SetScript("OnEnter", function()
        hovered=this
        if row.roll then LootFeedRolls.Tooltip(row.roll,this) end
    end)
    row.dice:SetScript("OnLeave", function() hovered=nil; GameTooltip:Hide() end)
    row:SetScript("OnEnter", function()
        hovered = this
        if this.link then
            GameTooltip:SetOwner(this, "ANCHOR_LEFT")
            local _, _, item = string.find(this.link, "|H(.-)|h")
            if item then GameTooltip:SetHyperlink(item); GameTooltip:Show() end
        end
    end)
    row:SetScript("OnLeave", function() hovered = nil; GameTooltip:Hide() end)
    row:Hide()
    return row
end
local function Enqueue(entry)
    -- Coalesce only queued identical links; displayed entries keep their history.
    for _, pending in ipairs(queue) do
        if entry.link and pending.link == entry.link then pending.amount = pending.amount + entry.amount; return end
    end
    table.insert(queue, entry)
end
local function Insert()
    local entry = table.remove(queue, 1)
    local row
    for _, candidate in ipairs(rows) do if not candidate.used then row = candidate; break end end
    if not row then row=MakeRow(table.getn(rows)+1); table.insert(rows,row) end
    row.roll=nil
    row.used = true; row.link = entry.link; row.text = entry.text; row.texture = entry.texture; row.amount = entry.amount or 1
    row.age = 0; row.y = 0; row.retry = 0
    Refresh(row); table.insert(active, 1, row); row:Show()
end

local function RollChanged(roll)
    local row
    for _, candidate in ipairs(active) do if candidate.roll == roll then row=candidate; break end end
    if not row then
        for _, candidate in ipairs(rows) do if not candidate.used then row=candidate; break end end
        if not row then row=MakeRow(table.getn(rows)+1); table.insert(rows,row) end
        row.used=true; row.roll=roll; row.link=roll.link; row.texture=roll.texture
        row.text=nil; row.amount=roll.amount; row.age=0; row.y=0; row.retry=0
        row.resolved=false
        table.insert(active,1,row); row:Show()
    end
    if roll.done and (not row.resolved or row.resultStatus~=roll.status or row.resultWinner~=roll.winner) then
        row.resolved=true; row.age=0.32
    end
    row.resultStatus=roll.status; row.resultWinner=roll.winner
    Refresh(row)
    if hovered==row.dice then LootFeedRolls.Tooltip(roll,row.dice) end
end

anchor:SetWidth(W*COMPACT_SCALE); anchor:SetHeight(22); anchor:SetMovable(true); anchor:SetClampedToScreen(true)
anchor:EnableMouse(true); anchor:RegisterForDrag("LeftButton")
anchor:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); anchor:SetBackdropColor(0.08, 0.38, 0.34, 0.9)
local title = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
title:SetPoint("CENTER", anchor, "CENTER", 0, 0); title:SetText("Loot Feed - drag here /lfeed lock")
anchor:SetScript("OnDragStart", function() if unlocked then this:StartMoving() end end)
anchor:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local s = this:GetEffectiveScale() / UIParent:GetEffectiveScale()
    LootFeedDB.x = this:GetRight()*s - UIParent:GetRight()
    LootFeedDB.y = this:GetTop()*s - UIParent:GetHeight()/2
    Place()
end)
-- Keep the parent shown for its children; only hide the handle's artwork/mouse.
local function Lock(value)
    unlocked = not value
    anchor:EnableMouse(unlocked)
    title:SetAlpha(unlocked and 1 or 0)
    anchor:SetBackdropColor(0.08, 0.38, 0.34, unlocked and 0.9 or 0)
end

root:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "LootFeed" then
        if type(LootFeedDB) ~= "table" then LootFeedDB = {} end
        for k, v in pairs(defaults) do if type(LootFeedDB[k]) ~= type(v) then LootFeedDB[k] = v end end
        LootFeedDB.scale = math.max(0.6, math.min(1.8, LootFeedDB.scale))
        LootFeedDB.duration = math.max(2, math.min(20, LootFeedDB.duration))
        local keys = {"LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF", "LOOT_ITEM_CREATED_SELF_MULTIPLE"}
        for _, key in ipairs(keys) do local p = Compile(getglobal(key)); if p then table.insert(patterns, p) end end
        for i = 1, LIMIT do rows[i] = MakeRow(i) end
        LootFeedRolls.Init(RollChanged)
        Place(); Lock(true); ready = true
        -- Vanilla has no ChatFrame_AddMessageEventFilter. Chain its handler.
        local previous = ChatFrame_OnEvent
        if previous then
            ChatFrame_OnEvent = function(e)
                local ev = e or event
                if ready and LootFeedDB.mute and ev == "CHAT_MSG_LOOT" and Personal(arg1) then return end
                return previous(e)
            end
        end
    elseif ready and event == "CHAT_MSG_LOOT" then
        LootFeedRolls.Event(event,arg1,arg2)
        if Personal(arg1) then
            local _, _, link = string.find(arg1, "(|c%x+|Hitem:.-|h.-|h|r)")
            if link then
                local _, _, amount = string.find(arg1, "|h|r[xX](%d+)")
                Enqueue({link=link, amount=tonumber(amount) or 1})
            end
        end
    elseif ready and event == "CHAT_MSG_MONEY" then
        Enqueue({text=arg1, texture=MoneyIcon(arg1), amount=1})
    elseif ready then LootFeedRolls.Event(event,arg1,arg2)
    end
end)
root:RegisterEvent("ADDON_LOADED"); root:RegisterEvent("CHAT_MSG_LOOT"); root:RegisterEvent("CHAT_MSG_MONEY")
root:RegisterEvent("START_LOOT_ROLL"); root:RegisterEvent("CANCEL_LOOT_ROLL")

root:SetScript("OnUpdate", function()
    if not ready then return end
    local dt = arg1 or 0
    clock = clock + dt
    LootFeedRolls.Tick()
    if demo and clock >= demo.next then
        local sample = demo.items[demo.index]
        Enqueue(sample); demo.index = demo.index + 1; demo.next = clock + 0.7
        if demo.index > table.getn(demo.items) then demo = nil end
    end
    -- Pause the entire stack while inspecting, including pending insertions.
    if hovered then return end
    for i = table.getn(active), 1, -1 do
        local row = active[i]
        row.age = row.age + dt
        if row.roll and not row.roll.done then row.age=math.min(row.age,0.32) end
        local lifetime=row.roll and 15 or LootFeedDB.duration
        if row.age >= lifetime + 0.7 then
            row:Hide(); row.used = false; table.remove(active, i)
        end
    end
    if table.getn(queue) > 0 and clock >= nextInsert then
        local oldest, ordinary = nil, 0
        for _, row in ipairs(active) do if not row.roll then ordinary=ordinary+1; oldest=row end end
        if ordinary < LIMIT then oldest=nil end
        if oldest then
            oldest.age = math.max(oldest.age, LootFeedDB.duration)
        else
            Insert(); nextInsert = clock + 0.32
        end
    end
    for i, row in ipairs(active) do
        local target = (i-1)*(H+GAP)*COMPACT_SCALE*(LootFeedDB.direction == "up" and 1 or -1)
        row.y = row.y + (target-row.y)*math.min(1, dt*12)
        local entrance = math.min(1, row.age/0.32)
        local lifetime=row.roll and 15 or LootFeedDB.duration
        local fade = math.max(0, math.min(1, (row.age-lifetime)/0.7))
        row.holder:ClearAllPoints(); row.holder:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, row.y-GAP*COMPACT_SCALE)
        row:SetScale(COMPACT_SCALE*(1-0.12*(1-entrance)^3))
        row:SetAlpha(entrance*(1-fade))
        if not row.cached then
            row.retry = row.retry + dt
            if row.retry > 0.5 then row.retry = 0; Refresh(row) end
        end
    end
end)

SLASH_LOOTFEED1 = "/lfeed"
SLASH_LOOTFEED2 = "/lootfeed"
SlashCmdList["LOOTFEED"] = function(message)
    if not ready then return end
    local _, _, command, value = string.find(string.lower(message or ""), "^%s*(%S*)%s*(.-)%s*$")
    if command == "unlock" then Lock(false); Say("Drag the green handle, then /lfeed lock.")
    elseif command == "lock" then Lock(true)
    elseif command == "testroll" then LootFeedRolls.Demo(); Say("Group-roll preview: hover the dice to watch choices and the result.")
    elseif command == "test" then
        demo = {index=1, next=clock, items={
            {link="|cffffffff|Hitem:2589:0:0:0|h[Linen Cloth]|h|r", amount=3},
            {link="|cff1eff00|Hitem:1210:0:0:0|h[Shadowgem]|h|r", amount=1},
            {text="You loot 2 Silver, 35 Copper", texture=MoneyIcon("You loot 2 " .. (SILVER or "Silver") .. ", 35 " .. (COPPER or "Copper")), amount=1},
            {link="|cffffffff|Hitem:2447:0:0:0|h[Peacebloom]|h|r", amount=2},
            {link="|cff0070dd|Hitem:935:0:0:0|h[Night Watch Shortsword]|h|r", amount=1},
            {link="|cffffffff|Hitem:2835:0:0:0|h[Rough Stone]|h|r", amount=4},
            {link="|cffffffff|Hitem:3631:0:0:0|h[Bellygrub's Tusk]|h|r", amount=1}}}
    elseif command == "scale" and tonumber(value) then LootFeedDB.scale = math.max(0.6, math.min(1.8, tonumber(value))); Place()
    elseif command == "duration" and tonumber(value) then LootFeedDB.duration = math.max(2, math.min(20, tonumber(value)))
    elseif command == "direction" and (value == "up" or value == "down") then LootFeedDB.direction = value
    elseif command == "chat" and (value == "on" or value == "off") then LootFeedDB.mute = value == "off"; Say("Personal item loot in chat: " .. value)
    elseif command == "reset" then for k,v in pairs(defaults) do LootFeedDB[k] = v end; Place(); Lock(false)
    else Say("/lfeed unlock | lock | test | testroll | scale 1 | duration 6 | direction up/down | chat on/off | reset") end
end

