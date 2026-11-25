if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-- Forever paper doll, equipment pane, and shared inspect-slot artwork.
-- Blizz Default keeps the native sheet with optional slot text and durability.
local ADDON_NAME, ns = ...
local EllesmereUI = _G.EllesmereUI
if not (EllesmereUI and EllesmereUI.IS_FOREVER) then return end

local FFD, GetFFD = EllesmereUI.NewFrameData()

-- The Character Sheet card's Off and the window skins kill switch, which
-- stop both looks (as they stop the retail sheet's).
local function SheetOn()
    if not EllesmereUIDB then return true end
    if EllesmereUIDB.themedCharacterSheet == false then return false end
    return not EllesmereUI.BlizzWindowSkinsKilled()
end

-- The EllesmereUI look (the card's style is latched at login, so a change
-- lands at the reload).
local function Enabled()
    return not ns.CharSheetStock() and SheetOn()
end

-- The slot text: both looks.
local function TextEnabled()
    return SheetOn()
end

local function FontPath()
    return (EllesmereUI.GetFontPath("blizzardSkin")) or STANDARD_TEXT_FONT
end

local MEDIA = "Interface\\AddOns\\EllesmereUIBlizzardSkin\\Media\\"
local ICONS = "Interface\\AddOns\\EllesmereUI\\media\\icons\\"
local SIDE_ARROW = ICONS .. "right-arrow.png"

ns.ForeverIconZoomDefault = 0.14

local function Zoom()
    return (EllesmereUIDB and EllesmereUIDB.charSheetIconZoom) or ns.ForeverIconZoomDefault
end

--------------------------------------------------------------------------------
--  Colors: the retail sidebar's category palette, keyed the way the options
--  page stores overrides (EllesmereUIDB.statCategoryColors[key]). Forever's
--  categories map onto it; General gets its own cyan, the pet pane's Combat
--  takes Attack's.
--------------------------------------------------------------------------------
local DEFAULT_COLORS = {
    General            = { r = 0.30,  g = 0.80,  b = 0.95 },
    Attributes         = { r = 0.047, g = 0.824, b = 0.616 },
    Attack             = { r = 1,     g = 0.353, b = 0.122 },
    ["Secondary Stats"] = { r = 0.471, g = 0.255, b = 0.784 },
    Defense            = { r = 0.247, g = 0.655, b = 1 },
}
local CATEGORY_KEY = {}
if STAT_CATEGORY_GENERAL then CATEGORY_KEY[STAT_CATEGORY_GENERAL] = "General" end
if STAT_CATEGORY_PRIMARY_ATTRIBUTES then CATEGORY_KEY[STAT_CATEGORY_PRIMARY_ATTRIBUTES] = "Attributes" end
if STAT_CATEGORY_WEAPONS then CATEGORY_KEY[STAT_CATEGORY_WEAPONS] = "Attack" end
if STAT_CATEGORY_MODIFIERS then CATEGORY_KEY[STAT_CATEGORY_MODIFIERS] = "Secondary Stats" end
if STAT_CATEGORY_DEFENSE then CATEGORY_KEY[STAT_CATEGORY_DEFENSE] = "Defense" end
if STAT_CATEGORY_COMBAT then CATEGORY_KEY[STAT_CATEGORY_COMBAT] = "Attack" end

local function CategoryColor(categoryName)
    local key = categoryName and CATEGORY_KEY[categoryName]
    local db = EllesmereUIDB
    -- A custom color applies only while its "use" flag is on, as on retail.
    local custom = key and db and db.statCategoryUseColor and db.statCategoryUseColor[key]
        and db.statCategoryColors and db.statCategoryColors[key]
    local c = custom or (key and DEFAULT_COLORS[key])
    if c and c.r then return c.r, c.g, c.b end
    local EG = EllesmereUI.ELLESMERE_GREEN
    if EG then return EG.r, EG.g, EG.b end
    return 1, 1, 1
end

-- The category a stat element belongs to: the data provider lists a header
-- then its rows, so it is the last header ahead of the element.
local function CategoryOf(box, elementData)
    local list = box and box.elementData
    if type(list) ~= "table" then return nil end
    local current
    for i = 1, #list do
        local d = list[i]
        if d.isHeader then current = d.name end
        if d == elementData then return current end
    end
    return current
end

--------------------------------------------------------------------------------
--  Stats list elements
--------------------------------------------------------------------------------
local function OnePixel(frame)
    local PP = EllesmereUI.PP
    local perfect = (PP and PP.perfect) or 1
    local es = frame:GetEffectiveScale()
    if not es or es <= 0 then es = 1 end
    return perfect / es
end

local function SkinHeader(frame, r, g, b)
    local d = GetFFD(frame)
    if not d.done then
        d.done = true
        if frame.Background then frame.Background:SetAlpha(0) end
        if frame.Title then
            frame.Title:SetFont(FontPath(), 11, "")
        end
        local leftBar = frame:CreateTexture(nil, "ARTWORK")
        leftBar:SetPoint("LEFT", frame, "LEFT", 8, 0)
        leftBar:SetPoint("RIGHT", frame.Title, "LEFT", -6, 0)
        d.leftBar = leftBar
        local rightBar = frame:CreateTexture(nil, "ARTWORK")
        rightBar:SetPoint("LEFT", frame.Title, "RIGHT", 6, 0)
        rightBar:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
        d.rightBar = rightBar
    end
    if frame.Title then frame.Title:SetTextColor(r, g, b, 1) end
    local px = OnePixel(frame)
    d.leftBar:SetColorTexture(r, g, b, 0.8)
    d.rightBar:SetColorTexture(r, g, b, 0.8)
    d.leftBar:SetHeight(px)
    d.rightBar:SetHeight(px)
end

local function SkinRow(frame, r, g, b)
    local d = GetFFD(frame)
    if not d.done then
        d.done = true
        if frame.Background then frame.Background:SetAlpha(0) end
        if frame.Label then frame.Label:SetFont(FontPath(), 10, "") end
        if frame.Value then frame.Value:SetFont(FontPath(), 10, "") end
        -- The retail rows carry a faint divider under each line.
        local divider = frame:CreateTexture(nil, "ARTWORK")
        divider:SetColorTexture(1, 1, 1, 0.06)
        divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 0)
        divider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 0)
        divider:SetHeight(OnePixel(frame))
        d.divider = divider
    end
    if frame.Label then frame.Label:SetTextColor(0.7, 0.7, 0.7, 0.8) end
    if frame.Value then frame.Value:SetTextColor(r, g, b, 1) end
end

local RESISTANCE_ATLAS_PREFIX = "UI-Character-Info-Resistance-"
local function SkinResistanceIcon(frame, d, atlas)
    local stock = frame.Icon
    if not stock then return end
    if not atlas or atlas:sub(1, #RESISTANCE_ATLAS_PREFIX) ~= RESISTANCE_ATLAS_PREFIX then
        if d.resistanceIcon then
            d.resistanceIcon:GetParent():Hide()
            stock:SetAlpha(1)
        end
        return
    end

    local WSkin = ns.WSkin
    local icon = d.resistanceIcon
    if not icon then
        local host = CreateFrame("Frame", nil, frame)
        host:SetSize(16, 16)
        host:SetPoint("CENTER", stock)
        icon = host:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(host)
        EllesmereUI.PP.CreateBorder(host, 0.25, 0.25, 0.25, 1, 1, "OVERLAY")
        WSkin.RegisterWindowIconBorder(host, EllesmereUI.PP.GetBorders(host))
        d.resistanceIcon = icon
    end
    if d.resistanceAtlas ~= atlas then
        icon:SetAtlas(atlas)
        WSkin.SetIconCrop(icon, 0.18)
        if not d.resistanceAtlas then WSkin.RegisterWindowIcon(icon, icon:GetParent()) end
        d.resistanceAtlas = atlas
    end
    stock:SetAlpha(0)
    icon:GetParent():Show()
end

local function SkinElement(box, frame, elementData)
    if not frame or not elementData then return end
    local hover = GetFFD(box).statsHover
    local d = GetFFD(frame)
    if hover and not d.statsHover then
        d.statsHover = true
        frame:HookScript("OnEnter", hover)
        frame:HookScript("OnLeave", hover)
    end
    if elementData.isHeader then
        SkinHeader(frame, CategoryColor(elementData.name))
    else
        SkinRow(frame, CategoryColor(CategoryOf(box, elementData)))
        SkinResistanceIcon(frame, d, elementData.atlas)
    end
end

local function HookStatsList(box)
    if not box or not box.ScrollBox or GetFFD(box).hooked then return end
    GetFFD(box).hooked = true
    if ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
        -- The event hands (owner, frame, elementData); the helper's own
        -- iterateExisting pass hands (frame, elementData) instead, so the
        -- frames already alive are walked separately below.
        ScrollUtil.AddInitializedFrameCallback(box.ScrollBox, function(_, frame, elementData)
            SkinElement(box, frame, elementData)
        end, nil, false)
        if box.ScrollBox.ForEachFrame then
            box.ScrollBox:ForEachFrame(function(frame, elementData) SkinElement(box, frame, elementData) end)
        end
    end
end

-- Options-page refresh: color overrides and their use flags land here, on
-- the frames alive in both lists. The retail sheet's refresher of the same
-- name is replaced (it walks retail-only state), so the swatches reach this.
local STAT_BOXES = { "CharacterStatsPaneScrollBox", "CharacterStatsPanePetScrollBox" }
function EllesmereUI._refreshCharacterSheetColors()
    if not Enabled() then return end
    for i = 1, #STAT_BOXES do
        local box = _G[STAT_BOXES[i]]
        if box and box.ScrollBox and box.ScrollBox.ForEachFrame then
            box.ScrollBox:ForEachFrame(function(frame, elementData) SkinElement(box, frame, elementData) end)
        end
    end
end

--------------------------------------------------------------------------------
--  The frame
--------------------------------------------------------------------------------
local SLOTS = {
    "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot",
    "CharacterChestSlot", "CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot",
    "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
    "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot",
    "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot", "CharacterAmmoSlot",
}

-- Use the paper doll's left inset on all three edges and mirror its slot anchors in Inspect.
local function LayoutGearSlots(frame, inspect)
    local character, head = _G.CharacterFrame, _G.CharacterHeadSlot
    local pane = character and character.LeftPaneHost
    if not (pane and head) then return end
    local _, _, _, inset = head:GetPoint()
    local _, _, _, _, paneTop = pane:GetPoint()
    if not inset then return end

    for _, name in ipairs(SLOTS) do
        local right = name == "CharacterHandsSlot"
        local weapon = name == "CharacterMainHandSlot"
        if inspect or right or weapon then
            local source = _G[name]
            local slot = source
            if inspect then slot = _G["Inspect" .. name:sub(10)] end
            if source and slot and not slot:IsProtected() then
                local point, relative, relativePoint, x, y = source:GetPoint()
                if inspect and relative == pane then
                    relative = frame
                    if point == "TOPLEFT" or point == "TOPRIGHT" then y = (y or 0) + (paneTop or 0) end
                elseif inspect then
                    local relativeName = relative and relative:GetName()
                    relative = relativeName and _G["Inspect" .. relativeName:sub(10)]
                end
                if point and relative then
                    if right then x = -inset end
                    if weapon then y = inset end
                    if inspect then slot:SetSize(source:GetSize()) end
                    slot:ClearAllPoints()
                    slot:SetPoint(point, relative, relativePoint, x, y)
                end
            end
        end
    end
end

function ns.ForeverLayoutInspect(frame, model)
    if not frame:IsProtected() then frame:SetSize(CHARACTER_FRAME_COLLAPSED_WIDTH, CHARACTER_FRAME_HEIGHT) end
    if not model:IsProtected() then
        local point, parent, _, _, y = model:GetPoint()
        if point == "TOPLEFT" then
            model:ClearAllPoints()
            model:SetPoint("TOP", parent, "TOP", 0, y)
        end
    end
    LayoutGearSlots(frame, true)
end

local function FadeChildren(frame, Fade)
    if not frame then return end
    local children = { frame:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child and child.GetRegions and not (child.IsForbidden and child:IsForbidden()) then
            Fade(child)
        end
    end
end

local function ItemQualityColor(quality)
    if quality and not (issecretvalue and issecretvalue(quality)) then
        local r, g, b
        if C_Item and C_Item.GetItemQualityColor then
            r, g, b = C_Item.GetItemQualityColor(quality)
        elseif GetItemQualityColor then
            r, g, b = GetItemQualityColor(quality)
        end
        if r then return r, g, b end
    end
end

-- The equipped item's quality color; nothing when the slot is empty.
local function QualityColor(slot, unit)
    return ItemQualityColor(GetInventoryItemQuality(unit or "player", slot:GetID()))
end

-- The slot border color: the equipped item's quality, dark grey when empty
-- (the retail sheet's values).
local function SlotBorderColor(slot, unit)
    local r, g, b = QualityColor(slot, unit)
    if r then return r, g, b end
    return 0.4, 0.4, 0.4
end

local function ColorSlotBorder(slot, border, unit)
    local PanelPP = EllesmereUI.PanelPP
    if not (PanelPP and PanelPP.SetBorderColor) then return end
    local r, g, b = SlotBorderColor(slot, unit)
    local d = ns.WSkin.GetFFD(border)
    local color = d.windowBorderTint
    if color then
        if r == color.r and g == color.g and b == color.b then return end
        color.r, color.g, color.b = r, g, b
        EllesmereUI.SetBorderStyleColor(d.windowCustomBorder, r, g, b, 1)
    end
    PanelPP.SetBorderColor(border, r, g, b, 1)
    EllesmereUI.RoundedBorderColor(border, r, g, b, 1)
end

--------------------------------------------------------------------------------
--  Slot text where the retail sheet shows the item level and upgrade track:
--  the item level and the item's main and secondary stat, or its armor when
--  it has no stats, and the enchant name under it. It reads the retail item
--  level and enchant keys and the retail sizes and colors, so those rows
--  drive it through the refreshers redefined below; the stats have a key of
--  this client's own (charSheetShowItemStats, off unless true).
--------------------------------------------------------------------------------
local EX_LOOK = 5  -- the EllesmereUI look's text edge, off the slot edge
local EX = EX_LOOK -- the text's near edge, off the slot edge
local WY = 10      -- the outer weapon slots' first line, above the slot's centre
local ILVL_GAP = 3 -- between the item level and the stats after it, as on retail
-- Item level position (charSheetItemLevelPos, beside the slot unless set):
-- heading the first line, else inside the slot icon at this point and y
-- offset.
local ILVL_ICON = {
    icontop = { "TOP", -2 }, iconcenter = { "CENTER", 0 }, iconbottom = { "BOTTOM", 2 },
}
local function IlvlPos()
    return EllesmereUIDB and EllesmereUIDB.charSheetItemLevelPos or "beside"
end
-- Under Blizz Default Blizzard's bronze slot frames stay: the 55px art round
-- each 37px slot reaches 9px past its edges. The text sits 4px past that,
-- and the outer weapon slots' first line drops to the slot's centre so it
-- clears the frames of the columns' bottom slots (set at the build, the
-- style being latched for the session).
local SLOT_FRAME = 9
local stockPane      -- Blizz Default: the left pane, which the side weapon lines stop at

-- Where each slot's text sits: "R" right of it, "L" left of it, "B" below
-- it, "T" above it. The inner side for the two columns; the outer side for
-- the outer weapon slots (the ranged text past the ammo slot while that
-- shows); below the middle weapon slot, whose sides are taken and whose top
-- holds the flyout arrow, or above it under Blizz Default (Blizzard's frame
-- border leaves no room under it). Shirt, tabard and ammo carry none
-- (shirt and tabard carry none on retail either).
local TEXT_SIDE = {
    CharacterHeadSlot = "R", CharacterNeckSlot = "R", CharacterShoulderSlot = "R",
    CharacterBackSlot = "R", CharacterChestSlot = "R", CharacterWristSlot = "R",
    CharacterHandsSlot = "L", CharacterWaistSlot = "L", CharacterLegsSlot = "L",
    CharacterFeetSlot = "L", CharacterFinger0Slot = "L", CharacterFinger1Slot = "L",
    CharacterTrinket0Slot = "L", CharacterTrinket1Slot = "L",
    CharacterMainHandSlot = "L", CharacterSecondaryHandSlot = "B", CharacterRangedSlot = "R",
}

-- The slots that can hold a weapon carry a dps line (painted only when the
-- item there is one).
local WEAPON_SLOT = {
    CharacterMainHandSlot = true, CharacterSecondaryHandSlot = true, CharacterRangedSlot = true,
}

-- C_Item.GetItemStats keys in tie order (an earlier key wins a tie), with our
-- own short labels. Main stat: the largest of the first three (the
-- primaries), else of the next two (Stamina, Spirit). Secondary: the largest
-- of every other listed key. Armor, shield block value, weapon damage,
-- sockets and any unlisted key never show. Built on first use, once the
-- locale catalog is active.
local STAT_LIST
local function StatList()
    if STAT_LIST then return STAT_LIST end
    local crit, hit = EllesmereUI.L("Crit"), EllesmereUI.L("Hit")
    local mp5, hp5 = EllesmereUI.L("MP5"), EllesmereUI.L("HP5")
    STAT_LIST = {
        { "ITEM_MOD_STRENGTH_SHORT",             EllesmereUI.L("Str") },
        { "ITEM_MOD_AGILITY_SHORT",              EllesmereUI.L("Agi") },
        { "ITEM_MOD_INTELLECT_SHORT",            EllesmereUI.L("Int") },
        { "ITEM_MOD_STAMINA_SHORT",              EllesmereUI.L("Stam") },
        { "ITEM_MOD_SPIRIT_SHORT",               EllesmereUI.L("Spi") },
        { "ITEM_MOD_ATTACK_POWER_SHORT",         EllesmereUI.L("AP") },
        { "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",  EllesmereUI.L("RAP") },
        { "ITEM_MOD_SPELL_POWER_SHORT",          EllesmereUI.L("SP") },
        { "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",    EllesmereUI.L("Spell Dmg") },
        { "ITEM_MOD_SPELL_HEALING_DONE_SHORT",   EllesmereUI.L("Heal") },
        { "ITEM_MOD_CRIT_RATING_SHORT",          crit },
        { "ITEM_MOD_CRIT_MELEE_RATING_SHORT",    crit },
        { "ITEM_MOD_CRIT_RANGED_RATING_SHORT",   crit },
        { "ITEM_MOD_CRIT_SPELL_RATING_SHORT",    EllesmereUI.L("Spell Crit") },
        { "ITEM_MOD_HIT_RATING_SHORT",           hit },
        { "ITEM_MOD_HIT_MELEE_RATING_SHORT",     hit },
        { "ITEM_MOD_HIT_RANGED_RATING_SHORT",    hit },
        { "ITEM_MOD_HIT_SPELL_RATING_SHORT",     EllesmereUI.L("Spell Hit") },
        { "ITEM_MOD_HASTE_RATING_SHORT",         EllesmereUI.L("Haste") },
        { "ITEM_MOD_MANA_REGENERATION_SHORT",    mp5 },
        { "ITEM_MOD_POWER_REGEN0_SHORT",         mp5 },
        { "ITEM_MOD_HEALTH_REGEN_SHORT",         hp5 },
        { "ITEM_MOD_HEALTH_REGENERATION_SHORT",  hp5 },
        { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", EllesmereUI.L("Def") },
        { "ITEM_MOD_DODGE_RATING_SHORT",         EllesmereUI.L("Dodge") },
        { "ITEM_MOD_PARRY_RATING_SHORT",         EllesmereUI.L("Parry") },
        { "ITEM_MOD_BLOCK_RATING_SHORT",         EllesmereUI.L("Block") },
        { "ITEM_MOD_SPELL_PENETRATION_SHORT",    EllesmereUI.L("Spell Pen") },
        { "RESISTANCE1_NAME",                    EllesmereUI.L("Holy Res") },
        { "RESISTANCE2_NAME",                    EllesmereUI.L("Fire Res") },
        { "RESISTANCE3_NAME",                    EllesmereUI.L("Nature Res") },
        { "RESISTANCE4_NAME",                    EllesmereUI.L("Frost Res") },
        { "RESISTANCE5_NAME",                    EllesmereUI.L("Shadow Res") },
        { "RESISTANCE6_NAME",                    EllesmereUI.L("Arcane Res") },
    }
    return STAT_LIST
end

-- "+14 Int / +9 Stam": main / secondary, one when only one exists; an item
-- with no listed stat shows its armor ("45 Armor"), else "". Memoized per
-- link (the link carries every input: item, suffix, enchant); an item whose
-- stats have not arrived is not recorded.
local statTextCache = {}
local armorLabel
local function StatText(link)
    local text = statTextCache[link]
    if text then return text end
    local stats = C_Item.GetItemStats(link)
    if not stats then return "" end
    local list = StatList()
    local main, mainV = nil, 0
    for i = 1, 3 do
        local v = stats[list[i][1]]
        if v and v > mainV then main, mainV = i, v end
    end
    if not main then
        for i = 4, 5 do
            local v = stats[list[i][1]]
            if v and v > mainV then main, mainV = i, v end
        end
    end
    local second, secondV = nil, 0
    for i = 1, #list do
        local v = i ~= main and stats[list[i][1]]
        if v and v > secondV then second, secondV = i, v end
    end
    if main and second then
        text = string.format("+%d %s / +%d %s", mainV, list[main][2], secondV, list[second][2])
    elseif main or second then
        text = string.format("+%d %s", main and mainV or secondV, list[main or second][2])
    else
        local armor = stats.RESISTANCE0_NAME
        if armor and armor > 0 then
            armorLabel = armorLabel or EllesmereUI.L("Armor")
            text = string.format("%d %s", armor, armorLabel)
        else
            text = ""
        end
    end
    statTextCache[link] = text
    return text
end

-- "6.3 Dps" for a weapon (item class Weapon, so never a shield or a held-in
-- off-hand item), "" for anything else. Memoized per link like the stats.
local dpsTextCache = {}
local dpsLabel
local function DpsText(link)
    local text = dpsTextCache[link]
    if text then return text end
    text = ""
    if select(6, C_Item.GetItemInfoInstant(link)) == Enum.ItemClass.Weapon then
        local stats = C_Item.GetItemStats(link)
        if not stats then return "" end
        local dps = stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
        if dps and dps > 0 then
            dpsLabel = dpsLabel or EllesmereUI.L("Dps")
            text = string.format("%.1f %s", dps, dpsLabel)
        end
    end
    dpsTextCache[link] = text
    return text
end

-- The inspect sheet shows the same lines for the inspected player's items,
-- and places its item levels by a position of its own: inside the slot icon
-- at a point and y offset, or (nothing returned) beside the slot.
ns.ForeverStatText = StatText
ns.ForeverDpsText = DpsText
function ns.ForeverIlvlIcon(pos)
    local icon = ILVL_ICON[pos]
    if icon then return icon[1], icon[2] end
end

local function DB(key)
    local db = EllesmereUIDB
    return db and db[key]
end

-- The enchant name through the retail sheet's reader, which takes the
-- engine-tagged permanent enchant tooltip line. A vanilla line is the effect
-- itself ("+7 Agility"): the plus the reader trims goes back on, and an
-- "Enchanted: " prefix, where the client adds one, comes off. The inspect
-- sheet names its enchants through the same function.
local ENCHANT_PREFIX = ENCHANTED_TOOLTIP_LINE and ENCHANTED_TOOLTIP_LINE:match("^(.-)%%s")
function ns.ForeverEnchantName(text)
    if text == "" then return text end
    if ENCHANT_PREFIX and ENCHANT_PREFIX ~= "" and text:sub(1, #ENCHANT_PREFIX) == ENCHANT_PREFIX then
        text = text:sub(#ENCHANT_PREFIX + 1)
    end
    if text:find("^%d") then text = "+" .. text end
    return text
end
local function EnchantName(slotID)
    return ns.ForeverEnchantName(EllesmereUI.GetEnchantText(slotID))
end

local textVer = 1               -- bumped by every options refresh
local pending, pendingN = {}, 0 -- SLOTS index -> itemID waiting on item data
local itemWatch                 -- GET_ITEM_INFO_RECEIVED, registered only while a slot waits

-- The stats font (and the weapon slots' dps line): the retail upgrade
-- track's size, outline and shadow keys. The enchant's font follows its
-- name mode at paint.
local function ApplyLabelFonts(d)
    local path = FontPath()
    local size = DB("charSheetUpgradeTrackSize") or 11
    local flags = DB("charSheetUpgradeTrackOutline") and EllesmereUI.SlugFlag("OUTLINE, SLUG") or ""
    EllesmereUI.PrimeFontShadow(d.stats, DB("charSheetUpgradeTrackShadow"))
    d.stats:SetFont(path, size, flags)
    -- Item level: retail's item level size, outline and shadow keys.
    local isize = DB("charSheetItemLevelSize") or 11
    local inIcon = ILVL_ICON[IlvlPos()]
    local iflags = (inIcon or DB("charSheetItemLevelOutline")) and EllesmereUI.SlugFlag("OUTLINE, SLUG") or ""
    EllesmereUI.PrimeFontShadow(d.ilvl, DB("charSheetItemLevelShadow"))
    d.ilvl:SetFont(path, isize, iflags)
    if d.dps then
        EllesmereUI.PrimeFontShadow(d.dps, DB("charSheetUpgradeTrackShadow"))
        d.dps:SetFont(path, size, flags)
    end
    d.fontVer = textVer
end

-- Blizz Default: a weapon slot's lines capped at the room they have
-- (the stats and dps take its width, justified to their anchored side; the
-- enchant shrinks to it when wider), cut short rather than run past it.
-- Room the item level takes at the head of the first line.
local function IlvlRoom(d)
    return d.hasIlvl and d.ilvl:GetStringWidth() + ILVL_GAP or 0
end

local function CapLines(d, room, justify)
    if not room or room <= 0 then return end
    d.stats:SetWidth(math.max(1, room - IlvlRoom(d))); d.stats:SetJustifyH(justify)
    d.dps:SetWidth(room); d.dps:SetJustifyH(justify)
    if d.ench:GetWidth() > room then d.ench:SetWidth(room) end
end

-- The side weapon lines stop 6px inside the left pane (its frame border on
-- the left, the stats pane's edge on the right: past the ammo slot the
-- ranged text has about 90px).
local PANE_PAD = 6
local function CapToPane(d, anchor, point)
    local room
    if point == "LEFT" then
        local a, e = anchor:GetRight(), stockPane:GetRight()
        room = a and e and e - PANE_PAD - a - EX
    else
        local a, e = anchor:GetLeft(), stockPane:GetLeft()
        room = a and e and a - EX - e - PANE_PAD
    end
    CapLines(d, room, point)
end

-- Weapon slots stack their lines from the top: the stats, the dps, then the
-- enchant, a line moving up when the one above it is empty. Beside a slot
-- the first line sits where retail's item level does (at the slot's centre
-- under Blizz Default) and the enchant keeps its retail spot unless the dps
-- line pushes it down; below the middle weapon slot the lines stack centred
-- under it, stats and dps sharing a row; above it (Blizz Default) they stack
-- upward, ending at its right edge. Re-run after each paint (the lines'
-- contents and heights decide the stack).
-- The first line beside a slot: the item level on the slot side (when
-- shown), the stats running on past it.
local function FirstLine(d, anchor, point, rel, x, y)
    if d.hasIlvl then
        d.ilvl:SetPoint(point, anchor, rel, x, y)
        d.stats:SetPoint(point, d.ilvl, rel, x < 0 and -ILVL_GAP or ILVL_GAP, 0)
    else
        d.stats:SetPoint(point, anchor, rel, x, y)
    end
end

local LINE = 13
local rowLines, rowGaps = {}, {}  -- the middle weapon slot's shared row, built again on each run
local function StackWeaponText(d, anchor)
    local stats, dps, ench, ilvl = d.stats, d.dps, d.ench, d.ilvl
    stats:ClearAllPoints(); dps:ClearAllPoints(); ench:ClearAllPoints()
    if d.hasIlvl then ilvl:ClearAllPoints() end
    local hasFirst = d.hasIlvl or d.hasStats
    if d.side == "B" then
        -- About 30px sit between the weapon row and the frame's bottom edge:
        -- three lines do not fit, so under the middle slot the stats and the
        -- dps share one row, centred as a pair.
        -- The item level heads the row.
        local top = -3
        local row, gaps = rowLines, rowGaps
        wipe(row); wipe(gaps)
        if d.hasIlvl then row[#row + 1] = ilvl end
        if d.hasStats then row[#row + 1] = stats; gaps[#row] = ILVL_GAP end
        if d.hasDps then row[#row + 1] = dps; gaps[#row] = 6 end
        if #row > 0 then
            local w, rh = 0, 0
            for i = 1, #row do
                w = w + row[i]:GetStringWidth() + (i > 1 and gaps[i] or 0)
                rh = math.max(rh, row[i]:GetStringHeight())
            end
            row[1]:SetPoint("TOPLEFT", anchor, "BOTTOM", -w / 2, top)
            for i = 2, #row do row[i]:SetPoint("LEFT", row[i - 1], "RIGHT", gaps[i], 0) end
            top = top - rh - 1
        end
        ench:SetPoint("TOP", anchor, "BOTTOM", 0, top)
        ench:SetJustifyH("CENTER")
        return
    end
    if d.side == "T" then
        -- The enchant nearest the slot, then the dps, then the stats. The
        -- columns' bottom slots keep their inner lines within their own
        -- height, level with these, so the stack starts at those slots' top,
        -- else just past the bronze frame. Each line ends at the slot's right
        -- edge and runs left into the band beside the shirt and tabard (which
        -- carry no text), capped at the left column's text edge: a centred
        -- stack or a shared stats and dps row would run into the right
        -- column's text.
        local y = SLOT_FRAME + 2
        local col, top = _G.CharacterWristSlot, anchor:GetTop()
        local colTop = col and col:GetTop()
        if top and colTop and colTop - top + 2 > y then y = colTop - top + 2 end
        local right, colRight = anchor:GetRight(), col and col:GetRight()
        CapLines(d, right and colRight and right - colRight - EX, "RIGHT")
        ench:SetJustifyH("RIGHT")
        if d.hasEnch then
            ench:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, y)
            y = y + ench:GetStringHeight() + 1
        end
        if d.hasDps then
            dps:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, y)
            y = y + dps:GetStringHeight() + 1
        end
        if hasFirst then
            if d.hasIlvl then
                ilvl:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, y)
                stats:SetPoint("BOTTOMRIGHT", ilvl, "BOTTOMLEFT", -ILVL_GAP, 0)
            else
                stats:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, y)
            end
        end
        return
    end
    local point, rel, x = "LEFT", "RIGHT", EX
    if d.side == "L" then point, rel, x = "RIGHT", "LEFT", -EX end
    if stockPane then CapToPane(d, anchor, point) end
    local y = WY
    if hasFirst then
        FirstLine(d, anchor, point, rel, x, y)
        y = y - LINE
    end
    if d.hasDps then
        dps:SetPoint(point, anchor, rel, x, y)
        y = y - LINE
    end
    ench:SetPoint(point, anchor, rel, x, math.min(y, -3) - 2)
    ench:SetJustifyH(point)
end

-- The stats off the slot's edge where retail's item level sits, the
-- enchant under them hugging the slot.
local function PlaceText(d, anchor)
    if d.dps then return StackWeaponText(d, anchor) end
    local stats, ench = d.stats, d.ench
    stats:ClearAllPoints(); ench:ClearAllPoints()
    if d.hasIlvl then d.ilvl:ClearAllPoints() end
    if d.side == "R" then
        FirstLine(d, anchor, "LEFT", "RIGHT", EX, 10)
        ench:SetPoint("LEFT", anchor, "RIGHT", EX, -5)
        ench:SetJustifyH("LEFT")
    else
        FirstLine(d, anchor, "RIGHT", "LEFT", -EX, 10)
        ench:SetPoint("RIGHT", anchor, "LEFT", -EX, -5)
        ench:SetJustifyH("RIGHT")
    end
end

-- One slot's text. Runs from Blizzard's per-slot update (only while the
-- slots are shown), from the options refreshers and from item data landing.
local function PaintSlotText(slot)
    local d = FFD[slot]
    local stats = d and d.stats
    if not stats then return end
    -- The ranged text sits past the ammo slot while that shows (checked
    -- ahead of the memo: the ammo slot comes and goes with the class).
    local ammo = d.ammo
    if ammo then
        local anchor = ammo:IsShown() and ammo or slot
        if d.anchor ~= anchor then
            d.anchor = anchor
            PlaceText(d, anchor)
        end
    end
    -- Memo: the equipped link and the settings version are every input.
    local slotID = slot:GetID()
    local link = GetInventoryItemLink("player", slotID)
    if d.paintLink == link and d.paintVer == textVer then return end
    d.paintLink, d.paintVer = link, textVer
    local idx = d.idx
    if pending[idx] then
        pending[idx] = nil
        pendingN = pendingN - 1
        if pendingN == 0 then itemWatch:UnregisterEvent("GET_ITEM_INFO_RECEIVED") end
    end
    if d.fontVer ~= textVer then ApplyLabelFonts(d) end
    local ench = d.ench
    local itemID = link and GetInventoryItemID("player", slotID)
    if not (itemID and C_Item.IsItemDataCachedByID(itemID)) then
        stats:SetText(""); ench:SetText(""); d.ilvl:SetText("")
        if d.dps then d.dps:SetText("") end
        if itemID then
            -- Not cached yet: one repaint when it lands, watched only while
            -- the slot shows (and ahead of the request, whose answer can
            -- come at once); a hidden one repaints on its next show.
            if slot:IsVisible() then
                pending[idx] = itemID
                pendingN = pendingN + 1
                itemWatch:RegisterEvent("GET_ITEM_INFO_RECEIVED")
            else
                d.paintLink = nil
            end
            C_Item.RequestLoadItemDataByID(itemID)
        end
        return
    end

    -- The item's color as retail colors its item level: the custom color,
    -- else the item's quality (unless turned off), else white.
    local r, g, b = 1, 1, 1
    local custom = DB("charSheetItemLevelUseColor") and DB("charSheetItemLevelColor")
    if custom then
        r, g, b = custom.r, custom.g, custom.b
    elseif DB("charSheetColorItemLevel") ~= false then
        local qr, qg, qb = QualityColor(slot)
        if qr then r, g, b = qr, qg, qb end
    end

    -- Show Item Stats (off unless turned on): the item's stats (or its
    -- armor), in the upgrade track's color override, else the item's
    -- color. A weapon's damage per second rides the same key and color.
    local showStats = DB("charSheetShowItemStats") == true
    local statText = showStats and StatText(link) or ""
    stats:SetText(statText)
    -- Item level (retail's key, on unless false) in the item's color, as
    -- on retail.
    local level = DB("showItemLevel") ~= false and C_Item.GetDetailedItemLevelInfo(link)
    local shown = level and level > 0 or false
    d.ilvl:SetText(shown and level or "")
    d.ilvl:SetTextColor(r, g, b, 0.9)
    -- Inside the icon: pinned to the slot, out of the text lines.
    local icon = ILVL_ICON[IlvlPos()]
    if icon then
        d.ilvl:ClearAllPoints()
        d.ilvl:SetPoint(icon[1], slot, icon[1], 0, icon[2])
    end
    local hasIlvl = shown and not icon
    if d.hasIlvl ~= hasIlvl then
        d.hasIlvl = hasIlvl
        if not d.dps then PlaceText(d, d.anchor) end
    end
    local sc = DB("charSheetUpgradeTrackUseColor") and DB("charSheetUpgradeTrackColor")
    local sr, sg, sb = r, g, b
    if sc then sr, sg, sb = sc.r, sc.g, sc.b end
    stats:SetTextColor(sr, sg, sb, 0.8)
    local dps = d.dps
    if dps then
        local dpsText = showStats and DpsText(link) or ""
        dps:SetText(dpsText)
        dps:SetTextColor(sr, sg, sb, 0.8)
        d.hasStats, d.hasDps = statText ~= "", dpsText ~= ""
    end

    -- Vanilla enchants carry no icon, so the name always shows; Enchants set
    -- to Colored Text gives it retail's name look (outlined, tinted from the
    -- item's color). Capped at 45% of the gap between the columns, as on
    -- retail, less Blizz Default's extra inset on each side (so the two
    -- columns' enchants keep a gap in the middle).
    local name = DB("showEnchants") ~= false and EnchantName(slotID) or ""
    ench:SetText(name)
    if name ~= "" then
        local size = DB("charSheetEnchantSize") or 9
        if DB("charSheetEnchantNames") then
            ench:SetFont(FontPath(), size, EllesmereUI.SlugFlag("OUTLINE, SLUG"))
            ench:SetTextColor(r + (1 - r) * 0.5, g + (1 - g) * 0.5, b + (1 - b) * 0.5, 0.9)
        else
            ench:SetFont(FontPath(), size, "")
            ench:SetTextColor(1, 1, 1, 0.8)
        end
        local head, hands = _G.CharacterHeadSlot, _G.CharacterHandsSlot
        local lr, rl = head and head:GetRight(), hands and hands:GetLeft()
        ench:SetWidth((lr and rl and rl > lr) and (rl - lr - 2 * (EX - EX_LOOK)) * 0.45 or 0)
    end
    if dps then
        d.hasEnch = name ~= ""
        StackWeaponText(d, d.anchor)
    end
end

-- The slots went away (tab, pet view, close): nothing waits any more; a
-- slot that was waiting repaints on its next show.
local function ClearPending()
    if pendingN == 0 then return end
    for i = 1, #SLOTS do
        if pending[i] then
            pending[i] = nil
            local d = FFD[_G[SLOTS[i]]]
            if d then d.paintLink = nil end
        end
    end
    pendingN = 0
    itemWatch:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
end

-- Item data landed: one repaint per waiting slot. A failed load is not
-- asked for again (no retry loop); that slot stays blank until its item or
-- a setting changes.
local function OnItemInfo(_, _, itemID, success)
    for i = 1, #SLOTS do
        if pending[i] == itemID then
            pending[i] = nil
            pendingN = pendingN - 1
            if success then
                local slot = _G[SLOTS[i]]
                local d = FFD[slot]
                if d then d.paintLink = nil end
                PaintSlotText(slot)
            end
        end
    end
    if pendingN == 0 then itemWatch:UnregisterEvent("GET_ITEM_INFO_RECEIVED") end
end

local slotOverlay   -- every slot's text; the eyeball fades it
local ilvlOverlay   -- the item levels (above the slots); faded with it

local function BuildSlotText()
    local host = _G.PaperDollItemsFrame
    if not host or itemWatch then return end
    -- Blizz Default: the text goes past Blizzard's bronze slot frames.
    local fv = ns.CharSheetForever()
    if fv then
        EX, WY = SLOT_FRAME + 4, 0
        stockPane = _G.CharacterFrame and _G.CharacterFrame.LeftPaneHost
    end
    itemWatch = CreateFrame("Frame")
    itemWatch:SetScript("OnEvent", OnItemInfo)
    -- A child of the slots' own frame, so it goes with them (other tabs, the
    -- pet view); above the model scene, below the slot buttons.
    local overlay = CreateFrame("Frame", nil, host)
    slotOverlay = overlay
    overlay:SetAllPoints(host)
    local scene = _G.CharacterModelScene
    overlay:SetFrameLevel((scene and scene:GetFrameLevel() or 50) + 10)
    -- The item level's layer: above the slot buttons, so it can sit inside
    -- an icon. Mouse stays off.
    local ilvlLayer = CreateFrame("Frame", nil, host)
    ilvlLayer:SetAllPoints(host)
    ilvlLayer:SetFrameLevel(host:GetFrameLevel() + 20)
    ilvlOverlay = ilvlLayer
    local ranged = _G.CharacterRangedSlot
    local rangedShown = ranged and ranged:IsShown()
    local path = FontPath()
    for i = 1, #SLOTS do
        local name = SLOTS[i]
        local side, slot = TEXT_SIDE[name], _G[name]
        if side and slot then
            -- Without a ranged slot the off hand is the outer one on the
            -- right; under Blizz Default the middle one's text goes above
            -- it.
            if side == "B" then
                if not rangedShown then side = "R"
                elseif fv then side = "T" end
            end
            local d = GetFFD(slot)
            d.idx, d.side, d.anchor = i, side, slot
            -- One line each: a capped width (Blizz Default) cuts the
            -- text short rather than wrapping it into the frames around.
            d.ilvl = ilvlLayer:CreateFontString(nil, "OVERLAY")
            d.ilvl:SetWordWrap(false)
            d.stats = overlay:CreateFontString(nil, "OVERLAY")
            d.stats:SetWordWrap(false)
            if WEAPON_SLOT[name] then
                d.dps = overlay:CreateFontString(nil, "OVERLAY")
                d.dps:SetWordWrap(false)
            end
            d.ench = overlay:CreateFontString(nil, "OVERLAY")
            d.ench:SetFont(path, DB("charSheetEnchantSize") or 9, "")
            d.ench:SetWordWrap(false)
            ApplyLabelFonts(d)
            if slot == ranged then d.ammo = _G.CharacterAmmoSlot end
            PlaceText(d, slot)
        end
    end
    host:HookScript("OnHide", ClearPending)
    -- A first open that skinned the sheet (or, under Blizz Default, the
    -- slots' first show) has already had Blizzard's update.
    for i = 1, #SLOTS do
        local slot = _G[SLOTS[i]]
        if slot and slot:IsVisible() then PaintSlotText(slot) end
    end
end

-- Options refreshers: the retail slot text setters (Show Item Level, Show
-- Item Stats, Enchants and its cog, the Fonts page's Enchant Text Size)
-- land here; the retail versions walk retail-only state.
-- The version bump feeds every setting into the paint memo, so a hidden
-- sheet repaints on its next show.
local function RefreshSlotText()
    textVer = textVer + 1
    if not TextEnabled() then return end
    for i = 1, #SLOTS do
        local slot = _G[SLOTS[i]]
        if slot and slot:IsVisible() then PaintSlotText(slot) end
    end
end
EllesmereUI._refreshItemLevelVisibility = RefreshSlotText
EllesmereUI._refreshUpgradeTrackVisibility = RefreshSlotText
EllesmereUI._refreshEnchantsVisibility = RefreshSlotText
EllesmereUI._refreshCharSheetSlotLabels = RefreshSlotText
EllesmereUI._applyCharSheetTextSizes = RefreshSlotText

local function VisitSlotChrome(slot, visit)
    visit(slot:GetNormalTexture())
    visit(slot:GetPushedTexture())
    visit(slot:GetHighlightTexture())
    visit(slot.IconBorder)
end

local function HideSlotTexture(texture)
    if texture then texture:SetAlpha(0) end
end

local function SuppressSlotChrome(slot)
    VisitSlotChrome(slot, HideSlotTexture)
end

local ACTION_BAR_MEDIA = "Interface\\AddOns\\EllesmereUIActionBars\\Media\\"
local GLOW_GOLD = { r = 1, g = 0.75, b = 0.24 }
local function BuildSlotHover(slot, bounds)
    local glow = slot:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints(bounds or slot)
    glow:SetTexture(ACTION_BAR_MEDIA .. "highlight-2.png")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0.35, 0.65, 1)

    local flash = slot:CreateTexture(nil, "OVERLAY")
    flash:SetAllPoints(glow)
    flash:SetTexture(ACTION_BAR_MEDIA .. "highlight-3.png")
    flash:SetBlendMode("ADD")
    flash:SetVertexColor(1, 1, 1)
    flash:Hide()
    local animation = flash:CreateAnimationGroup()
    local fade = animation:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(0.18)
    animation:SetScript("OnFinished", function() flash:Hide() end)
    slot:HookScript("OnMouseDown", function()
        if not glow:IsShown() then return end
        animation:Stop()
        flash:Show()
        animation:Play()
    end)
    slot:HookScript("OnHide", function()
        animation:Stop()
        flash:Hide()
    end)
    return glow, flash
end

-- Blizzard refreshes every shown slot through this on equipment changes and
-- on show; the border and the slot text follow. Foreign item buttons (bags)
-- have no entry.
local function OnSlotUpdate(slot)
    local d = FFD[slot]
    if not d then return end
    local unit = d.inspect and _G.InspectFrame.unit
    if d.inspect and not unit then return end
    local icon = d.cropIcon
    if d.skinnedSlotChrome then SuppressSlotChrome(slot) end
    -- SetItemButtonTexture can restore the full texture during a slot refresh.
    if icon then
        if math.abs(icon:GetTexCoord() - d.crop) > 0.0001 then ns.WSkin.SetIconCrop(icon, d.crop) end
        local db = EllesmereUIDB
        local style = db and db.blizzWinBorderTexture
        if style and EllesmereUI.RoundedStyleOK(style) and (db.blizzWinIconCornerRadius or 0) > 0 and icon:GetNumMaskTextures() == 0 then
            ns.WSkin.RegisterWindowIcon(icon)
        end
    end
    if d.border then ColorSlotBorder(slot, d.border, unit) end
    if d.stats then PaintSlotText(slot) end
end
ns.ForeverRefreshInspectSlot = OnSlotUpdate

local slotHooked = false
local function HookSlotUpdates()
    if slotHooked or type(_G.PaperDollItemSlotButton_Update) ~= "function" then return end
    slotHooked = true
    hooksecurefunc("PaperDollItemSlotButton_Update", OnSlotUpdate)
    if Enabled() then
        hooksecurefunc("SetItemButtonQuality", function(slot)
            local d = FFD[slot]
            if d and d.skinnedSlotChrome then HideSlotTexture(slot.IconBorder) end
        end)
    end
end

-- One slot's dress, the same on this sheet and on the inspect sheet
-- (ns.ForeverSkinSlot): the bronze frame and the button art off, the quality
-- ring suppressed, the icon cropped, a grey square behind it and a border
-- that the sheet colors by its item. Once per slot.
local function DressSlot(slot, slotName, Fade, inspectUnit)
    local d = GetFFD(slot)
    if d.done then return end
    d.done = true
    d.inspect = inspectUnit ~= nil
    -- The bronze slot frame lives on a child frame; the button art is the
    -- named NormalTexture (hidden, not faded: the client rewrites its vertex
    -- color, and with it the alpha, on every item update).
    if slot.BorderFrame then
        Fade(slot.BorderFrame)
    else
        -- The ammo slot is built without that child: its ring is an atlas
        -- texture on the button itself. The arrow pointing at the ranged slot
        -- (an unnamed child frame of its own) stays.
        local regions = { slot:GetRegions() }
        for i = 1, #regions do
            local r = regions[i]
            if r.GetAtlas and r:GetAtlas() == "UI-Character-Info-GearSlotSmall" then r:SetAlpha(0) end
        end
    end
    local normal = _G[slotName .. "NormalTexture"] or (slot.GetNormalTexture and slot:GetNormalTexture())
    if normal then normal:Hide() end
    d.skinnedSlotChrome = true
    SuppressSlotChrome(slot)
    slot:HookScript("OnClick", SuppressSlotChrome)
    -- The item icon is the button's own; the ammo slot also declares a
    -- legacy texture under the same global name, which is not it.
    local icon = slot.icon or _G[slotName .. "IconTexture"]
    if icon then
        ns.WSkin.RemoveStockItemMask(slot, icon)
        local z = Zoom()
        ns.WSkin.SetIconCrop(icon, z)
        d.cropIcon, d.crop = icon, z
    end
    local bg = slot:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetAllPoints(slot)
    bg:SetColorTexture(0.5, 0.5, 0.5, 0.7)
    local hover, flash = BuildSlotHover(slot, icon)
    if not inspectUnit then
        local glow = slot:CreateTexture(nil, "OVERLAY")
        glow:SetAllPoints(hover)
        glow:SetTexture(ACTION_BAR_MEDIA .. "highlight-3.png")
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(hover:GetVertexColor())
        glow:Hide()
        d.altFlyoutGlow = glow
    end
    local PanelPP = EllesmereUI.PanelPP
    if PanelPP and PanelPP.CreateBorder then
        local host = CreateFrame("Frame", nil, slot)
        host:SetAllPoints(slot)
        host:SetFrameLevel(slot:GetFrameLevel())
        PanelPP.CreateBorder(host, 0.4, 0.4, 0.4, 1, 1, "OVERLAY", 1)
        local borders = PanelPP.GetBorders(host)
        if borders then borders:SetFrameLevel(slot:GetFrameLevel()) end
        d.border = host
        local WSkin = ns.WSkin
        local r, g, b = SlotBorderColor(slot, inspectUnit)
        PanelPP.SetBorderColor(host, r, g, b, 1)
        WSkin.RegisterWindowIconBorder(host, borders, { r = r, g = g, b = b })
        WSkin.RegisterWindowIcon(icon, host, bg, hover, nil, nil, { flash, d.altFlyoutGlow })
    end
end

local function SkinSlot(slotName, Fade)
    local slot = _G[slotName]
    if not slot then return end
    DressSlot(slot, slotName, Fade)
end

local inspectSlotHooked
function ns.ForeverSkinSlot(slot, slotName, unit)
    DressSlot(slot, slotName, ns.WSkin.FadeRegions, unit)
    if not inspectSlotHooked then
        inspectSlotHooked = true
        hooksecurefunc("InspectPaperDollItemSlotButton_Update", OnSlotUpdate)
    end
end

-- Options-page refresh: the Icon Zoom slider lands here (the retail sheet's
-- own refresher is replaced, it walks the retail slot list).
function EllesmereUI._refreshCharSheetIconZoom()
    local z = Zoom()
    for _, d in pairs(FFD) do
        if d.cropIcon then
            d.crop = z
            ns.WSkin.SetIconCrop(d.cropIcon, z)
        end
    end
end

--------------------------------------------------------------------------------
--  The model backdrop and the sidebar panel, as on retail
--------------------------------------------------------------------------------
local IMG_ASPECT = 787 / 1030   -- character-bg.png

-- Both panels draw above the shell's top bar (children of the frame render
-- over its own textures), so their top edge is pinned to the bar's bottom:
-- flush under it, never over it, no gap of bare backdrop between.
local function PinTop(region, topBar, fallback)
    if topBar then
        region:SetPoint("TOP", topBar, "BOTTOM", 0, 0)
    else
        region:SetPoint("TOP", fallback, "TOP", 0, 0)
    end
end

-- The model scene's own art: the four race background pieces and the black
-- shade over them. The paper doll sets the shade's alpha (per race) and the
-- pieces' textures every time it shows, so a fade alone does not last and the
-- shade would cover our backdrop. Nothing of Blizzard's shows them again, so
-- they are hidden, as on the retail and inspect sheets.
local SCENE_ART = { "BackgroundOverlay", "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight" }
function ns.ForeverHideSceneArt(scene)
    if not scene then return end
    for i = 1, #SCENE_ART do
        local art = scene[SCENE_ART[i]]
        if art then art:Hide() end
    end
end

local function SkinPaneToggle(frame, WSkin)
    local button, pane = frame.RightPaneToggleButton, frame.LeftPaneHost
    if not (button and pane and frame.IsRightPaneCollapsed and frame.UpdateRightPaneToggleButton)
        or button:IsProtected() then return end
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -7 - 3 * OnePixel(button), 7)
    button:SetSize(20, 20)
    WSkin.FadeRegions(button)

    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("CENTER")
    arrow:SetTexture(SIDE_ARROW)
    arrow:SetVertexColor(1, 1, 1, 0.75)
    local function UpdateArrow()
        button:GetNormalTexture():SetAlpha(0)
        button:GetPushedTexture():SetAlpha(0)
        if frame:IsRightPaneCollapsed() then
            arrow:SetTexCoord(0, 1, 0, 1)
        else
            arrow:SetTexCoord(1, 0, 0, 1)
        end
    end
    hooksecurefunc(frame, "UpdateRightPaneToggleButton", UpdateArrow)
    button:HookScript("OnEnter", function() arrow:SetVertexColor(1, 1, 1, 1) end)
    button:HookScript("OnLeave", function() arrow:SetVertexColor(1, 1, 1, 0.75) end)
    UpdateArrow()
end

local CONTROL_WIDTH, CONTROL_ALPHA = 18, 0.4
local TITLE_INSET = 22

local function SkinControlFeedback(button, art)
    local function Release()
        art:SetPoint("CENTER", button, "CENTER", 0, 0)
    end
    local function Dim()
        art:SetAlpha(CONTROL_ALPHA)
    end
    Dim()
    button:HookScript("OnEnter", function() art:SetAlpha(0.85) end)
    button:HookScript("OnLeave", Dim)
    button:HookScript("OnMouseDown", function()
        art:SetPoint("CENTER", button, "CENTER", 0, -1)
    end)
    button:HookScript("OnMouseUp", Release)
    button:HookScript("OnHide", function()
        Release()
        Dim()
    end)
end

function ns.ForeverSkinHeaderHover(frame, topBar, controls, close)
    local header = CreateFrame("Frame", nil, frame)
    header:SetAllPoints(topBar)
    header:SetMouseMotionEnabled(true)
    header:SetMouseClickEnabled(false)
    header:SetPropagateMouseClicks(true)
    header:SetPropagateMouseMotion(true)
    local revealed
    local function SetRevealed(show)
        if revealed == show then return end
        revealed = show
        for _, button in ipairs(controls) do button:SetAlpha(show and 1 or 0.25) end
    end
    local function Reveal() SetRevealed(true) end
    local function Refresh() SetRevealed(header:IsVisible() and header:IsMouseOver() or false) end
    header:SetScript("OnEnter", Reveal)
    header:SetScript("OnLeave", Refresh)
    header:SetScript("OnShow", Refresh)
    header:SetScript("OnHide", function() SetRevealed(false) end)
    for _, button in ipairs(controls) do
        button:HookScript("OnEnter", Reveal)
        button:HookScript("OnLeave", Refresh)
    end
    if close then
        close:HookScript("OnEnter", Reveal)
        close:HookScript("OnLeave", Refresh)
    end
    Refresh()
end

function ns.ForeverSkinClose(close, topBar)
    if not (topBar and close) or close:IsProtected() then return end
    close:ClearAllPoints()
    close:SetPoint("CENTER", topBar, "RIGHT", -TITLE_INSET, 0)
    local glyph = ns.WSkin.GetFFD(close).x
    if glyph then
        glyph:ClearAllPoints()
        glyph:SetPoint("CENTER", close)
    end
end

function ns.ForeverBuildItemTextEye(items, topBar, overlay, ilvlOverlay, field)
    local character = field and EllesmereUI.CharEntry()
    local hidden = character and character[field] == true
    local button = CreateFrame("Button", nil, items)
    button:SetSize(CONTROL_WIDTH, 20)
    button:SetPoint("CENTER", topBar, "LEFT", TITLE_INSET, 0)
    button:SetFrameLevel(items:GetFrameLevel() + 5)
    local art = button:CreateTexture(nil, "OVERLAY")
    art:SetSize(CONTROL_WIDTH, CONTROL_WIDTH)
    art:SetPoint("CENTER")
    local function Apply()
        art:SetTexture(hidden and EllesmereUI.EYE_INVISIBLE_ICON or EllesmereUI.EYE_VISIBLE_ICON)
        overlay:SetAlpha(hidden and 0 or 1)
        ilvlOverlay:SetAlpha(hidden and 0 or 1)
    end
    local tooltipOpts = { anchor = "right" }
    local function ShowTooltip(self)
        EllesmereUI.ShowWidgetTooltip(self, hidden and "Show Item Text" or "Hide Item Text", tooltipOpts)
    end
    local function HideTooltip(self)
        if EllesmereUI._WidgetTooltipOwner() == self then EllesmereUI.HideWidgetTooltip() end
    end
    button:SetScript("OnClick", function(self)
        hidden = not hidden
        local entry = field and EllesmereUI.CharEntry(true)
        if entry then entry[field] = hidden end
        Apply()
        if EllesmereUI._WidgetTooltipOwner() == self then ShowTooltip(self) end
    end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", HideTooltip)
    button:SetScript("OnHide", HideTooltip)
    SkinControlFeedback(button, art)
    Apply()
    return button
end

local function SkinModelControls(scene, eye, WSkin)
    local control = scene.ControlFrame
    if not (control and eye) or control:IsProtected() then return end
    local buttons = { control.zoomInButton, control.zoomOutButton,
        control.rotateLeftButton, control.rotateRightButton, control.resetButton }
    for i = 1, 5 do
        if not buttons[i] or buttons[i]:IsProtected() then return end
    end

    local function KeepOpaque()
        control:SetAlpha(1)
    end
    local function ShowControls()
        if not InputUtil.IsGamepadUIEnabled() then control:Show() end
    end
    local function Layout()
        if InCombatLockdown() then
            ns.CombatQueue.Defer("ForeverModelControls", Layout)
            return
        end
        for i, button in ipairs(buttons) do
            button:ClearAllPoints()
            button:SetPoint("LEFT", control, "LEFT", (i - 1) * CONTROL_WIDTH, 0)
            button:Show()
        end
        control:SetSize(#buttons * CONTROL_WIDTH, 20)
        KeepOpaque()
    end

    control:ClearAllPoints()
    control:SetPoint("LEFT", eye, "RIGHT", 4, 0)
    control:SetFrameStrata(eye:GetFrameStrata())
    control:SetFrameLevel(eye:GetFrameLevel() + 1)
    control:HookScript("OnLeave", KeepOpaque)
    -- The controls are in the title bar, outside the model's hover area.
    scene:HookScript("OnLeave", ShowControls)
    for i, button in ipairs(buttons) do
        WSkin.FadeRegions(button)
        button:SetSize(CONTROL_WIDTH, 20)
        button:SetHitRectInsets(0, 0, 0, 0)

        local art = CreateFrame("Frame", nil, button)
        art:SetSize(14, 14)
        art:SetPoint("CENTER")
        local icon = art:CreateTexture(nil, "ARTWORK")
        if i <= 2 then
            icon:SetColorTexture(1, 1, 1, 1)
            icon:SetSize(10, 2)
            icon:SetPoint("CENTER")
            if i == 1 then
                local stem = art:CreateTexture(nil, "ARTWORK")
                stem:SetColorTexture(1, 1, 1, 1)
                stem:SetSize(2, 10)
                stem:SetPoint("CENTER")
            end
        else
            local size = i == 5 and 14 or 12
            icon:SetSize(size, size)
            icon:SetPoint("CENTER")
            icon:SetTexture(i == 5 and ICONS .. "unlock-reset.png" or SIDE_ARROW)
            if i == 3 then icon:SetTexCoord(1, 0, 0, 1) end
        end
        button:HookScript("OnLeave", KeepOpaque)
        SkinControlFeedback(button, art)
    end
    -- Blizzard can reflow the native buttons when it switches cameras.
    hooksecurefunc(control, "UpdateLayout", Layout)
    Layout()
    ShowControls()
    GetFFD(control).moved = true
    return buttons
end

function ns.ForeverModelBackdrop(frame, topBar, doll, pane)
    if not (doll and pane) then return end
    -- Stay at the shell's level below the outer border and the model scene.
    local host = CreateFrame("Frame", nil, frame)
    host:SetFrameLevel(frame:GetFrameLevel())
    PinTop(host, topBar, pane)
    host:SetPoint("LEFT", frame, "LEFT", 0, 0)
    host:SetPoint("RIGHT", pane, "RIGHT", 0, 0)
    host:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    doll:HookScript("OnShow", function() host:Show() end)
    doll:HookScript("OnHide", function() host:Hide() end)
    host:SetShown(doll:IsShown())
    local tex = host:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints(host)
    tex:SetTexture(MEDIA .. "character-bg.png")
    ns.WSkin.FitBackdropOnResize(host, tex, IMG_ASPECT)
    return tex
end

local function SidebarPanel(frame, topBar)
    local host = frame.RightPaneHost
    if not host then return end
    -- A child of the pane host so it collapses with it, at the host's own
    -- level so every list and scrollbar draws over it.
    local panel = CreateFrame("Frame", nil, host)
    panel:SetFrameLevel(host:GetFrameLevel())
    PinTop(panel, topBar, host)
    panel:SetPoint("LEFT", host, "LEFT", 0, 0)
    panel:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    panel:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    local tex = panel:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints(panel)
    tex:SetColorTexture(0, 0, 0, 0.2)
    return tex
end

local STRATA_ORDER = {
    BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
    FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}

local function BuildModeTabEffects(tab, WSkin, icon, mask, squareMask)
    local border = CreateFrame("Frame", nil, tab)
    border:SetAllPoints(icon)
    WSkin.RegisterWindowIconBorder(border, nil, nil, 2 + 8) -- top right and bottom right

    local effect = tab:CreateTexture(nil, "OVERLAY")
    effect:SetAllPoints(icon)
    effect:SetBlendMode("ADD")
    effect:SetVertexColor(GLOW_GOLD.r, GLOW_GOLD.g, GLOW_GOLD.b)
    effect:AddMaskTexture(mask)
    effect:Hide()
    WSkin.RegisterWindowIcon(icon, border, nil, effect, mask, squareMask)

    local enabled, configured, hovered, current, goldBorder
    local function Paint()
        local selected = tab.SelectedTexture:IsShown()
        local gold = configured and selected or nil
        if goldBorder ~= gold then
            goldBorder = gold
            WSkin.SetWindowBorderTint(border, gold and GLOW_GOLD or nil)
        end
        local art
        if enabled then
            if selected then
                art = "highlight-3.png"
            elseif hovered then
                art = "highlight-2.png"
            end
        end
        if art == current then return end
        current = art
        if art then effect:SetTexture(ACTION_BAR_MEDIA .. art) end
        effect:SetShown(art ~= nil)
    end
    tab:HookScript("OnEnter", function()
        hovered = true
        Paint()
    end)
    local function ClearHover()
        hovered = false
        Paint()
    end
    tab:HookScript("OnLeave", ClearHover)
    tab:HookScript("OnHide", ClearHover)
    hooksecurefunc(tab, "SetChecked", Paint)
    return function(on, hasConfiguredBorder)
        enabled, configured = on, hasConfiguredBorder
        Paint()
    end
end

local function ModeTabArtwork(frame, tab, WSkin, inspect)
    local native, mask = tab.Icon, tab.Mask
    local portrait = tab == frame.ModeTabs.CharacterTab
    local function CropNative()
        native:RemoveMaskTexture(mask)
        WSkin.SetIconCrop(native, 0.075)
        native:AddMaskTexture(mask)
    end
    local icon = tab:CreateTexture(nil, "ARTWORK", nil, 1)
    local useNative
    local function PaintPortrait()
        if useNative then
            CropNative()
        else
            local unit = "player"
            if inspect then unit = frame.unit end
            if not unit then return end
            SetPortraitTexture(icon, unit, true)
            WSkin.SetIconCrop(icon, 0.045)
        end
    end
    local function SetStyle(house, configured)
        -- Extend the artwork and its mask into the clipped edge only.
        local extension = configured and 2 * OnePixel(tab) or 0
        icon:SetPoint("TOPLEFT", native, "TOPLEFT", -extension, 0)
        icon:SetPoint("BOTTOMRIGHT", native, "BOTTOMRIGHT", 0, 0)
        useNative = house or (not portrait and not configured)
        native:SetAlpha(useNative and 1 or 0)
        icon:SetShown(not useNative)
        if portrait then PaintPortrait() end
    end
    if not portrait then
        local function SyncIcon()
            icon:SetTexture(tab.iconTexture or native:GetTexture())
            WSkin.SetIconCrop(icon, 0.075)
            CropNative()
        end
        SyncIcon()
        if inspect then hooksecurefunc(frame, "SetupModeTabs", SyncIcon) end
    end
    local style = EllesmereUIDB and EllesmereUIDB.blizzWinBorderTexture
    SetStyle(not style, WSkin.IsModeTabBorderStyle(style))
    if not portrait then
        icon:AddMaskTexture(mask)
        return icon, mask, nil, SetStyle
    end
    hooksecurefunc(frame, "UpdateCharacterModeTabPortrait", PaintPortrait)
    local square = tab:CreateMaskTexture()
    square:SetBlockingLoadsRequested(true)
    square:SetTexture(EllesmereUI.SHAPE_MASKS.square, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    -- Fit the portrait to the square opening inside the 128px mask.
    local insetX, insetY = native:GetWidth() * 10 / 108, native:GetHeight() * 10 / 108
    square:SetPoint("TOPLEFT", icon, "TOPLEFT", -insetX, insetY)
    square:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", insetX, -insetY)
    icon:AddMaskTexture(square)
    return icon, square, square, SetStyle
end

local function BuildModeTabSkin(frame, WSkin, inspect)
    local host = frame.ModeTabs
    local tabs = host and host.Tabs
    local layoutMethod = inspect and "InitializeModeTabLayout" or "UpdateTabLayout"
    if not (tabs and frame[layoutMethod]) or host:IsProtected() then return end
    for _, tab in ipairs(tabs) do
        if tab:IsProtected() then return end
    end

    -- Clip on the native tab container. Keep the tab origin at its stock inset.
    local _, _, _, x, y = host:GetPoint()
    local width = host:GetWidth() + 32
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", frame, "TOPRIGHT")
    host:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, -32)
    host:SetWidth(width)
    host:SetClipsChildren(true)
    local origin = CreateFrame("Frame", nil, host)
    origin:SetSize(1, 1)
    origin:SetPoint("TOPLEFT", host, "TOPLEFT", x or 0, y or -30)

    local scale, overlap, maskExtension = 0.9, 2, 2
    local effects, artwork = {}, {}
    for _, tab in ipairs(tabs) do
        tab:SetScale(tab:GetScale() * scale)
        local mask = tab.Mask
        if mask and tab.Icon then
            local x = maskExtension / tab:GetScale()
            mask:SetWidth(mask:GetWidth() + x)
            mask:SetPoint("CENTER", tab, "CENTER", -x / 2, 0)
            local icon, nativeMask, squareMask, setStyle = ModeTabArtwork(frame, tab, WSkin, inspect)
            artwork[tab] = setStyle
            effects[tab] = BuildModeTabEffects(tab, WSkin, icon, nativeMask, squareMask)
        end
    end
    local function Layout()
        if InCombatLockdown() then
            ns.CombatQueue.Defer(origin, Layout)
            return
        end
        if host:IsProtected() then return end
        local row, step = 0, nil
        for _, tab in ipairs(tabs) do
            if tab:IsShown() then
                if tab:IsProtected() then return end
                local pixel = OnePixel(tab)
                -- Anchor every row to the same origin on the same pixel phase.
                if not step then
                    local previousStep = (tab:GetHeight() - overlap / tab:GetScale()) / pixel - 1
                    step = math.floor(previousStep + 0.5) + 4
                end
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", origin, "TOPLEFT", 0, -row * step * pixel)
                row = row + 1
            end
        end
    end
    hooksecurefunc(frame, layoutMethod, Layout)
    if inspect then hooksecurefunc(frame, "UpdateTabs", Layout) end
    host:HookScript("OnShow", function()
        Layout()
        EllesmereUI.RegisterPxReapply(origin, Layout)
    end)
    host:HookScript("OnHide", function() EllesmereUI.RegisterPxReapply(origin, nil) end)
    if host:IsVisible() then EllesmereUI.RegisterPxReapply(origin, Layout) end
    Layout()

    local previousHouse, previousConfigured
    return function(style)
        local house = not style
        local configured = WSkin.IsModeTabBorderStyle(style)
        if previousHouse == house and previousConfigured == configured then return end
        previousHouse, previousConfigured = house, configured
        for _, tab in ipairs(tabs) do
            local setStyle = artwork[tab]
            if setStyle then setStyle(house, configured) end
            WSkin.SideTab(tab, house)
            tab.Background:SetAlpha((house or configured) and 0 or 1)
            tab.TabGlow:SetVertexColor(1, 1, 1, 0)
            tab.SelectedTexture:SetVertexColor(GLOW_GOLD.r, GLOW_GOLD.g, GLOW_GOLD.b, configured and 0 or 1)
            tab.HighlightTexture:SetAlpha(house and 1 or 0)
            local paint = effects[tab]
            if paint then paint(not house, configured) end
        end
    end, host
end

local function TopLayer(strata, level, owner)
    local layer = owner:GetFrameStrata()
    if (STRATA_ORDER[layer] or 0) > (STRATA_ORDER[strata] or 0) then strata = layer end
    return strata, math.max(level, owner:GetFrameLevel())
end

local function BorderLayer(border)
    local strata, level = border:GetFrameStrata(), border:GetFrameLevel()
    local strips = EllesmereUI.PP.GetBorders(border)
    if strips and strips:IsShown() then strata, level = TopLayer(strata, level, strips) end
    local backdrop = EllesmereUI._bdBorderData[border]
    if backdrop and backdrop:IsShown() then strata, level = TopLayer(strata, level, backdrop) end
    return strata, level
end

local function PaintHorizontalCompanion(line, style, thickness, pixel)
    local pixels = EllesmereUI._pixelArtBorders[style]
    local wrap = pixels and "CLAMPTOBLACKADDITIVE" or nil
    line:SetTexture(EllesmereUI.GetBorderCompanion(style, "sepH"), wrap, wrap, pixels and "NEAREST" or nil)
    local phase = 0
    if pixels then
        -- Seat the bright texel on a pixel center rather than its shaded neighbor.
        local height = math.max(1, math.floor(thickness / pixel + 0.5))
        local stroke = 26.5 / 32
        phase = (math.floor(stroke * height) + 0.5) / height - stroke
        line:SetSnapToPixelGrid(true)
        line:SetTexelSnappingBias(0)
    end
    line:SetTexCoord(0, 1, 1 + phase, phase)
end

local accentBorderHooked
function ns.ForeverBuildDividers(frame, topBar, modelBg, sidebarBg, inspect, headerOnly)
    local right = not headerOnly and frame.RightPaneHost
    if not topBar then return end
    if not accentBorderHooked then
        accentBorderHooked = true
        EllesmereUI.RegAccent({ type = "callback", fn = function()
            if EllesmereUIDB and EllesmereUIDB.blizzWinBorderColorMode == "accent" then
                ns.WSkin.RefreshBorders()
            end
        end })
    end
    local PP = EllesmereUI.PP
    local header = CreateFrame("Frame", nil, frame)
    header:SetAllPoints(frame)
    local horizontal = header:CreateTexture(nil, "OVERLAY")
    local seam = right and CreateFrame("Frame", nil, right)
    local vertical = seam and seam:CreateTexture(nil, "OVERLAY")
    local backgrounds = { modelBg, sidebarBg }
    local skinModeTabs, tabClip
    if not headerOnly then skinModeTabs, tabClip = BuildModeTabSkin(frame, ns.WSkin, inspect) end

    local border, style, size, key, color, px, dock
    local dockSeam, dockLine
    local function Paint()
        if not border then return end
        if InCombatLockdown() then
            ns.CombatQueue.Defer(header, Paint)
            return
        end
        local es = frame:GetEffectiveScale()
        local db = EllesmereUIDB
        local pixelArt = EllesmereUI._pixelArtBorders[style]
        local geometryStyle = pixelArt and "pixels" or style
        local filter = pixelArt and "NEAREST" or nil
        local strata, level = BorderLayer(border)
        if tabClip and not tabClip:IsProtected() then
            local edge = 0
            if style then
                local _, reach = EllesmereUI.BorderReach(size, geometryStyle,
                    db.blizzWinBorderOffsetX, db.blizzWinBorderOffsetY,
                    db.blizzWinBorderShiftX, db.blizzWinBorderShiftY, "blizzardSkin", key, px, nil, 1, es)
                local overlap = (style == "glow" or pixelArt) and OnePixel(frame) or 0
                edge = math.max(0, (reach or 0) - overlap)
            end
            tabClip:SetPoint("TOPLEFT", dock or frame, "TOPRIGHT", edge, 0)
            tabClip:SetPoint("BOTTOMLEFT", dock or frame, "BOTTOMRIGHT", edge, -32)
            if pixelArt then
                tabClip:SetFrameStrata(strata)
                tabClip:SetFrameLevel(level + 5)
            else
                tabClip:SetFrameStrata(frame:GetFrameStrata())
                tabClip:SetFrameLevel(frame:GetFrameLevel() + 2)
            end
        end
        for _, bg in pairs(backgrounds) do
            strata, level = TopLayer(strata, level, bg:GetParent())
        end
        if dock then strata, level = TopLayer(strata, level, dock) end
        header:SetFrameStrata(strata)
        header:SetFrameLevel(level + (dock and 4 or 2))
        if size == 0 then
            horizontal:Hide()
            if vertical then vertical:Hide() end
            if dockSeam then dockSeam:Hide() end
            return
        end

        local thick = EllesmereUI.BorderCompanionThickness(geometryStyle, size, px, es)
        local art = thick and thick > 0
        local solid = style == "solid" and PP.GetBorders(border)
        local pixel = OnePixel(frame)
        local left, rightInset, top, bottom, dockBottom = 0, 0, 0, 0, 0
        local lead, join
        if art then
            local edge, ox, oy, sx, sy = EllesmereUI.BorderPlacement(size, geometryStyle,
                db.blizzWinBorderOffsetX, db.blizzWinBorderOffsetY,
                db.blizzWinBorderShiftX, db.blizzWinBorderShiftY, "blizzardSkin", key, px, nil, es)
            -- Inner edge of the opaque stroke in the 28 sampled texels.
            local ink = edge * 16 / 28
            -- Round towards the border at the left and bottom joins so the
            -- antialiased inner texel meets the separator on the pixel grid.
            left = math.floor((ink - ox + sx) / pixel) * pixel
            rightInset = PP.SnapForES(ink - ox - sx, es)
            top = math.ceil((ink - oy - sy) / pixel) * pixel
            bottom = math.floor((ink - oy + sy) / pixel) * pixel
            dockBottom = math.ceil((ink - oy + sy) / pixel) * pixel
            lead = PP.SnapForES(thick * 6 / 32, es)
            join = PP.SnapForES(thick * 4 / 32, es)
            PaintHorizontalCompanion(horizontal, style, thick, pixel)
        else
            thick = pixel * (style == "solid" and (px or size) or 1)
            if not style then left, rightInset, top, bottom, dockBottom = pixel, pixel, pixel, pixel, pixel end
            lead, join = PP.SnapForES(thick / 2, es), 0
            horizontal:SetColorTexture(1, 1, 1, 1)
            horizontal:SetTexCoord(0, 1, 0, 1)
        end
        horizontal:SetSnapToPixelGrid(not solid)
        horizontal:ClearAllPoints()
        if solid then
            horizontal:SetPoint("LEFT", solid._left, "RIGHT", -pixel, 0)
            if dock then
                horizontal:SetPoint("RIGHT", topBar, "RIGHT")
            else
                horizontal:SetPoint("RIGHT", solid._right, "LEFT", pixel, 0)
            end
            horizontal:SetPoint("BOTTOM", topBar, "BOTTOM", 0, -lead)
        else
            horizontal:SetPoint("BOTTOMLEFT", topBar, "BOTTOMLEFT", left - pixel, -lead)
            horizontal:SetPoint("BOTTOMRIGHT", topBar, "BOTTOMRIGHT", dock and 0 or pixel - rightInset, -lead)
        end
        horizontal:SetHeight(thick)
        horizontal:Show()

        local r, g, b = 0.25, 0.25, 0.25
        if color then r, g, b = color.r, color.g, color.b end
        horizontal:SetVertexColor(r, g, b, 1)
        if not seam then return end
        seam:SetFrameStrata(strata)
        seam:SetFrameLevel(level + (dock and 5 or 3))
        vertical:SetSnapToPixelGrid(not solid)
        if pixelArt then vertical:SetTexelSnappingBias(0) end
        seam:ClearAllPoints()
        seam:SetPoint("TOP", horizontal, "BOTTOM", 0, join)
        seam:SetPoint("LEFT", right, "LEFT", 0, 0)
        if solid then
            seam:SetPoint("BOTTOM", solid._bottom, "TOP", 0, -pixel)
        else
            seam:SetPoint("BOTTOM", frame, "BOTTOM", 0, bottom - pixel)
        end
        seam:SetWidth(thick)
        if art then
            EllesmereUI.PlaceBorderDividerV(vertical, seam, true, true, style, size, px, es, filter)
        else
            vertical:SetColorTexture(1, 1, 1, 1)
            vertical:SetTexCoord(0, 1, 0, 1)
            vertical:ClearAllPoints()
            vertical:SetPoint("TOP", seam, "TOPLEFT", 0, 0)
            vertical:SetPoint("BOTTOM", seam, "BOTTOMLEFT", 0, 0)
            vertical:SetWidth(thick)
            vertical:Show()
        end
        vertical:SetVertexColor(r, g, b, 1)
        if dock then
            if not dockSeam then
                dockSeam = CreateFrame("Frame", nil, frame)
                dockLine = dockSeam:CreateTexture(nil, "OVERLAY")
            end
            dockSeam:SetFrameStrata(strata)
            dockSeam:SetFrameLevel(level + 3)
            dockSeam:SetWidth(thick)
            dockSeam:ClearAllPoints()
            local offset = 0
            if pixelArt then
                -- The mirrored companion's inner stroke begins six texels from its lead.
                local stroke = PP.SnapForES(thick * 6 / 32, es)
                local overhang = PP.SnapForES(thick * 2 / EllesmereUI.GetBorderCompanion(style, "sepSize"), es)
                offset = stroke - overhang
            end
            dockSeam:SetPoint("LEFT", frame, "RIGHT", offset, 0)
            if solid then
                dockSeam:SetPoint("TOP", solid._top, "BOTTOM")
                dockSeam:SetPoint("BOTTOM", solid._bottom, "TOP")
            else
                local extension = pixelArt and 2 * pixel or 0
                dockSeam:SetPoint("TOP", frame, "TOP", 0, -top + extension)
                dockSeam:SetPoint("BOTTOM", frame, "BOTTOM", 0, dockBottom - extension)
            end
            dockLine:SetSnapToPixelGrid(not solid)
            if pixelArt then dockLine:SetTexelSnappingBias(0) end
            if art then
                EllesmereUI.PlaceBorderDividerV(dockLine, dockSeam, true, true, style, size, px, es, filter)
            else
                dockLine:ClearAllPoints()
                dockLine:SetAllPoints(dockSeam)
                dockLine:SetColorTexture(1, 1, 1, 1)
                dockLine:SetTexCoord(0, 1, 0, 1)
                dockLine:Show()
            end
            dockLine:SetVertexColor(r, g, b, 1)
        end
        if dockSeam then dockSeam:SetShown(dock ~= nil) end
    end
    EllesmereUI.RegisterPxReapply(header, Paint)
    return function(outer, texture, step, thickness, tint, exact, attachment)
        border, style, size, key, color, px, dock = outer, texture, step, thickness, tint, exact, attachment
        if skinModeTabs then skinModeTabs(style) end
        Paint()
    end
end

function ns.ForeverColorLevelLabel(label)
    if not label then return end
    local text, word = label:GetText(), _G.LEVEL
    if not (text and word and word ~= "") or (issecretvalue and issecretvalue(text)) then return end
    local first, last = text:find(word, 1, true)
    if not first then return end
    local prefix = text:sub(1, first - 1)
    local openColor = (prefix:match(".*|r(.*)") or prefix):match(".*(|c%x%x%x%x%x%x%x%x)")
    if openColor == "|cffffffff" then return end
    label:SetText(prefix .. "|cffffffff" .. word .. "|r" .. (openColor or "") .. text:sub(last + 1))
end

function ns.ForeverLevelRowY()
    local tab = _G.PaperDollSidebarTab1
    return -1 - (tab and tab:GetHeight() or 22) / 2
end

local titleSize
function ns.ForeverTitleSize()
    if not titleSize then
        local frame = _G.CharacterFrame
        local title = frame and ((frame.TitleContainer and frame.TitleContainer.TitleText) or _G.CharacterFrameTitleText)
        titleSize = title and select(2, title:GetFont()) or 12
    end
    return titleSize
end

local function SkinPaperDollHeader(WSkin, modelBg, sidebarBg, fontSize)
    local firstTab = _G.PaperDollSidebarTab1
    local tabHost = _G.PaperDollSidebarTabs
    if not (firstTab and tabHost) then return end
    local hostTop, tabTop = 4, -5
    if sidebarBg and not tabHost:IsProtected() then
        tabHost:ClearAllPoints()
        tabHost:SetPoint("TOP", sidebarBg, "TOP", 0, hostTop)
    end
    local rowY = ns.ForeverLevelRowY()
    for _, level in pairs({ _G.CharacterLevelText, _G.PetCharacterLevelText }) do
        WSkin.Font(level, nil, nil, nil, fontSize)
        ns.ForeverColorLevelLabel(level)
        if modelBg then
            level:ClearAllPoints()
            level:SetPoint("CENTER", modelBg, "TOP", 0, rowY)
        end
    end
    hooksecurefunc("PaperDollFrame_SetLevel", function() ns.ForeverColorLevelLabel(_G.CharacterLevelText) end)
    hooksecurefunc("PaperDollFrame_SetPetLevel", function() ns.ForeverColorLevelLabel(_G.PetCharacterLevelText) end)
    local names = { EllesmereUI.L("Character"), EllesmereUI.L("Equipment"), EllesmereUI.L("Titles"), EllesmereUI.L("Pet") }
    local tabs = {}
    local gap = 10
    local function Paint(entry)
        local tab, label, underline = entry.tab, entry.label, entry.underline
        local accent = EllesmereUI.ELLESMERE_GREEN
        local selected = tab:IsEnabled() and tab:GetChecked() and accent ~= nil
        underline:SetShown(selected == true)
        if not tab:IsEnabled() then
            label:SetTextColor(1, 1, 1, 0.28)
        elseif selected then
            label:SetTextColor(accent.r, accent.g, accent.b, 1)
            underline:SetColorTexture(accent.r, accent.g, accent.b, 1)
        else
            label:SetTextColor(1, 1, 1, tab:IsMouseOver() and 1 or 0.6)
        end
    end
    local function Sync()
        for _, entry in ipairs(tabs) do Paint(entry) end
    end
    local function Layout()
        if InCombatLockdown() then
            ns.CombatQueue.Defer("ForeverSidebarTabs", Layout)
            return
        end
        local total, count = 0, 0
        for _, entry in ipairs(tabs) do
            if entry.tab:IsShown() then
                if entry.tab:IsProtected() then return end
                total = total + entry.width
                count = count + 1
            end
        end
        if total == 0 then return end
        local ratio = math.min(1, math.max(1, tabHost:GetWidth() - count * gap) / total)
        local x = -(total * ratio + count * gap) / 2
        for _, entry in ipairs(tabs) do
            local tab = entry.tab
            if tab:IsShown() then
                local w = entry.width * ratio + gap
                tab:SetWidth(w)
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", tabHost, "TOP", x, tabTop)
                x = x + w
            end
        end
    end
    for i, name in ipairs(names) do
        local tab = _G["PaperDollSidebarTab" .. i]
        if tab then
            WSkin.FadeRegions(tab)
            local label = tab:CreateFontString(nil, "OVERLAY")
            WSkin.Font(label, nil, nil, nil, fontSize)
            label:SetWordWrap(false)
            label:SetText(name)
            local width = math.max(1, label:GetStringWidth())
            label:SetPoint("LEFT", tab, "LEFT", gap / 2, 0)
            label:SetPoint("RIGHT", tab, "RIGHT", -gap / 2, 0)
            label:SetJustifyH("CENTER")
            local underline = tab:CreateTexture(nil, "OVERLAY")
            underline:SetSize(width, OnePixel(tab))
            underline:SetPoint("TOP", label, "BOTTOM", 0, -2)
            local entry = { tab = tab, label = label, width = width, underline = underline }
            tabs[#tabs + 1] = entry
            local function Repaint() Paint(entry) end
            tab:HookScript("OnEnter", Repaint)
            tab:HookScript("OnLeave", Repaint)
            tab:HookScript("OnEnable", Repaint)
            tab:HookScript("OnDisable", Repaint)
        end
    end
    hooksecurefunc("PaperDollFrame_UpdateSidebarTabLayout", Layout)
    hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", Sync)
    EllesmereUI.RegAccent({ type = "callback", fn = Sync })
    Layout()
    Sync()
end

local LIST_INSET, LIST_Y = 20, -8

local function SkinSheetScroll(box, WSkin, nativeArt, fadeContent)
    local scroll = box and box.ScrollBox
    local bar = box and box.ScrollBar
    if not (scroll and bar) then return end
    if not nativeArt then WSkin.ScrollBar(bar) end
    local track = bar.Track
    local thumb = track and track.Thumb
    local bg, fill
    if track then
        if nativeArt then nativeArt(track) end
        bg = track:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOP", track)
        bg:SetPoint("BOTTOM", track)
        bg:SetWidth(5)
        bg:SetColorTexture(1, 1, 1, 0.12)
        EllesmereUI.RoundBody(track, bg, 2)
        if thumb then
            if nativeArt then
                nativeArt(thumb)
                fill = thumb:CreateTexture(nil, "ARTWORK")
                fill:SetPoint("TOP", thumb)
                fill:SetPoint("BOTTOM", thumb)
            else
                fill = WSkin.GetFFD(thumb).bg
            end
            if fill then
                fill:SetWidth(4)
                fill:SetColorTexture(1, 1, 1, 0.45)
                EllesmereUI.RoundBody(thumb, fill, 2)
            end
        end
    end
    if nativeArt then
        nativeArt(bar.Back)
        nativeArt(bar.Forward)
    end

    local enabled, stockAlpha = not nativeArt, bar:GetAlpha()
    local function UpdateHover()
        if enabled then
            bar:SetAlpha(box:IsVisible() and box:IsMouseOver() and scroll:HasScrollableExtent() and 1 or 0)
        end
    end
    GetFFD(box).statsHover = UpdateHover
    box:SetMouseMotionEnabled(true)
    for _, region in pairs({ box, scroll, bar, track, track and track.Thumb, bar.Back, bar.Forward }) do
        region:HookScript("OnEnter", UpdateHover)
        region:HookScript("OnLeave", UpdateHover)
    end
    box:HookScript("OnHide", function() if enabled then bar:SetAlpha(0) end end)

    local UpdateFade
    if not nativeArt or fadeContent then
        local fade, clear = CreateVector2D(0, 16), CreateVector2D(0, 0)
        local fading
        UpdateFade = function()
            local show = enabled and scroll:HasScrollableExtent() and scroll:GetScrollPercentage() < ScrollBoxConstants.ScrollEnd
            if fading ~= show then
                fading = show
                scroll:SetAlphaGradient(1, show and fade or clear)
            end
        end
        scroll:RegisterCallback(BaseScrollBoxEvents.OnScroll, UpdateFade, box)
        UpdateFade()
    end
    local function UpdateLayout()
        UpdateHover()
        if UpdateFade then UpdateFade() end
    end
    scroll:RegisterCallback(BaseScrollBoxEvents.OnLayout, UpdateLayout, box)
    box:HookScript("OnShow", UpdateLayout)
    UpdateHover()
    if nativeArt then
        return function(on)
            if enabled == on then return end
            if on then stockAlpha = bar:GetAlpha() end
            enabled = on
            if UpdateFade then UpdateFade() end
            if bg then bg:SetShown(on) end
            if fill then fill:SetShown(on) end
            if on then
                UpdateHover()
            else
                bar:SetAlpha(stockAlpha)
            end
        end
    end
end

local function SkinStatsScroll(box, WSkin)
    local scroll = box and box.ScrollBox
    if not (scroll and box.ScrollBar) then return end
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", LIST_INSET, LIST_Y)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -LIST_INSET, 30)
    SkinSheetScroll(box, WSkin)
end

local equipmentBorderColor = {}
local function PaintEquipmentBorder(host, style, WSkin, color)
    local pp = EllesmereUI.PanelPP or EllesmereUI.PP
    if style then
        pp.HideBorder(host)
        return EllesmereUI._applyBlizzardConfiguredBorder(host, "blizzWin", 1, color, 1, nil,
            EllesmereUI._pixelArtBorders[style])
    end
    EllesmereUI._hideBlizzardConfiguredBorder(host)
    WSkin.AddBorder(host)
    local theme = WSkin.Theme
    equipmentBorderColor.r, equipmentBorderColor.g, equipmentBorderColor.b = theme.brdR, theme.brdG, theme.brdB
    color = color or equipmentBorderColor
    pp.SetBorderColor(host, color.r, color.g, color.b, theme.brdA)
    pp.ShowBorder(host)
    return pp.GetBorders(host), 1, nil, color, 1, "solid"
end

local function HookEquipmentFlyout(pane, WSkin)
    local flyout = _G.EquipmentFlyoutFrame
    if not (flyout and flyout.buttonFrame and _G.EquipmentFlyout_UpdateItems) then return end
    local anchor = flyout.buttonFrame
    local arrows, sources, tiles, hidden, arrowAlpha, qualities = {}, {}, {}, {}, {}, {}
    local stockPoint = {}
    local enabled, stockWidth, stockHeight, arrowsShown, Refresh
    local modifierGlow, modifierIcon

    local function PositionModifierIcon(icon, source)
        local direction = source.flyoutDirection or source.popoutButton.flyoutDirection
        local slotEdge, flyoutEdge, point
        local vertical = direction == "UP" or direction == "DOWN"
        if direction == "LEFT" then
            slotEdge, flyoutEdge, point = source:GetLeft(), anchor:GetRight(), "LEFT"
        elseif direction == "UP" then
            slotEdge, flyoutEdge, point = source:GetTop(), anchor:GetBottom(), "TOP"
        elseif direction == "DOWN" then
            slotEdge, flyoutEdge, point = source:GetBottom(), anchor:GetTop(), "BOTTOM"
        else
            slotEdge, flyoutEdge, point = source:GetRight(), anchor:GetLeft(), "RIGHT"
        end
        if slotEdge and flyoutEdge then
            local scale = anchor:GetEffectiveScale() / source:GetEffectiveScale()
            local offset = (flyoutEdge * scale - slotEdge) / 2
            icon:SetPoint("CENTER", source, point, vertical and 0 or offset, vertical and offset or 0)
        else
            icon:SetPoint("CENTER", source.popoutButton)
        end
    end

    local function SetModifierFeedback(source)
        local glow, icon
        if source and not source.popoutButton.flyoutLocked then
            local data = GetFFD(source)
            glow = data.altFlyoutGlow
            local characterTab = _G.PaperDollSidebarTab1
            if glow and characterTab and characterTab:GetChecked() then
                icon = data.altFlyoutIcon
                if not icon then
                    icon = source:CreateTexture(nil, "OVERLAY", nil, 5)
                    icon:SetSize(24, 24)
                    icon:SetTexture(ICONS .. "unlock-center.png")
                    icon:Hide()
                    data.altFlyoutIcon = icon
                end
            end
        end
        if icon then PositionModifierIcon(icon, source) end
        if modifierIcon ~= icon then
            if modifierIcon then modifierIcon:Hide() end
            modifierIcon = icon
            if icon then
                local accent = EllesmereUI.ELLESMERE_GREEN
                icon:SetVertexColor(accent.r, accent.g, accent.b)
                icon:Show()
            end
        end
        if modifierGlow == glow then return end
        if modifierGlow then modifierGlow:Hide() end
        modifierGlow = glow
        if glow then glow:Show() end
    end

    for _, name in ipairs(SLOTS) do
        local slot = _G[name]
        local button = slot and slot.popoutButton
        if button and not button:IsProtected() then
            sources[slot] = true
            local icon = button:CreateTexture(nil, "OVERLAY")
            icon:SetSize(12, 12)
            icon:SetPoint("CENTER")
            icon:SetTexture(SIDE_ARROW)
            local direction = slot.flyoutDirection or button.flyoutDirection
            local x, y = 0, 0
            if direction == "LEFT" then
                icon:SetTexCoord(1, 0, 0, 1)
                x = 2
            elseif direction == "UP" then
                icon:SetRotation(math.pi / 2)
                y = -2
            elseif direction == "DOWN" then
                icon:SetRotation(-math.pi / 2)
                y = 2
            else
                x = -2
            end
            arrows[button] = { art = icon, point = { button:GetPoint() }, x = x, y = y }
        end
    end

    local function HideArrowTextures(...)
        for i = 1, select("#", ...) do
            local texture = select(i, ...)
            if texture then
                local alpha = texture:GetAlpha()
                if arrowAlpha[texture] == nil or alpha ~= 0 then arrowAlpha[texture] = alpha end
                texture:SetAlpha(0)
            end
        end
    end

    local function SkinArrow(button)
        HideArrowTextures(button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture())
    end

    -- The popout reassigns its atlases on click, hover and lock changes.
    hooksecurefunc("EquipmentFlyoutPopoutButton_RefreshVisualState", function(button)
        if arrowsShown and arrows[button] then SkinArrow(button) end
    end)

    local function HideArt(region)
        if not region then return end
        local alpha = region:GetAlpha()
        if hidden[region] == nil or alpha ~= 0 then hidden[region] = alpha end
        region:SetAlpha(0)
    end

    local function PaintTileCorners(tile, style)
        local softOwner = (style == "glow" or style == "shadow") and tile.host
        local border = (softOwner or style == "solid") and tile.border
        local st = WSkin.PaintIconCorners(tile.art, tile, style, border, softOwner)
        if st then
            EllesmereUI.MaskRoundedIconLayer(st, tile.hover)
            EllesmereUI.MaskRoundedIconLayer(st, tile.flash)
        end
    end

    local function RestoreFlyout(restoreSize)
        SetModifierFeedback()
        if not stockWidth then return end
        for region, alpha in pairs(hidden) do region:SetAlpha(alpha) end
        wipe(hidden)
        for button, tile in pairs(tiles) do
            if tile.points and not button:IsProtected() then
                PaintTileCorners(tile)
                tile.hover:Hide()
                tile.flash:Hide()
                if tile.specialIcon then tile.specialIcon:Hide() end
                tile.art = tile.icon
                button:ClearAllPoints()
                button:SetPoint(unpack(tile.points, 1, 5))
                button:SetSize(tile.width, tile.height)
                tile.icon:ClearAllPoints()
                for _, point in ipairs(tile.iconPoints) do tile.icon:SetPoint(unpack(point, 1, 5)) end
                tile.icon:SetTexCoord(unpack(tile.coords))
                if tile.mask then tile.icon:AddMaskTexture(tile.mask) end
                tile.points, tile.mask = nil, nil
                tile.host:Hide()
            end
        end
        if restoreSize and not anchor:IsProtected() then
            anchor:ClearAllPoints()
            if stockPoint[1] then anchor:SetPoint(unpack(stockPoint, 1, 5)) end
            anchor:SetSize(stockWidth, stockHeight)
        end
        stockWidth, stockHeight = nil, nil
        wipe(stockPoint)
    end

    -- Blizzard already resolves quality when it populates the flyout tiles.
    hooksecurefunc("SetItemButtonQuality", function(button, quality)
        if sources[flyout.button] and button and button:GetParent() == anchor then qualities[button] = quality end
    end)

    -- Keep the command artwork stable when Blizzard refreshes a pooled button.
    local function SetTileArtwork(button, tile, special)
        local native = tile.icon
        if special and not tile.specialIcon then
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(native)
            icon:SetBlockingLoadsRequested(true)
            tile.specialIcon = icon
        end
        local art = special and tile.specialIcon or native
        if art ~= tile.art or (special and special ~= tile.specialTexture) then
            EllesmereUI.RoundAuraCorners(button, tile, tile.art, nil, false, 0)
            tile.art = art
            if special ~= tile.specialTexture and special then
                art:SetTexture(special)
                WSkin.SetIconCrop(art, 0.1)
                tile.specialTexture = special
            end
        end
        if special then
            HideArt(native)
            art:Show()
        elseif tile.specialIcon then
            tile.specialIcon:Hide()
            local alpha = hidden[native]
            if alpha then
                native:SetAlpha(alpha)
                hidden[native] = nil
            end
        end
    end

    local function PaintTile(button, style, width, height)
        local icon = button.icon
        local tile = tiles[button]
        if not tile then
            local host = CreateFrame("Frame", nil, button)
            host:SetAllPoints()
            local hover, flash = BuildSlotHover(button, icon)
            tile = { host = host, iconBounds = button, icon = icon, art = icon, hover = hover, flash = flash, color = {} }
            tiles[button] = tile
        end
        local mask = button.Mask
        if not tile.points then
            tile.points, tile.coords = { button:GetPoint() }, { icon:GetTexCoord() }
            tile.width, tile.height = button:GetSize()
            tile.iconPoints = {}
            for i = 1, icon:GetNumPoints() do tile.iconPoints[i] = { icon:GetPoint(i) } end
            icon:ClearAllPoints()
            icon:SetAllPoints(button)
            if mask and icon:GetNumMaskTextures() == 1 and icon:GetMaskTexture(1) == mask then
                tile.mask = mask
                icon:RemoveMaskTexture(mask)
            end
        end
        VisitSlotChrome(button, HideArt)
        tile.hover:Show()
        local currentWidth, currentHeight = button:GetSize()
        if currentWidth ~= width or currentHeight ~= height then button:SetSize(width, height) end
        tile.host:Show()
        local r, g, b
        local special
        local location = button.location
        local numericLocation = type(location) == "number" and not (issecretvalue and issecretvalue(location))
        if numericLocation and location == _G.EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION then
            special = "Interface\\PaperDollInfoFrame\\UI-GearManager-ItemIntoBag"
            local accent = EllesmereUI.ELLESMERE_GREEN
            r, g, b = accent.r, accent.g, accent.b
        elseif numericLocation and location == _G.EQUIPMENTFLYOUT_IGNORESLOT_LOCATION then
            special = "Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Opaque"
            r, g, b = 1, 0.2, 0.2
        elseif numericLocation and location == _G.EQUIPMENTFLYOUT_UNIGNORESLOT_LOCATION then
            special = "Interface\\PaperDollInfoFrame\\UI-GearManager-Undo"
            r, g, b = 1, 0.9, 0.2
        elseif button.UpdateTooltip then
            r, g, b = ItemQualityColor(qualities[button])
        end
        SetTileArtwork(button, tile, special)
        if not special and math.abs(icon:GetTexCoord() - 0.1) > 0.0001 then
            EllesmereUI.RoundAuraCorners(button, tile, icon, nil, false, 0)
            WSkin.SetIconCrop(icon, 0.1)
        end
        local color = tile.color
        color.r, color.g, color.b = r, g, b
        local border, size = PaintEquipmentBorder(tile.host, style, WSkin, r and color)
        tile.border = size and size > 0 and border or nil
        PaintTileCorners(tile, style)
    end

    local function PaintFlyout(nativeUpdate)
        if InCombatLockdown() then
            ns.CombatQueue.Defer("ForeverEquipmentFlyout", function() Refresh(enabled) end)
            return
        end
        local source = flyout.button
        if not (enabled and sources[source] and source:IsVisible()) then
            RestoreFlyout(not nativeUpdate)
            return
        end
        local style = EllesmereUIDB.blizzWinBorderTexture
        local buttons = flyout.buttons
        if not buttons or not buttons[1] or anchor:IsProtected() then return end
        if nativeUpdate or not stockWidth then
            stockWidth, stockHeight = anchor:GetSize()
            stockPoint[1], stockPoint[2], stockPoint[3], stockPoint[4], stockPoint[5] = anchor:GetPoint()
        end
        HideArt(flyout.Highlight)
        HideArt(flyout.NavigationFrame and flyout.NavigationFrame.BottomBackground)
        for i = 1, anchor.numBGs or 0 do HideArt(anchor["bg" .. i]) end

        local columns = _G.EQUIPMENTFLYOUT_ITEMS_PER_ROW or 5
        local width, height = source:GetSize()
        local scale = source:GetEffectiveScale() / anchor:GetEffectiveScale()
        width, height = width * scale, height * scale
        local gap, count = 6 * scale, 0 -- The sheet's item-slot spacing.
        for _, button in ipairs(buttons) do
            if button:IsShown() then
                if not button:IsProtected() and button.icon then
                    PaintTile(button, style, width, height)
                    button:ClearAllPoints()
                    button:SetPoint("TOPLEFT", anchor, "TOPLEFT",
                        (count % columns) * (width + gap), -math.floor(count / columns) * (height + gap))
                end
                count = count + 1
            end
        end
        if count > 0 then
            local rows = math.ceil(count / columns)
            local across = math.min(count, columns)
            anchor:SetSize(across * (width + gap) - gap, rows * (height + gap) - gap)
            local arrow = source.popoutButton or source
            local direction = source.flyoutDirection or arrow.flyoutDirection
            anchor:ClearAllPoints()
            if direction == "UP" or direction == "DOWN" then
                anchor:SetPoint("LEFT", source, "LEFT")
                if direction == "UP" then
                    anchor:SetPoint("BOTTOM", arrow, "TOP", 0, gap)
                else
                    anchor:SetPoint("TOP", arrow, "BOTTOM", 0, -gap)
                end
            else
                anchor:SetPoint("TOP", source, "TOP")
                if direction == "LEFT" then
                    anchor:SetPoint("RIGHT", arrow, "LEFT", -gap, 0)
                else
                    anchor:SetPoint("LEFT", arrow, "RIGHT", gap, 0)
                end
            end
        end
        SetModifierFeedback(count > 0 and source or nil)
    end
    hooksecurefunc("EquipmentFlyout_UpdateItems", function()
        if flyout:IsShown() then PaintFlyout(true) end
    end)
    flyout:HookScript("OnShow", function() PaintFlyout(true) end)
    hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", function()
        local source = flyout.button
        if enabled and flyout:IsShown() and sources[source] then SetModifierFeedback(source) end
    end)
    hooksecurefunc(WSkin, "RefreshIconCorners", function()
        if not (enabled and stockWidth and flyout:IsShown()) or InCombatLockdown() then return end
        local style = EllesmereUIDB.blizzWinBorderTexture
        for button, tile in pairs(tiles) do
            if tile.points and button:IsShown() and not button:IsProtected() then
                PaintTileCorners(tile, style)
            end
        end
    end)

    local function TintArrows()
        local accent = EllesmereUI.ELLESMERE_GREEN
        for _, entry in pairs(arrows) do entry.art:SetVertexColor(accent.r, accent.g, accent.b) end
    end
    EllesmereUI.RegAccent({ type = "callback", fn = function()
        if arrowsShown then TintArrows() end
        if modifierIcon then
            local accent = EllesmereUI.ELLESMERE_GREEN
            modifierIcon:SetVertexColor(accent.r, accent.g, accent.b)
        end
        if enabled and flyout:IsShown() then PaintFlyout(false) end
    end })

    Refresh = function(on)
        enabled = on
        if InCombatLockdown() then
            ns.CombatQueue.Defer("ForeverEquipmentFlyout", function() Refresh(enabled) end)
            return
        end
        local show = on and pane:IsVisible()
        if arrowsShown ~= show then
            arrowsShown = show
            if show then TintArrows() end
            for button, entry in pairs(arrows) do
                entry.art:SetShown(show)
                local point = entry.point
                if point[1] and not button:IsProtected() then
                    button:SetPoint(point[1], point[2], point[3],
                        (point[4] or 0) + (show and entry.x or 0), (point[5] or 0) + (show and entry.y or 0))
                end
                if show then SkinArrow(button) end
            end
            if not show then
                for texture, alpha in pairs(arrowAlpha) do texture:SetAlpha(alpha) end
                wipe(arrowAlpha)
            end
        end
        if flyout:IsShown() then PaintFlyout(false) else RestoreFlyout(true) end
    end
    pane:HookScript("OnHide", function() Refresh(enabled) end)
    flyout:HookScript("OnHide", function()
        SetModifierFeedback()
        if not InCombatLockdown() then RestoreFlyout(true) end
    end)
    return Refresh
end

local function SkinPickerDropdown(dropdown, WSkin)
    WSkin.Dropdown(dropdown)
    if not dropdown.OnMenuOpened or not dropdown.OnMenuClosed then return end
    dropdown:SetMenuAnchor(AnchorUtil.CreateAnchor("TOPLEFT", dropdown, "BOTTOMLEFT", 0, 0))
    local edge = CreateFrame("Frame", nil, dropdown)
    local theme = WSkin.Theme
    local fill = WSkin.SolidTex(edge, "BACKGROUND", theme.bgR, theme.bgG, theme.bgB, 1)
    local dividerHost = CreateFrame("Frame", nil, edge)
    dividerHost:SetAllPoints(edge)
    local divider = dividerHost:CreateTexture(nil, "OVERLAY")
    divider:SetPoint("LEFT", edge)
    divider:SetPoint("RIGHT", edge)
    edge:Hide()
    local pp = EllesmereUI.PanelPP or EllesmereUI.PP
    local defaultColor = { r = 0.25, g = 0.25, b = 0.25 }
    local function PaintBorder()
        local style = EllesmereUIDB.blizzWinBorderTexture
        local tint = not style and defaultColor or nil
        if not edge:IsShown() then
            PaintEquipmentBorder(dropdown, style, WSkin, tint)
            return
        end
        pp.HideBorder(dropdown)
        EllesmereUI._hideBlizzardConfiguredBorder(dropdown)
        local border, size, _, color, px, texture = PaintEquipmentBorder(edge, style, WSkin, tint)
        if not border or size <= 0 then divider:Hide(); return end
        local strata, level = BorderLayer(border)
        dividerHost:SetFrameStrata(strata)
        dividerHost:SetFrameLevel(level + 1)
        local es = edge:GetEffectiveScale()
        local thick = EllesmereUI.BorderCompanionThickness(texture, size, px, es)
        local lead = 0
        if thick and thick > 0 then
            PaintHorizontalCompanion(divider, texture, thick, OnePixel(edge))
            lead = EllesmereUI.PP.SnapForES(thick * 6 / 32, es)
        else
            thick = (px or size) * OnePixel(edge)
            divider:SetColorTexture(1, 1, 1, 1)
            divider:SetTexCoord(0, 1, 0, 1)
        end
        divider:SetPoint("BOTTOM", dropdown, "BOTTOM", 0, -lead)
        divider:SetHeight(thick)
        divider:SetVertexColor(color.r, color.g, color.b, 1)
        divider:Show()
    end
    local menu, painted, art, fonts = nil, nil, {}, {}
    local Refresh = WSkin.Debounce(function()
        if painted and not painted:IsForbidden() and (not painted:IsShown() or painted:GetOwnerRegion() == dropdown) then
            for region, alpha in pairs(art) do region:SetAlpha(alpha) end
            for label, font in pairs(fonts) do label:SetFontObject(font) end
        end
        painted = nil
        wipe(art)
        wipe(fonts)
        if not (menu and menu:IsShown() and not menu:IsForbidden() and menu:GetOwnerRegion() == dropdown) then
            edge:Hide()
            edge:ClearAllPoints()
            fill:ClearAllPoints()
            PaintBorder()
            return
        end
        painted = menu
        for _, region in ipairs({ menu:GetRegions() }) do
            if region:IsObjectType("Texture") then
                art[region] = region:GetAlpha()
                region:SetAlpha(0)
            end
        end
        EllesmereUI._hideBlizzardConfiguredBorder(menu)
        for _, child in ipairs({ menu:GetChildren() }) do
            for _, label in ipairs({ child:GetRegions() }) do
                if label:IsObjectType("FontString") and label:GetFontObject() then
                    fonts[label] = label:GetFontObject()
                    WSkin.FontFamily(label)
                end
            end
        end
        edge:ClearAllPoints()
        edge:SetPoint("TOPLEFT", dropdown)
        edge:SetPoint("BOTTOMRIGHT", menu)
        edge:SetFrameStrata(menu:GetFrameStrata())
        edge:SetFrameLevel(menu:GetFrameLevel())
        fill:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT")
        fill:SetPoint("BOTTOMRIGHT", menu)
        edge:Show()
        PaintBorder()
    end)
    hooksecurefunc(dropdown, "OnMenuOpened", function(_, opened)
        menu = opened
        WSkin.GetFFD(opened).embeddedDropdownMenu = true
        Refresh()
    end)
    hooksecurefunc(dropdown, "OnMenuClosed", function(_, closed)
        WSkin.GetFFD(closed).embeddedDropdownMenu = nil
        if closed == menu then menu = nil end
        Refresh()
    end)
    PaintBorder()
    return PaintBorder
end

local function HookEquipmentSkin(WSkin, sheet)
    local pane = _G.PaperDollFrame.EquipmentManagerPane
    if not pane then return end
    local popup = _G.GearManagerPopupFrame
    local surfaces, stock, extras, pickerFonts = {}, {}, {}, {}
    local active, setScroll, paneBuilt, popupBuilt, setFlyout, setPickerScroll, refreshPickerIcons, pickerShell
    local paintPickerDropdown
    local Update

    local function SaveArt(region)
        if region and stock[region] == nil then stock[region] = region:GetAlpha() end
        if region and active then region:SetAlpha(0) end
    end
    local function SaveTextures(owner, keep)
        if not owner then return end
        for _, region in ipairs({ owner:GetRegions() }) do
            if region ~= keep and region:IsObjectType("Texture") then SaveArt(region) end
        end
        SaveArt(owner.NineSlice)
    end

    -- The cards and footer buttons share horizontal pixels, with native heights.
    local function SnapSides(host, left, right)
        local pp = EllesmereUI.PP
        local scale = host:GetEffectiveScale()
        local leftEdge, rightEdge = left:GetLeft(), right:GetRight()
        leftEdge = leftEdge and leftEdge * left:GetEffectiveScale() / scale
        rightEdge = rightEdge and rightEdge * right:GetEffectiveScale() / scale
        host:SetPoint("LEFT", left, "LEFT", leftEdge and pp.SnapForES(leftEdge, scale) - leftEdge or 0, 0)
        host:SetPoint("RIGHT", right, "RIGHT", rightEdge and pp.SnapForES(rightEdge, scale) - rightEdge or 0, 0)
    end

    local function PaintButtonBorderState(surface)
        if not (active and surface.pixelBorder) then return end
        local color = surface.pixelBorderColor
        local shade = surface.button:IsEnabled() and 1 or 0.65
        EllesmereUI.SetBorderStyleColor(surface.pixelBorder, color.r * shade, color.g * shade, color.b * shade, 1)
    end

    local function Paint(surface)
        surface.host:SetShown(active)
        surface.fill:SetShown(active)
        -- The mask owner must contain both the background and the hover textures.
        local maskOwner = surface.row or surface.button or surface.host
        if not active then
            EllesmereUI.RoundCorners(maskOwner, 0)
            if surface.icon then EllesmereUI.RoundAuraCorners(maskOwner, surface, surface.icon, nil, false, 0) end
            return
        end
        if surface.row and not surface.row:IsVisible() then
            surface.pendingPaint = true
            return
        end
        surface.pendingPaint = nil
        if surface.left then SnapSides(surface.host, surface.left, surface.right) end
        local db = EllesmereUIDB
        local style = db.blizzWinBorderTexture
        local border, size, key, color, px, texture = PaintEquipmentBorder(surface.host, style, WSkin, surface.borderTint)
        surface.pixelBorder = surface.button and EllesmereUI._pixelArtBorders[style] and border or nil
        surface.pixelBorderColor = surface.pixelBorder and color or nil
        PaintButtonBorderState(surface)
        if not border then return end
        local radius = style and not surface.square and db.blizzWinCornerRadius or 0
        EllesmereUI.RoundCorners(maskOwner, radius, {
            rect = surface.host, border = border, style = texture, roots = {}, textures = surface.body or { surface.fill },
        })
        local icon = surface.icon
        if icon then
            -- Use the slot icon's full-texture mask; the card keeps its own outline.
            local iconRadius = EllesmereUI.RoundedStyleOK(style) and radius or 0
            local width, height = icon:GetSize()
            if iconRadius == 0 or (width and height and width > 0 and height > 0) then
                EllesmereUI.RoundAuraCorners(maskOwner, surface, icon, nil, false, iconRadius, width, height, 1 + 4)
            else
                surface.pendingPaint = true
            end
        end
        local separator = surface.separator
        if not separator then return end
        local sep, anchor = separator.texture, separator.anchor
        local backdrop = EllesmereUI._bdBorderData[border]
        local layer = backdrop and backdrop:IsShown() and backdrop or border
        anchor:SetFrameStrata(layer:GetFrameStrata())
        anchor:SetFrameLevel(math.max(border:GetFrameLevel(), layer:GetFrameLevel()) + 1)
        local es = anchor:GetEffectiveScale()
        if size <= 0 then
            sep:Hide()
        elseif texture == "solid" then
            sep:ClearAllPoints()
            sep:SetPoint("TOPLEFT", anchor)
            sep:SetPoint("BOTTOMLEFT", anchor)
            sep:SetWidth((px or size) * OnePixel(anchor))
            sep:SetColorTexture(1, 1, 1, 1)
            sep:Show()
        else
            EllesmereUI.PlaceBorderDividerV(sep, anchor, false, false, texture, size, px, es,
                EllesmereUI._pixelArtBorders[texture] and "NEAREST" or nil)
        end
        sep:SetVertexColor(color.r, color.g, color.b, 1)
    end

    local function Box(owner, bounds, button)
        local host = CreateFrame("Frame", nil, owner)
        host:SetAllPoints(bounds or owner)
        host:EnableMouse(false)
        local fill = owner:CreateTexture(nil, "BACKGROUND", nil, -1)
        fill:SetAllPoints(host)
        local theme = WSkin.Theme
        fill:SetColorTexture(theme.bgR, theme.bgG, theme.bgB, theme.bgA)
        local surface = { host = host, fill = fill }
        surfaces[#surfaces + 1] = surface
        if button then
            surface.button = owner
            local hover = host:CreateTexture(nil, "ARTWORK")
            hover:SetAllPoints()
            hover:SetColorTexture(1, 1, 1, 0.1)
            surface.body = { fill, hover }
            hover:Hide()
            local function ShowHover()
                hover:SetAlpha(owner:GetButtonState() == "PUSHED" and 0.5 or 1)
                hover:SetShown(active and owner:IsEnabled() and owner:IsMouseOver())
            end
            local function HideHover() hover:Hide() end
            owner:HookScript("OnEnter", ShowHover)
            owner:HookScript("OnEnable", function()
                ShowHover()
                PaintButtonBorderState(surface)
            end)
            owner:HookScript("OnMouseDown", ShowHover)
            owner:HookScript("OnMouseUp", ShowHover)
            owner:HookScript("OnLeave", HideHover)
            owner:HookScript("OnHide", HideHover)
            owner:HookScript("OnDisable", function()
                HideHover()
                PaintButtonBorderState(surface)
            end)
        end
        return surface
    end

    local function SetButtonFonts(surface, button, label, fontName)
        local states = { "Normal", "Highlight", "Disabled" }
        local stockFonts, skinFonts = {}, {}
        for _, state in ipairs(states) do
            local original = button["Get" .. state .. "FontObject"](button)
            if not original then return end
            stockFonts[state] = original
        end
        local _, size = label:GetFont()
        size = size or 12
        surface.font = function()
            local theme = WSkin.Theme
            local family = active and EllesmereUI.GetFontFamily(theme.fontPath, size, theme.fontFlag, theme.fontShadow)
            for _, state in ipairs(states) do
                local font = stockFonts[state]
                if active then
                    if not skinFonts[state] then
                        skinFonts[state] = CreateFont(fontName .. "Ellesmere" .. state .. "Font")
                    end
                    font = skinFonts[state]
                    if family then
                        font:SetFontObject(family)
                    else
                        EllesmereUI.PrimeFontShadow(font, theme.fontShadow)
                        font:SetFont(theme.fontPath, size, theme.fontFlag or "")
                    end
                    if state ~= "Disabled" then
                        font:SetTextColor(1, 1, 1)
                    else
                        font:SetTextColor(stockFonts[state]:GetTextColor())
                    end
                end
                button["Set" .. state .. "FontObject"](button, font)
            end
            -- Setters install the fonts for future state changes; refresh today's label too.
            local state = not button:IsEnabled() and "Disabled" or button:IsMouseOver() and "Highlight" or "Normal"
            label:SetFontObject((active and skinFonts or stockFonts)[state])
        end
        return true
    end

    local function Font(surface, label, button, tint)
        if not label then return end
        if button then
            local box = popup and popup.BorderBox
            local fontName
            if button == pane.EquipSet or button == pane.SaveSet then
                fontName = button:GetName()
            elseif box and button == box.OkayButton then
                fontName = "EUIForeverPickerOkay"
            elseif box and button == box.CancelButton then
                fontName = "EUIForeverPickerCancel"
            end
            if fontName and SetButtonFonts(surface, button, label, fontName) then return end
        end
        local original = label:GetFontObject()
        local r, g, b, a
        if tint then r, g, b, a = label:GetTextColor() end
        local stateFonts = button and button:GetFontString() == label
        local function NativeFont()
            if not stateFonts then return end
            local normal = button:GetNormalFontObject()
            if not button:IsEnabled() then return button:GetDisabledFontObject() or normal end
            if button:IsMouseOver() then return button:GetHighlightFontObject() or normal end
            return normal
        end
        local function Apply()
            if not active then return end
            local current = label:GetFontObject()
            if current and not EllesmereUI._fontFamilySet[current] then original = current end
            local native = NativeFont() or (button and original)
            WSkin.FontFamily(label)
            if tint then
                local color = tint(g)
                if color then
                    label:SetTextColor(color.r, color.g, color.b, color.a or 1)
                else
                    label:SetTextColor(r, g, b, a)
                end
            elseif button and button:IsEnabled() then
                if button == pane.NewSet then
                    local accent = EllesmereUI.ELLESMERE_GREEN
                    label:SetTextColor(accent.r, accent.g, accent.b)
                else
                    WSkin.White(label)
                end
            elseif native then
                label:SetTextColor(native:GetTextColor())
            end
        end
        if button then
            for _, event in ipairs({ "OnEnter", "OnLeave", "OnEnable", "OnDisable", "OnMouseDown", "OnMouseUp" }) do
                button:HookScript(event, Apply)
            end
        end
        surface.font = function(refreshColor)
            if tint and refreshColor then
                r, g, b, a = label:GetTextColor()
                if not active then return end
            end
            if active then
                Apply()
            else
                local native = NativeFont() or (button and original)
                if native or original then label:SetFontObject(native or original) end
                if native then label:SetTextColor(native:GetTextColor()) end
                if tint then label:SetTextColor(r, g, b, a) end
            end
        end
    end

    local function Button(owner, widthAdjustment, verticalOffset, spanEquipButtons)
        if not owner or owner:IsProtected() then return end
        SaveTextures(owner)
        SaveArt(owner.StateTexture)
        SaveArt(owner:GetNormalTexture())
        SaveArt(owner:GetPushedTexture())
        SaveArt(owner:GetDisabledTexture())
        SaveArt(owner:GetHighlightTexture())
        local surface = Box(owner, nil, true)
        local label = owner.Text or owner:GetFontString()
        if not label then
            for _, region in ipairs({ owner:GetRegions() }) do
                if region:IsObjectType("FontString") then
                    label = region
                    break
                end
            end
        end
        Font(surface, label, owner)
        if widthAdjustment or spanEquipButtons then
            surface.left, surface.right = owner, owner
            if spanEquipButtons then surface.left, surface.right = pane.EquipSet, pane.SaveSet end
            surface.host:ClearAllPoints()
            surface.host:SetPoint("TOP", owner)
            surface.host:SetPoint("BOTTOM", owner)
            local width = owner:GetWidth()
            local point, relative, relativePoint, x, y = owner:GetPoint()
            surface.layout = function()
                if spanEquipButtons then
                    owner:ClearAllPoints()
                    if active then
                        owner:SetPoint("LEFT", pane.EquipSet, "LEFT")
                        owner:SetPoint("RIGHT", pane.SaveSet, "RIGHT")
                    else
                        owner:SetWidth(width)
                    end
                else
                    owner:SetWidth(active and width - widthAdjustment or width)
                end
                if verticalOffset and point then
                    owner:SetPoint(point, relative, relativePoint, x or 0, (y or 0) + (active and verticalOffset or 0))
                end
            end
        end
        return surface
    end

    local rows = {}
    local function PaintSelection(row)
        local surface = rows[row]
        if surface then surface.selected:SetShown(active and row.SelectedBar:IsShown()) end
    end
    local function DressRow(row)
        if not active or not row.icon or row:IsProtected() then return end
        if InCombatLockdown() then
            ns.CombatQueue.Defer("ForeverEquipmentSkin", Update)
            return
        end
        local existing = rows[row]
        if existing then
            if existing.layout() or existing.pendingPaint then Paint(existing) end
            return
        end
        for _, art in ipairs({ row:GetRegions() }) do
            local atlas = art.GetAtlas and art:GetAtlas()
            if atlas == "UI-Character-Info-OutfitCard" or atlas == "UI-Character-Info-OutfitIcon-Frame" then SaveArt(art) end
        end
        SaveArt(row.SelectedBar)
        SaveArt(row.HighlightBar)
        local nativeIcon = row.icon
        SaveArt(nativeIcon)
        local surface = Box(row)
        surface.row = row
        surface.host:ClearAllPoints()
        surface.host:SetPoint("TOP", row, "TOP", 0, -4)
        surface.host:SetPoint("BOTTOM", row, "BOTTOM", 0, 4)
        surface.left, surface.right = pane.EquipSet, pane.SaveSet
        Font(surface, row.text, nil, function(g)
            -- Keep the native red warning for sets with missing items.
            if g > 0.5 then return WHITE_FONT_COLOR end
        end)

        -- The scroll box moves and replaces the native icon when it reuses a row.
        local icon = row:CreateTexture(nil, "ARTWORK", nil, -1)
        icon:SetBlockingLoadsRequested(true)
        icon:SetWidth(36)
        icon:SetPoint("TOPLEFT", surface.host)
        icon:SetPoint("BOTTOMLEFT", surface.host)
        surface.icon = icon
        local displayedTexture
        local edit, delete = row.EditButton, row.DeleteButton
        local editPoint = edit and not edit:IsProtected() and { edit:GetPoint() }
        local deletePoint = delete and not delete:IsProtected() and { delete:GetPoint() }
        local actionsSkinned
        surface.layout = function()
            icon:SetShown(active)
            local changed
            if active then
                local _, setTexture
                if row.setID then _, setTexture = C_EquipmentSet.GetEquipmentSetInfo(row.setID) end
                local texture = setTexture or nativeIcon:GetTexture() or "Interface\\Icons\\INV_Misc_QuestionMark"
                if texture ~= displayedTexture then
                    EllesmereUI.RoundAuraCorners(row, surface, icon, nil, false, 0)
                    icon:SetTexture(texture)
                    WSkin.SetIconCrop(icon, 0.08)
                    displayedTexture = texture
                    changed = true
                end
            end
            if editPoint and editPoint[1] and deletePoint and deletePoint[1] and actionsSkinned ~= active then
                edit:ClearAllPoints()
                delete:ClearAllPoints()
                if active then
                    local pixel = OnePixel(surface.host)
                    edit:SetPoint("CENTER", surface.host, "RIGHT", -13 + pixel, 7 + pixel)
                    delete:SetPoint("CENTER", surface.host, "RIGHT", -13 + pixel, -9 + pixel)
                else
                    delete:SetPoint(unpack(deletePoint, 1, 5))
                    edit:SetPoint(unpack(editPoint, 1, 5))
                end
                actionsSkinned = active
            end
            return changed
        end
        local join = CreateFrame("Frame", nil, surface.host)
        join:SetPoint("TOP", surface.host)
        join:SetPoint("BOTTOM", surface.host)
        join:SetPoint("LEFT", icon, "RIGHT")
        join:SetWidth(1)
        surface.separator = { anchor = join, texture = join:CreateTexture(nil, "OVERLAY") }
        local selected = row:CreateTexture(nil, "BACKGROUND")
        selected:SetPoint("TOPLEFT", join)
        selected:SetPoint("BOTTOMRIGHT", surface.host)
        selected:SetColorTexture(0.27, 0.86, 0.49, 0.13)
        surface.selected = selected
        rows[row] = surface
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(selected)
        hover:SetColorTexture(1, 1, 1, 0.08)
        surface.body = { surface.fill, selected, hover }
        extras[#extras + 1] = hover
        local hoverScroll = GetFFD(pane).statsHover
        if hoverScroll then
            row:HookScript("OnEnter", hoverScroll)
            row:HookScript("OnLeave", hoverScroll)
        end
        surface.layout()
        if surface.font then surface.font() end
        PaintSelection(row)
        Paint(surface)
    end
    local RefreshRows = WSkin.Debounce(function()
        if active and pane:IsVisible() then pane.ScrollBox:ForEachFrame(DressRow) end
    end)

    local function BuildPane()
        paneBuilt = true
        SaveArt(pane.Border)
        setScroll = SkinSheetScroll(pane, WSkin, SaveTextures)
        local bar = pane.ScrollBar
        SaveArt(bar and bar.Back and bar.Back.Texture)
        SaveArt(bar and bar.Forward and bar.Forward.Texture)
        local drop = 3
        Button(pane.EquipSet, 9, -drop)
        Button(pane.SaveSet, 9, -drop)
        local button = pane.NewSet
        -- The 44px list rows have a 2px gap and 4px insets on each end.
        local newSet = Button(button, nil, 8 - drop, true)
        if newSet then
            local plus = {}
            for i = 1, 2 do
                local line = button:CreateTexture(nil, "ARTWORK")
                line:SetColorTexture(1, 1, 1, 0.85)
                line:SetPoint("CENTER", button, "LEFT", 20, 0)
                line:SetSize(i == 1 and 10 or 2, i == 1 and 2 or 10)
                plus[i] = line
                extras[#extras + 1] = line
            end
            for _, art in ipairs({ pane:GetRegions() }) do
                if art.GetAtlas and art:GetAtlas() == "UI-Character-Info-ScrollLine" then SaveArt(art) end
            end
            local glow = {}
            local pixel = OnePixel(pane)
            for i = 1, 2 do
                local left = pane:CreateTexture(nil, "ARTWORK")
                local right = pane:CreateTexture(nil, "ARTWORK")
                left:SetPoint("LEFT", button, "TOPLEFT", 0, 12)
                left:SetPoint("RIGHT", button, "TOP", 0, 12)
                right:SetPoint("LEFT", button, "TOP", 0, 12)
                right:SetPoint("RIGHT", button, "TOPRIGHT", 0, 12)
                for _, line in ipairs({ left, right }) do
                    line:SetHeight((i == 1 and 3 or 1) * pixel)
                    line:SetColorTexture(1, 1, 1, 1)
                    extras[#extras + 1] = line
                end
                glow[i] = { left, right }
            end
            local function TintNewSet()
                local accent = EllesmereUI.ELLESMERE_GREEN
                for _, line in ipairs(plus) do line:SetVertexColor(accent.r, accent.g, accent.b) end
                local clear = CreateColor(accent.r, accent.g, accent.b, 0)
                for i, pair in ipairs(glow) do
                    local center = CreateColor(accent.r, accent.g, accent.b, i == 1 and 0.10 or 0.60)
                    pair[1]:SetGradient("HORIZONTAL", clear, center)
                    pair[2]:SetGradient("HORIZONTAL", center, clear)
                end
                if active and newSet.font then newSet.font() end
            end
            TintNewSet()
            EllesmereUI.RegAccent({ type = "callback", fn = TintNewSet })
        end
        -- Dress recycled rows after Blizzard finishes laying out the set list.
        if pane.ScrollBox then pane.ScrollBox:RegisterCallback(BaseScrollBoxEvents.OnLayout, RefreshRows, rows) end
        hooksecurefunc("PaperDollEquipmentManagerPane_SetButtonSelected", function(row)
            if active then PaintSelection(row) end
        end)
        hooksecurefunc("PaperDollEquipmentManagerPane_InitButton", function(row)
            local surface = rows[row]
            if surface and surface.font then surface.font(true) end
        end)
    end

    local function BuildPopup()
        popupBuilt = true
        local box = popup.BorderBox
        if not box then return end
        local okay, cancel = box.OkayButton, box.CancelButton
        local footerGap = 16
        if sheet then
            popup:ClearAllPoints()
            popup:SetPoint("TOPLEFT", sheet, "TOPRIGHT")
            popup:SetPoint("BOTTOMLEFT", sheet, "BOTTOMRIGHT")
        end
        SaveTextures(popup)
        WSkin.Shell("charsheet", popup, { noBorder = true, noTopBar = true })
        pickerShell = WSkin.GetFFD(popup)
        SaveTextures(box)
        local edit = box.IconSelectorEditBox
        local dropdown = box.IconTypeDropdown or box.IconFilterDropdown
        if edit and not edit:IsProtected() then
            SaveTextures(edit)
            local surface = Box(edit)
            surface.font = function() if active then WSkin.Font(edit) end end
        end
        local icons = {}
        local function DressIcon(button)
            local icon = button.Icon
            if not icon or button:IsProtected() then return end
            local surface = icons[button]
            if not surface then
                SaveTextures(button, icon)
                surface = Box(button, icon)
                surface.square = true
                local hover, flash = BuildSlotHover(button, icon)
                local selected = button:CreateTexture(nil, "OVERLAY")
                selected:SetAllPoints(icon)
                selected:SetTexture(ACTION_BAR_MEDIA .. "highlight-3.png")
                selected:SetBlendMode("ADD")
                selected:SetVertexColor(GLOW_GOLD.r, GLOW_GOLD.g, GLOW_GOLD.b)
                local function UpdateSelection()
                    local on = active and button.SelectedTexture and button.SelectedTexture:IsShown()
                    selected:SetShown(on or false)
                    hover:SetShown(active)
                    hover:SetAlpha(on and 0 or 1)
                    if not active then flash:Hide() end
                    local tint = on and GLOW_GOLD or nil
                    if surface.borderTint ~= tint then
                        surface.borderTint = tint
                        if active then Paint(surface) end
                    end
                end
                surface.layout = UpdateSelection
                if button.UpdateSelectedTexture then hooksecurefunc(button, "UpdateSelectedTexture", UpdateSelection) end
                icons[button] = surface
                Paint(surface)
            end
            surface.layout()
            -- Retain the center half of each icon.
            if math.abs(icon:GetTexCoord() - 0.25) > 0.0001 then WSkin.SetIconCrop(icon, 0.25) end
        end
        local area, grid = box.SelectedIconArea, popup.IconSelector
        local preview = area and area.SelectedIconButton
        local selectedText = area and area.SelectedIconText
        local description = selectedText and selectedText.SelectedIconDescription
        local function PickerLabel(label, tint)
            if not label then return end
            local surface = {}
            Font(surface, label, nil, tint)
            pickerFonts[#pickerFonts + 1] = surface.font
            return surface.font
        end
        local function MutedText() return EllesmereUI.TEXT_DIM end
        PickerLabel(box.EditBoxHeaderText, MutedText)
        PickerLabel(box.IconSelectionText, MutedText)
        local descriptionFont = PickerLabel(description, MutedText)
        local headerFont = PickerLabel(selectedText and selectedText.SelectedIconHeader, function()
            return EllesmereUI.ELLESMERE_GREEN
        end)
        if headerFont then
            EllesmereUI.RegAccent({ type = "callback", fn = function() if active then headerFont() end end })
        end
        if grid and grid.ScrollBox and grid.ScrollBar then
            setPickerScroll = SkinSheetScroll(grid, WSkin, SaveTextures, true)
            local bar = grid.ScrollBar
            SaveArt(bar.Back and bar.Back.Texture)
            SaveArt(bar.Forward and bar.Forward.Texture)
            local gridInset = 21
            grid:ClearAllPoints()
            grid:SetPoint("TOPLEFT", popup, "TOPLEFT", gridInset, -97)
            grid:SetPoint("RIGHT", popup, "RIGHT", -10, 0)
            grid:SetPoint("BOTTOM", cancel, "TOP", 0, footerGap)
            local _, _, padding, _, columnGap = grid:GetPadding()
            local columns = grid:GetStride()
            local left = gridInset + padding
            local right = left + columns * grid:GetButtonWidth() + (columns - 1) * columnGap
            if edit and not edit:IsProtected() then
                local _, _, _, _, y = edit:GetPoint()
                edit:SetPoint("TOPLEFT", box, "TOPLEFT", left, y or 0)
            end
            if dropdown and not dropdown:IsProtected() then
                local _, _, _, _, y = dropdown:GetPoint()
                dropdown:SetPoint("TOPRIGHT", box, "TOPLEFT", right, y or 0)
            end
        end
        refreshPickerIcons = WSkin.Debounce(function()
            if not (active and popup:IsVisible()) then return end
            if descriptionFont and not EllesmereUI._fontFamilySet[description:GetFontObject()] then descriptionFont() end
            if preview then DressIcon(preview) end
            if grid and grid.ScrollBox then grid.ScrollBox:ForEachFrame(DressIcon) end
        end)
        if grid and grid.ScrollBox then hooksecurefunc(grid.ScrollBox, "Update", refreshPickerIcons) end
        if preview and preview.SetIconTexture then hooksecurefunc(preview, "SetIconTexture", refreshPickerIcons) end

        if dropdown then paintPickerDropdown = SkinPickerDropdown(dropdown, WSkin) end
        local dragContent = box.IconDragArea and box.IconDragArea.IconDragAreaContent
        PickerLabel(dragContent and dragContent.IconDragText)
        PickerLabel(dropdown and (dropdown.Text or dropdown:GetFontString()))
        if Button(okay) and Button(cancel) then
            cancel:ClearAllPoints()
            cancel:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -footerGap, footerGap)
            okay:ClearAllPoints()
            okay:SetPoint("RIGHT", cancel, "LEFT", -12, 0)
        end
    end

    Update = function()
        if InCombatLockdown() then
            ns.CombatQueue.Defer("ForeverEquipmentSkin", Update)
            return
        end
        local style = EllesmereUIDB and EllesmereUIDB.blizzWinBorderTexture
        local enabled = not style or WSkin.IsModeTabBorderStyle(style)
        if not enabled and active == enabled then return end
        if active ~= enabled then
            active = enabled
            for art, alpha in pairs(stock) do art:SetAlpha(active and 0 or alpha) end
        end
        if active then
            if not setFlyout then setFlyout = HookEquipmentFlyout(pane, WSkin) end
            if not paneBuilt and pane:IsVisible() then BuildPane() end
            if not popupBuilt and popup and popup:IsVisible() and not popup:IsProtected() then BuildPopup() end
            if paneBuilt and pane.ScrollBox and pane:IsVisible() then RefreshRows() end
        end
        if setScroll then setScroll(active) end
        if pickerShell then
            pickerShell.bg:SetShown(active)
            pickerShell.bgOverlay:SetShown(active)
            pickerShell.modernBg:SetShown(active)
        end
        if setPickerScroll then setPickerScroll(active) end
        if paintPickerDropdown and active and popup:IsVisible() then paintPickerDropdown() end
        if refreshPickerIcons and popup:IsVisible() then refreshPickerIcons() end
        if setFlyout then setFlyout(active) end
        for _, extra in ipairs(extras) do extra:SetShown(active) end
        for _, font in ipairs(pickerFonts) do font() end
        for row in pairs(rows) do PaintSelection(row) end
        for _, surface in ipairs(surfaces) do
            if surface.layout then surface.layout() end
            if surface.font then surface.font() end
            Paint(surface)
        end
    end
    pane:HookScript("OnShow", Update)
    if popup then
        local function OpenPopup()
            if not popup:IsVisible() then return end
            Update()
            if sheet and active and popupBuilt then WSkin.SetWindowBorderDock(sheet, popup) end
        end
        popup:HookScript("OnShow", function()
            if InCombatLockdown() then
                ns.CombatQueue.Defer("ForeverEquipmentPicker", OpenPopup)
            else
                OpenPopup()
            end
        end)
        popup:HookScript("OnHide", function()
            if sheet and popupBuilt then WSkin.SetWindowBorderDock(sheet) end
        end)
    end
    return Update
end

--------------------------------------------------------------------------------
--  The overall item level at the top of the stats sidebar, as on retail: the
--  equipped average on a line of its own above the player's stats list. A
--  child of that list, so it shows only with it (never over the equipment
--  manager, the titles or the pet stats), and the list's rows start under it
--  while it shows. Its two events are registered only while the sheet is
--  shown; nothing is built when the client has no average item level.
--------------------------------------------------------------------------------
local AVG_H = 24               -- the line's room above the rows
local avg                      -- { host, text, events, shown }

local function UpdateAverage()
    local a = avg
    local _, equipped = _G.GetAverageItemLevel()
    local shown = type(equipped) == "number"
        and not (issecretvalue and issecretvalue(equipped)) and equipped > 0
    if shown then a.text:SetFormattedText("%.2f", equipped) end
    if a.shown ~= shown then
        a.shown = shown
        a.host:SetShown(shown)
        -- The rows make room for the line, and take it back with no level to show.
        local box = a.host:GetParent()
        box.ScrollBox:SetPoint("TOPLEFT", box, "TOPLEFT", LIST_INSET, shown and (LIST_Y - AVG_H) or LIST_Y)
    end
end

local function WatchAverage()
    local a = avg
    if _G.CharacterFrame:IsShown() then
        a.events:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
        a.events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        UpdateAverage()
    else
        a.events:UnregisterAllEvents()
    end
end

local function BuildAverage(frame)
    local box = _G.CharacterStatsPaneScrollBox
    if avg or not (box and box.ScrollBox and _G.GetAverageItemLevel) then return end
    local host = CreateFrame("Frame", nil, box)
    host:SetPoint("TOPLEFT", box, "TOPLEFT", LIST_INSET, LIST_Y + 2)
    host:SetPoint("TOPRIGHT", box, "TOPRIGHT", -LIST_INSET, LIST_Y + 2)
    host:SetHeight(AVG_H)
    host:Hide()
    local text = host:CreateFontString(nil, "OVERLAY")
    EllesmereUI.ApplyModuleFont(text, nil, 18, "blizzardSkin")
    text:SetPoint("CENTER", host, "CENTER", 0, 0)
    text:SetTextColor(0.6, 0.2, 1, 1)  -- the retail sheet's and the inspect sheet's
    host:EnableMouse(true)
    host:SetScript("OnEnter", function(self) EllesmereUI.ShowWidgetTooltip(self, "Equipped Item Level") end)
    host:SetScript("OnLeave", function() EllesmereUI.HideWidgetTooltip() end)
    local hover = GetFFD(box).statsHover
    if hover then
        host:HookScript("OnEnter", hover)
        host:HookScript("OnLeave", hover)
    end
    local events = CreateFrame("Frame")
    events:SetScript("OnEvent", UpdateAverage)
    avg = { host = host, text = text, events = events, shown = false }
    frame:HookScript("OnShow", WatchAverage)
    frame:HookScript("OnHide", WatchAverage)
    WatchAverage()
end

local function SkinFrame()
    local frame = _G.CharacterFrame
    local WSkin = ns.WSkin
    if not (frame and WSkin and WSkin.Shell) then return false end
    local Fade = WSkin.FadeRegions
    if not Fade then return false end
    local d = GetFFD(frame)
    if d.done or not Enabled() then return true end
    if InCombatLockdown() then
        ns.CombatQueue.Defer("ForeverSheetBuild", SkinFrame)
        return true
    end
    d.done = true

    -- The ordinary window treatment: shell, border, top bar, house close
    -- button, title centred on the bar. explicitControls keeps the engine
    -- away from the stats scrollbar, which stays Blizzard's.
    WSkin.Shell("charsheet", frame)
    if WSkin.CommonChrome then WSkin.CommonChrome(frame, "CharacterFrame", true) end
    if WSkin.RemovePortrait then WSkin.RemovePortrait(frame) end

    SkinPaneToggle(frame, WSkin)

    local shell = WSkin.GetFFD and WSkin.GetFFD(frame)
    local topBar = shell and shell.topBar
    local title = (frame.TitleContainer and frame.TitleContainer.TitleText) or _G.CharacterFrameTitleText
    local titleSize = ns.ForeverTitleSize()
    if title then
        WSkin.Font(title, 1, 1, 1, titleSize)
        local _, class = UnitClass("player")
        local function UpdateTitle()
            local isCharacter = frame.activeSubframe == "PaperDollFrame"
            if topBar then
                title:ClearAllPoints()
                title:SetPoint("CENTER", topBar)
            end
            if not isCharacter then return end
            local color = EllesmereUI.GetRawClassColor(class)
            if color then title:SetTextColor(color.r, color.g, color.b) end
        end
        hooksecurefunc(frame, "UpdateTitle", UpdateTitle)
        UpdateTitle()
    end

    -- Pane backdrops, the stone header, the divider strip, the stats box
    -- chrome (inside frame, scroll line, class crest) and the model backdrop.
    Fade(frame.LeftPaneHost)
    Fade(frame.RightPaneHost)
    FadeChildren(frame.RightPaneHost, function(child)
        -- The stats and pet lists are children too; their chrome goes, their
        -- rows and scrollbars are handled by the element callback and kept.
        if child ~= _G.CharacterStatsPaneScrollBox and child ~= _G.CharacterStatsPanePetScrollBox then
            Fade(child)
        end
    end)
    if frame.RightPaneHost and frame.RightPaneHost.StoneBg then frame.RightPaneHost.StoneBg:SetAlpha(0) end
    Fade(_G.CharacterStatsPaneScrollBox)
    Fade(_G.CharacterStatsPanePetScrollBox)
    Fade(_G.PaperDollFrame)
    Fade(_G.PaperDollFrame.TopBackgroundStripHost)
    Fade(_G.CharacterModelScene)
    ns.ForeverHideSceneArt(_G.CharacterModelScene)
    local close = frame.CloseButton
    ns.ForeverSkinClose(close, topBar)
    local modelBg = ns.ForeverModelBackdrop(frame, topBar, _G.PaperDollFrame, frame.LeftPaneHost)
    local sidebarBg = SidebarPanel(frame, topBar)
    local dividers = ns.ForeverBuildDividers(frame, topBar, modelBg, sidebarBg)
    local equipment = HookEquipmentSkin(WSkin, frame)
    WSkin.SetWindowBorderDetails(frame, modelBg, sidebarBg, function(...)
        if dividers then dividers(...) end
        if equipment then equipment() end
    end, true)
    SkinPaperDollHeader(WSkin, modelBg, sidebarBg, titleSize - 2)

    -- Item slots: frames off, icons cropped, a grey square and a quality
    -- border on each, and the slot text beside them; both follow Blizzard's
    -- own slot refresh.
    LayoutGearSlots(frame, false)
    for i = 1, #SLOTS do SkinSlot(SLOTS[i], Fade) end
    BuildSlotText()
    local eyeBtn
    if topBar and slotOverlay then
        eyeBtn = ns.ForeverBuildItemTextEye(slotOverlay:GetParent(), topBar, slotOverlay, ilvlOverlay,
            "foreverItemTextHidden")
    end
    local scene = _G.CharacterModelScene
    local cameraButtons = scene and SkinModelControls(scene, eyeBtn, WSkin)
    if eyeBtn and topBar then
        -- The native camera layout must never loop over its own anchor (the eye).
        ns.ForeverSkinHeaderHover(frame, topBar, { eyeBtn, unpack(cameraButtons or {}) }, close)
    end
    HookSlotUpdates()

    SkinStatsScroll(_G.CharacterStatsPaneScrollBox, WSkin)
    SkinStatsScroll(_G.CharacterStatsPanePetScrollBox, WSkin)
    HookStatsList(_G.CharacterStatsPaneScrollBox)
    HookStatsList(_G.CharacterStatsPanePetScrollBox)
    BuildAverage(frame)
    return true
end

-- Blizz Default: the slot text alone, built at the slots' first show;
-- every later show returns at once.
local function BuildStockText()
    if itemWatch then return end
    BuildSlotText()
    HookSlotUpdates()
end

-- Show Item Durability: the weakest item's percent above the model, both
-- looks. Events only while the option is on and the sheet is shown.
local durEvents, durLabel
local function UpdateDurability()
    local on = EllesmereUIDB and EllesmereUIDB.showCharSheetDurability and TextEnabled()
    local frame = _G.CharacterFrame
    if on and frame and frame:IsShown() then
        if not durEvents then
            durEvents = CreateFrame("Frame")
            durEvents:SetScript("OnEvent", UpdateDurability)
        end
        durEvents:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
        durEvents:RegisterEvent("UPDATE_INVENTORY_ALERTS")
    elseif durEvents then
        durEvents:UnregisterEvent("UPDATE_INVENTORY_DURABILITY")
        durEvents:UnregisterEvent("UPDATE_INVENTORY_ALERTS")
    end
    if not on then
        if durLabel then durLabel:Hide() end
        return
    end
    if not durLabel then
        local scene, doll = _G.CharacterModelScene, _G.PaperDollFrame
        if not (scene and doll) then return end
        -- On the paper doll so it goes with that tab, above the model.
        local host = CreateFrame("Frame", nil, doll)
        host:SetAllPoints(scene)
        host:SetFrameLevel(scene:GetFrameLevel() + 10)
        durLabel = host:CreateFontString(nil, "OVERLAY")
        EllesmereUI.ApplyModuleFont(durLabel, nil, 12, "blizzardSkin")
        -- Under the model's zoom/rotate controls.
        local ctrl = scene.ControlFrame
        if ctrl and GetFFD(ctrl).moved and doll.TopBackgroundStripHost then
            durLabel:SetPoint("TOP", doll.TopBackgroundStripHost, "TOP", 0, -76)
        elseif ctrl then
            durLabel:SetPoint("TOP", ctrl, "BOTTOM", 0, -4)
        else
            durLabel:SetPoint("TOP", scene, "TOP", 0, -8)
        end
    end
    local pct = ns.GetDurabilityPercent()
    local showLabel = EllesmereUIDB.charSheetDurabilityShowLabel ~= false
    durLabel:SetText(ns.FormatDurabilityText(pct, showLabel))
    local r, g, b = ns.GetDurabilityTextColor(pct)
    durLabel:SetTextColor(r, g, b, 1)
    durLabel:Show()
end
EllesmereUI._updateCharSheetDurability = UpdateDurability

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not _G.CharacterFrame then return end
    if TextEnabled() then
        _G.CharacterFrame:HookScript("OnShow", UpdateDurability)
        _G.CharacterFrame:HookScript("OnHide", UpdateDurability)
    end
    if Enabled() then
        if not SkinFrame() then
            -- The engine loads after this addon's own files; one retry on the
            -- first open covers a late shell.
            _G.CharacterFrame:HookScript("OnShow", function() SkinFrame() end)
        end
    elseif TextEnabled() and _G.PaperDollItemsFrame then
        _G.PaperDollItemsFrame:HookScript("OnShow", BuildStockText)
    end
end)
