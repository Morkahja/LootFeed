-- Group roll tracking for Vanilla 1.12. No modern loot-history API required.
OctoLootRolls = { records = {}, formats = {}, pending = {} }
local R = OctoLootRolls
local notify
local function Key(link)
    local _, _, key = string.find(link or "", "|H(item:.-)|h")
    return key
end
local function Player() return UnitName("player") or "You" end
local function AddPlayer(r, name)
    if not name or name == "" then return end
    if not r.players[name] then
        r.players[name] = {name=name}
        table.insert(r.order, name)
    end
    return r.players[name]
end
local function Changed(r) if notify then notify(r) end end
local function Finish(r, status, winner)
    -- A timeout is provisional: real results can still arrive afterwards.
    if r.done and r.status ~= "Ended (result unavailable)" then return end
    r.done = true; r.status = status; r.winner = winner; r.finished = GetTime()
    Changed(r)
end
-- Capture printf arguments, including translated positional placeholders.
local function Format(fmt)
    local out, map, pos, nextArg = "^", {}, 1, 1
    while pos <= string.len(fmt) do
        local a, b, index, kind = string.find(fmt, "%%(%d+)%$([sd])", pos)
        local c, d, simple = string.find(fmt, "%%([sd])", pos)
        if c and (not a or c < a) then a,b,index,kind = c,d,nil,simple end
        if not a then
            out = out .. string.gsub(string.sub(fmt,pos), "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            break
        end
        out = out .. string.gsub(string.sub(fmt,pos,a-1), "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        out = out .. (kind == "d" and "(%-?%d+)" or "(.-)")
        table.insert(map, tonumber(index) or nextArg)
        if not index then nextArg = nextArg+1 end
        pos = b+1
    end
    return out .. "$", map
end
function R.Init(callback)
    notify = callback
    -- Vanilla suppresses choices/numeric rolls at the client when this is off.
    if GetCVar and SetCVar and GetCVar("showLootSpam") == "0" then SetCVar("showLootSpam","1") end
    local specs = {
        {"NEED", "choice", "Need", 1}, {"GREED", "choice", "Greed", 1}, {"PASSED", "choice", "Pass", 1},
        {"NEED_SELF", "choice", "Need"}, {"GREED_SELF", "choice", "Greed"}, {"PASSED_SELF", "choice", "Pass"},
        {"ROLLED_NEED", "number", "Need", 9, 1}, {"ROLLED_GREED", "number", "Greed", 9, 1},
        {"ROLLED_NEED_SELF", "number", "Need", nil, 1}, {"ROLLED_GREED_SELF", "number", "Greed", nil, 1},
        {"ROLLED", "number", nil, 1, 2}, {"ROLLED_SELF", "number", nil, nil, 1},
        {"WON", "winner", nil, 1}, {"YOU_WON", "winner"}, {"ALL_PASSED", "passed"},
        {"WON_NO_SPAM_NEED", "winner", "Need", 1, 2}, {"WON_NO_SPAM_GREED", "winner", "Greed", 1, 2},
        {"YOU_WON_NO_SPAM_NEED", "winner", "Need", nil, 1}, {"YOU_WON_NO_SPAM_GREED", "winner", "Greed", nil, 1},
    }
    for _, spec in ipairs(specs) do
        local fmt = getglobal("LOOT_ROLL_" .. spec[1])
        if fmt then
            local pattern, map = Format(fmt)
            -- Specific self/all-pass formats must precede generic %s names.
            table.insert(R.formats, 1, {pattern=pattern, map=map, action=spec[2], choice=spec[3], player=spec[4], number=spec[5]})
        end
    end
end
function R.Demo()
    local old=R.records.preview
    if old and not old.done then return end
    local r={id="preview",link="|cff0070dd|Hitem:935:0:0:0|h[Night Watch Shortsword]|h|r",
        players={},order={},amount=1,status="Preview: rolling",deadline=GetTime()+30,
        demoStart=GetTime(),demoStep=0}
    AddPlayer(r,Player()); AddPlayer(r,"ExampleMage"); AddPlayer(r,"ExampleRogue")
    R.records.preview=r; Changed(r)
end
function R.Start(id, duration)
    if R.records[id] then return end
    local link = GetLootRollItemLink(id)
    if not link then R.pending[id] = {duration=duration, untilTime=GetTime()+3}; return end
    R.pending[id] = nil
    local texture, name, count = GetLootRollItemInfo(id)
    local r = {id=id, link=link, key=Key(link), texture=texture, amount=count or 1,
        players={}, order={}, deadline=GetTime()+(tonumber(duration) or 60000)/1000+15, status="Rolling"}
    AddPlayer(r, Player())
    if GetNumRaidMembers() > 0 then
        for i=1,GetNumRaidMembers() do AddPlayer(r, UnitName("raid"..i)) end
    else
        for i=1,GetNumPartyMembers() do AddPlayer(r, UnitName("party"..i)) end
    end
    R.records[id] = r
    Changed(r)
end
function R.Message(message)
    local key = Key(message)
    if not key then return end
    for _, fmt in ipairs(R.formats) do
        local captures = {string.find(message, fmt.pattern)}
        if captures[1] then
            local values = {}
            for i, index in ipairs(fmt.map) do values[index] = captures[i+2] end
            local name = fmt.player and values[fmt.player] or Player()
            local found, count = nil, 0
            for _, r in pairs(R.records) do
                if r.key == key and not r.done then found=r; count=count+1 end
            end
            -- Recover delayed results, or numbers delivered after the winner.
            -- Never merge them into an arbitrary completed copy of the item.
            if count == 0 and fmt.action ~= "choice" then
                for _, r in pairs(R.records) do
                    if r.key == key and r.done and GetTime()-r.finished <= 120
                        and (r.status == "Ended (result unavailable)" or fmt.action == "number") then
                        found=r; count=count+1
                    end
                end
            end
            -- Vanilla chat carries an item link, not a roll ID. Never invent
            -- which identical simultaneous drop a player's message belongs to.
            if count > 1 then
                for _, r in pairs(R.records) do if r.key == key and not r.done then r.ambiguous=true; Changed(r) end end
                return
            end
            if not found then return end
            local p = AddPlayer(found, name)
            if fmt.choice then p.choice=fmt.choice end
            if fmt.number then p.number=tonumber(values[fmt.number]) end
            if fmt.action == "passed" then
                for _, n in ipairs(found.order) do found.players[n].choice="Pass" end
                Finish(found, "Everyone passed")
            elseif fmt.action == "winner" then Finish(found, "Won", name)
            else Changed(found) end
            return
        end
    end
end
function R.Event(ev, a, b)
    if ev == "START_LOOT_ROLL" then R.Start(a,b)
    elseif ev == "CHAT_MSG_LOOT" then R.Message(a)
    elseif ev == "CANCEL_LOOT_ROLL" then
        R.pending[a]=nil
        local r=R.records[a]
        -- This closes the local roll prompt; it is NOT proof the group has
        -- finished. Keep tracking until a result or the original roll deadline.
        if r and not r.done then r.promptClosed=true end
    end
end
function R.Tick()
    local now=GetTime()
    for id, p in pairs(R.pending) do
        if now >= p.untilTime then R.pending[id]=nil
        elseif GetLootRollItemLink(id) then R.Start(id,p.duration) end
    end
    for id, r in pairs(R.records) do
        if r.demoStart and not r.done then
            local step=math.floor((now-r.demoStart)/2)
            if step>r.demoStep then
                r.demoStep=step
                if step>=1 then r.players.ExampleMage.choice="Greed" end
                if step>=2 then r.players.ExampleRogue.choice="Pass" end
                if step>=3 then r.players[Player()].choice="Need" end
                if step>=4 then
                    r.players.ExampleMage.number=92; r.players[Player()].number=76
                    Finish(r,"Won",Player())
                else Changed(r) end
            end
        end
        if not r.done then
            if now >= r.deadline then Finish(r,"Ended (result unavailable)") end
        elseif now-r.finished > 300 then R.records[id]=nil end
    end
end
function R.Tooltip(r, button)
    GameTooltip:SetOwner(button,"ANCHOR_LEFT")
    GameTooltip:ClearLines()
    local _, _, name = string.find(r.link or "", "%[(.-)%]")
    GameTooltip:AddLine(name or "Group roll",1,0.82,0)
    GameTooltip:AddLine(r.winner and ("Winner: "..r.winner) or r.status,1,1,1)
    if r.demoStart then GameTooltip:AddLine("Preview only - no real roll was made.",0.7,0.7,0.7) end
    for _, n in ipairs(r.order) do
        local p=r.players[n]
        local choice=p.choice and (getglobal(string.upper(p.choice)) or p.choice) or "Waiting / eligibility unknown"
        local result=choice
        if p.number then result=result.." - "..p.number
        elseif r.done and p.choice and p.choice~="Pass" then result=result.." - no number reported" end
        GameTooltip:AddDoubleLine(n..(n==Player() and " (you)" or ""),result,1,1,1,1,0.82,0)
    end
    if r.ambiguous then GameTooltip:AddLine("Identical simultaneous drops: chat cannot identify each roll.",1,0.5,0.2,true) end
    GameTooltip:AddLine("Choose Need / Greed / Pass in the normal roll window.",0.7,0.7,0.7,true)
    GameTooltip:Show()
end
