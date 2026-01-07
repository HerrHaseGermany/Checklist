-- Checklist.lua
-- Addon core: SavedVariables, event triggers, and public helpers used by UI/options.

local ADDON_NAME = ...
local ADDON_VERSION = "0.1.0"

function Checklist_GetVersion()
  return ADDON_VERSION
end

-- Open the addon options panel, optionally focusing a specific list in the UI.
function Checklist_OpenOptions(listId)
  if not ChecklistDB then ChecklistDB = {} end
  if listId then
    ChecklistDB.openListId = listId
  end
  -- Ensure the options window isn't obscured by the checklist popup.
  if _G and _G.ChecklistFrame and _G.ChecklistFrame.IsShown and _G.ChecklistFrame:IsShown() then
    _G.ChecklistFrame:Hide()
  end
  if SlashCmdList and SlashCmdList.CHECKLISTOPTIONS then
    SlashCmdList.CHECKLISTOPTIONS()
    return
  end
  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory("Checklist")
    InterfaceOptionsFrame_OpenToCategory("Checklist")
  end
end

-- Account-wide SavedVariables
ChecklistDB = ChecklistDB or {}
-- Per-character legacy SavedVariables (only used for one-time migration)
ChecklistCharDB = ChecklistCharDB or nil

local DEFAULTS = {
  enabled = true,
  minimap = {
    hide = false,
    angle = 225,
  },
  lists = nil,
  triggerList = nil,
  listDisabled = nil,
  defaultListId = nil,
  migratedFromChar = false,
  checked = {},
  lastLogoutAt = nil,
}

-- Deep-merge DEFAULTS into a SavedVariables table without overwriting user values.
local function copyDefaults(dst, src)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = copyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

local function shallowCopyTable(src)
  if type(src) ~= "table" then return nil end
  local dst = {}
  for k, v in pairs(src) do
    dst[k] = v
  end
  return dst
end

-- One-time migration from per-character DB into the account-wide DB.
local function migrateFromCharacterDB()
  if ChecklistDB.migratedFromChar then return end
  if type(ChecklistCharDB) ~= "table" then
    ChecklistDB.migratedFromChar = true
    return
  end

  -- Only migrate if the account-wide DB looks "new" (no lists yet).
  local hasLists = type(ChecklistDB.lists) == "table" and next(ChecklistDB.lists) ~= nil
  if not hasLists then
    ChecklistDB.enabled = (ChecklistCharDB.enabled ~= false)
    ChecklistDB.minimap = shallowCopyTable(ChecklistCharDB.minimap) or ChecklistDB.minimap
    ChecklistDB.lists = shallowCopyTable(ChecklistCharDB.lists) or ChecklistDB.lists
    ChecklistDB.triggerList = shallowCopyTable(ChecklistCharDB.triggerList) or ChecklistDB.triggerList
    ChecklistDB.listDisabled = shallowCopyTable(ChecklistCharDB.listDisabled) or ChecklistDB.listDisabled
    ChecklistDB.defaultListId = ChecklistCharDB.defaultListId or ChecklistDB.defaultListId
    ChecklistDB.checked = shallowCopyTable(ChecklistCharDB.checked) or ChecklistDB.checked
  end

  ChecklistDB.migratedFromChar = true
  -- Stop persisting the per-character DB going forward.
  ChecklistCharDB = nil
end

local function now()
  return time()
end

local function newId()
  return tostring(now()) .. tostring(math.random(1000, 9999))
end

local function ensureLists()
  if type(ChecklistDB.lists) ~= "table" then
    ChecklistDB.lists = {}
  end
  if type(ChecklistDB.triggerList) ~= "table" then
    ChecklistDB.triggerList = {}
  end
  if type(ChecklistDB.listDisabled) ~= "table" then
    ChecklistDB.listDisabled = {}
  end
  -- Back-compat: older builds used listEnabled (true/false). Convert once.
  if type(ChecklistDB.listEnabled) == "table" then
    for listId, isEnabled in pairs(ChecklistDB.listEnabled) do
      if isEnabled == false then
        ChecklistDB.listDisabled[listId] = true
      end
    end
    ChecklistDB.listEnabled = nil
  end
end

local function ensureDefaultLists()
  ensureLists()
  local existingId = next(ChecklistDB.lists)
  local defaultId = existingId
  if not defaultId then
    defaultId = newId()
    ChecklistDB.lists[defaultId] = { name = "Default", items = {} }
  end

  -- Manual checklist always uses the default list.
  ChecklistDB.defaultListId = ChecklistDB.defaultListId or defaultId
  if ChecklistDB.listDisabled[defaultId] == nil then
    ChecklistDB.listDisabled[defaultId] = false
  end
end

local function migrateOldItems()
  if type(ChecklistDB.items) ~= "table" then return end
  ensureDefaultLists()
  for trigger, items in pairs(ChecklistDB.items) do
    if type(items) == "table" and trigger ~= "afterLogout" then
      local id = ChecklistDB.triggerList[trigger]
      if not (id and ChecklistDB.lists[id]) then
        id = newId()
        ChecklistDB.lists[id] = { name = trigger, items = {} }
        ChecklistDB.triggerList[trigger] = id
      end
      ChecklistDB.lists[id].items = items
    end
  end
  ChecklistDB.items = nil
end

function Checklist_CreateList(name)
  if not ChecklistDB then return nil end
  ensureLists()
  name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then name = "New List" end
  local id = newId()
  ChecklistDB.lists[id] = { name = name, items = {} }
  ChecklistDB.listDisabled[id] = false
  return id
end

function Checklist_GetItemsForTrigger(trigger)
  if not ChecklistDB then return nil end
  ensureLists()
  local id
  if trigger == "manual" then
    id = ChecklistDB.defaultListId
  else
    id = ChecklistDB.triggerList and ChecklistDB.triggerList[trigger]
  end
  if id and ChecklistDB.lists and ChecklistDB.lists[id] and type(ChecklistDB.lists[id].items) == "table" then
    return ChecklistDB.lists[id].items
  end
  return nil
end

function Checklist_HasListForTrigger(trigger)
  if not ChecklistDB then return false end
  ensureLists()
  if trigger == "afterLogout" then return false end
  if trigger == "manual" then return false end
  local id = ChecklistDB.triggerList and ChecklistDB.triggerList[trigger]
  if not (id and ChecklistDB.lists and ChecklistDB.lists[id]) then return false end
  if ChecklistDB.listDisabled and ChecklistDB.listDisabled[id] == true then return false end
  local items = ChecklistDB.lists[id].items
  if type(items) ~= "table" or #items == 0 then return false end
  return true
end

function Checklist_GetListNameForTrigger(trigger)
  if not ChecklistDB then return nil end
  ensureLists()
  local id
  if trigger == "manual" then
    id = ChecklistDB.defaultListId
  else
    id = ChecklistDB.triggerList and ChecklistDB.triggerList[trigger]
  end
  local list = id and ChecklistDB.lists and ChecklistDB.lists[id]
  if list and type(list.name) == "string" and list.name ~= "" then
    return list.name
  end
  return nil
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("PLAYER_LOGOUT")

-- Event wiring: determines when to show the checklist popup.
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON_NAME then return end
    ChecklistDB = copyDefaults(ChecklistDB, DEFAULTS)
    migrateFromCharacterDB()
    ensureDefaultLists()
    migrateOldItems()
    return
  end

  if not ChecklistDB.enabled then return end

  if event == "PLAYER_LOGIN" then
    if Checklist_HasListForTrigger("login") then
      Checklist_ShowChecklist("login")
    end
    return
  end

  if event == "PLAYER_DEAD" then
    if Checklist_HasListForTrigger("death") then
      Checklist_ShowChecklist("death")
    end
    return
  end

  if event == "PLAYER_LOGOUT" then
    ChecklistDB.lastLogoutAt = now()
    return
  end
end)

-- Slash commands for quick access/testing.
SLASH_CHECKLIST1 = "/checklist"
SlashCmdList.CHECKLIST = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "" or msg == "show" then
    Checklist_ShowChecklist("manual")
    return
  end
  if msg == "options" or msg == "opt" then
    if SlashCmdList.CHECKLISTOPTIONS then
      SlashCmdList.CHECKLISTOPTIONS()
    end
    return
  end
  if msg == "on" then
    ChecklistDB.enabled = true
    print("Checklist: enabled")
    return
  end
  if msg == "off" then
    ChecklistDB.enabled = false
    print("Checklist: disabled")
    return
  end
  if msg == "reset" then
    ChecklistDB.checked = {}
    print("Checklist: reset checks")
    return
  end
  if msg == "minimap" then
    if Checklist_ToggleMinimapButton then
      Checklist_ToggleMinimapButton()
    end
    return
  end
  print("Checklist commands: /checklist show | options | on | off | reset | minimap")
end
