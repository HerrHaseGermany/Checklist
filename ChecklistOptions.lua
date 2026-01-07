-- ChecklistOptions.lua
-- Options UI for configuring when the popup shows and managing lists/items.

local function ensureDB()
  ChecklistDB = ChecklistDB or {}
  ChecklistDB.lists = ChecklistDB.lists or {}
  ChecklistDB.triggerList = ChecklistDB.triggerList or {}
  ChecklistDB.listDisabled = ChecklistDB.listDisabled or {}
  ChecklistDB.defaultListId = ChecklistDB.defaultListId or nil
end

local function makeId()
  return tostring(time()) .. tostring(math.random(1000, 9999))
end

local function ensureAtLeastOneList()
  ensureDB()
  if next(ChecklistDB.lists) ~= nil then return end
  local id = makeId()
  ChecklistDB.lists[id] = { name = "Default", items = {} }
  ChecklistDB.listDisabled[id] = false
  ChecklistDB.defaultListId = id
end

local function ensureDefaultListId()
  ensureDB()
  if ChecklistDB.defaultListId and ChecklistDB.lists[ChecklistDB.defaultListId] then return end
  local first = next(ChecklistDB.lists)
  if first then
    ChecklistDB.defaultListId = first
  end
end

local function listIdsSorted()
  ensureDB()
  local ids = {}
  for id, list in pairs(ChecklistDB.lists) do
    if type(list) == "table" then
      table.insert(ids, id)
    end
  end
  table.sort(ids, function(a, b)
    local an = (ChecklistDB.lists[a] and ChecklistDB.lists[a].name) or a
    local bn = (ChecklistDB.lists[b] and ChecklistDB.lists[b].name) or b
    return an < bn
  end)
  return ids
end

local function listName(id)
  ensureDB()
  local list = id and ChecklistDB.lists[id]
  return (list and list.name) or "—"
end

-- Options panel (Settings / Interface Options).
local parent = InterfaceOptionsFramePanelContainer or UIParent
local panel = CreateFrame("Frame", "ChecklistOptionsPanel", parent)
panel.name = "Checklist"
panel.__category = nil

-- Wrap all controls in a scroll container so the whole options page can scroll.
local scrollFrame = CreateFrame("ScrollFrame", "ChecklistOptionsPanelScroll", panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 0, -4)
scrollFrame:SetPoint("BOTTOMRIGHT", -28, 4)

local root = CreateFrame("Frame", nil, scrollFrame)
-- Fixed height large enough for all sections; the scrollframe handles overflow.
root:SetSize(420, 900)
scrollFrame:SetScrollChild(root)

local title = root:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Checklist")

local enabled = CreateFrame("CheckButton", nil, root, "InterfaceOptionsCheckButtonTemplate")
enabled:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
enabled.Text:SetText("Enable addon")
enabled:SetScript("OnClick", function(self)
  ensureDB()
  ChecklistDB.enabled = self:GetChecked() and true or false
end)

local minimapHide = CreateFrame("CheckButton", nil, root, "InterfaceOptionsCheckButtonTemplate")
minimapHide:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -14)
minimapHide.Text:SetText("Hide minimap button")
minimapHide:SetScript("OnClick", function(self)
  ensureDB()
  ChecklistDB.minimap = ChecklistDB.minimap or {}
  ChecklistDB.minimap.hide = self:GetChecked() and true or false
  if Checklist_MinimapButton then
    if ChecklistDB.minimap.hide then
      Checklist_MinimapButton:Hide()
    else
      Checklist_MinimapButton:Show()
    end
  end
end)

local editorTitle = root:CreateFontString(nil, "ARTWORK", "GameFontNormal")
editorTitle:SetPoint("TOPLEFT", minimapHide, "BOTTOMLEFT", 0, -16)
editorTitle:SetText("Lists:")

local listLabel = root:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
listLabel:SetPoint("TOPLEFT", editorTitle, "BOTTOMLEFT", 0, -10)
listLabel:SetText("List:")

local selectedListId = nil
local renameListId = nil

local listNameBox = CreateFrame("EditBox", nil, root, "InputBoxTemplate")
listNameBox:SetSize(220, 20)
listNameBox:SetPoint("LEFT", listLabel, "RIGHT", 8, 0)
listNameBox:SetAutoFocus(false)
listNameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

local addOrRename = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
addOrRename:SetSize(90, 22)
addOrRename:SetPoint("LEFT", listNameBox, "RIGHT", 8, 0)
addOrRename:SetText("Add")

local listsBg = CreateFrame("Frame", nil, root, "InsetFrameTemplate3")
listsBg:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -10)
-- Keep this area compact; it has its own scrollbar.
listsBg:SetSize(360, 90)

local listsScroll = CreateFrame("ScrollFrame", "ChecklistOptionsListsScroll", listsBg, "UIPanelScrollFrameTemplate")
listsScroll:SetPoint("TOPLEFT", 8, -8)
listsScroll:SetPoint("BOTTOMRIGHT", -28, 8)

local listsContent = CreateFrame("Frame", nil, listsScroll)
listsContent:SetSize(1, 1)
listsScroll:SetScrollChild(listsContent)

local listRows = {}
local function ensureRow(i)
  if listRows[i] then return listRows[i] end
  -- Each row is clickable to select a list. Edit/Remove are separate buttons.
  local row = CreateFrame("Button", nil, listsContent)
  -- UIDropDownMenuTemplate is taller than a normal row; give it enough vertical room.
  row:SetSize(320, 30)
  row:SetPoint("TOPLEFT", 0, -((i - 1) * 32))

  row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  row.name:SetPoint("LEFT", 2, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWidth(90)

  row.edit = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.edit:SetSize(48, 20)
  row.edit:SetPoint("RIGHT", -52, 0)
  row.edit:SetText("Edit")

  row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.remove:SetSize(48, 20)
  row.remove:SetPoint("RIGHT", -2, 0)
  row.remove:SetText("Remove")

  row.event = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
  -- Place the dropdown between the name and the action buttons.
  row.event:SetPoint("RIGHT", row.edit, "LEFT", -2, 0)
  row.event:SetPoint("LEFT", row.name, "RIGHT", -22, 0)
  -- UIDropDownMenuTemplate has built-in padding; scale+width keep it within the row.
  row.event:SetScale(0.72)
  UIDropDownMenu_SetWidth(row.event, 70)
  UIDropDownMenu_JustifyText(row.event, "LEFT")

  row:SetScript("OnEnter", function(self)
    if self._id and self._id ~= selectedListId then
      self.name:SetTextColor(1, 0.92, 0.4)
    end
  end)
  row:SetScript("OnLeave", function(self)
    if not self._id then return end
    if self._id == selectedListId then
      self.name:SetTextColor(1, 0.82, 0)
    else
      self.name:SetTextColor(1, 1, 1)
    end
  end)

  listRows[i] = row
  return row
end

local itemsTitle = root:CreateFontString(nil, "ARTWORK", "GameFontNormal")
itemsTitle:SetPoint("TOPLEFT", listsBg, "BOTTOMLEFT", 0, -12)
itemsTitle:SetText("Items in selected list:")

local itemEditIndex = nil

local itemBox = CreateFrame("EditBox", nil, root, "InputBoxTemplate")
itemBox:SetSize(260, 20)
itemBox:SetPoint("TOPLEFT", itemsTitle, "BOTTOMLEFT", 0, -8)
itemBox:SetAutoFocus(false)
itemBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

local addOrSaveItem = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
addOrSaveItem:SetSize(90, 22)
addOrSaveItem:SetPoint("LEFT", itemBox, "RIGHT", 8, 0)
addOrSaveItem:SetText("Add")

local noItemsText = root:CreateFontString(nil, "ARTWORK", "GameFontDisable")
noItemsText:SetPoint("TOPLEFT", itemBox, "BOTTOMLEFT", 2, -12)
noItemsText:SetText("No items yet.")

local itemsBg = CreateFrame("Frame", nil, root, "InsetFrameTemplate3")
itemsBg:SetPoint("TOPLEFT", noItemsText, "BOTTOMLEFT", -2, -8)
itemsBg:SetSize(360, 170)

local itemsScroll = CreateFrame("ScrollFrame", "ChecklistOptionsItemsScroll", itemsBg, "UIPanelScrollFrameTemplate")
itemsScroll:SetPoint("TOPLEFT", 8, -8)
itemsScroll:SetPoint("BOTTOMRIGHT", -28, 8)

local itemsContent = CreateFrame("Frame", nil, itemsScroll)
itemsContent:SetSize(1, 1)
itemsScroll:SetScrollChild(itemsContent)

local itemRows = {}
local function ensureItemRow(i)
  if itemRows[i] then return itemRows[i] end
  local row = CreateFrame("Frame", nil, itemsContent)
  row:SetSize(320, 22)
  row:SetPoint("TOPLEFT", 0, -((i - 1) * 24))

  row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  row.text:SetPoint("LEFT", 2, 0)
  row.text:SetJustifyH("LEFT")
  row.text:SetWidth(200)

  row.edit = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.edit:SetSize(50, 20)
  row.edit:SetPoint("RIGHT", -56, 0)
  row.edit:SetText("Edit")

  row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.remove:SetSize(50, 20)
  row.remove:SetPoint("RIGHT", -2, 0)
  row.remove:SetText("Remove")

  itemRows[i] = row
  return row
end

local function getSelectedList()
  ensureDB()
  if not selectedListId then return nil end
  return ChecklistDB.lists[selectedListId]
end

local function rebuildItemRows()
  local list = getSelectedList()
  local items = (list and list.items) or {}
  if #items == 0 then
    itemsBg:Hide()
    noItemsText:Show()
  else
    itemsBg:Show()
    noItemsText:Hide()
  end
  for i, text in ipairs(items) do
    local row = ensureItemRow(i)
    row.text:SetText(text)
    if itemEditIndex == i then
      row.text:SetTextColor(1, 0.82, 0)
    else
      row.text:SetTextColor(1, 1, 1)
    end
    row.edit:SetScript("OnClick", function()
      itemEditIndex = i
      itemBox:SetText(text)
      addOrSaveItem:SetText("Save")
      itemBox:SetFocus()
      rebuildItemRows()
    end)
    row.remove:SetScript("OnClick", function()
      local l = getSelectedList()
      if not l or type(l.items) ~= "table" then return end
      table.remove(l.items, i)
      if itemEditIndex == i then
        itemEditIndex = nil
        itemBox:SetText("")
        addOrSaveItem:SetText("Add")
      elseif itemEditIndex and itemEditIndex > i then
        itemEditIndex = itemEditIndex - 1
      end
      rebuildItemRows()
    end)
    row:Show()
  end
  for i = #items + 1, #itemRows do
    itemRows[i]:Hide()
  end
  itemsContent:SetHeight(math.max(1, (#items * 24) + 4))
end

local function clearItemEdit()
  itemEditIndex = nil
  itemBox:SetText("")
  addOrSaveItem:SetText("Add")
end

addOrSaveItem:SetScript("OnClick", function()
  local list = getSelectedList()
  if not list then return end
  list.items = list.items or {}
  local text = (itemBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return end

  if itemEditIndex and list.items[itemEditIndex] then
    list.items[itemEditIndex] = text
    clearItemEdit()
    rebuildItemRows()
    return
  end

  table.insert(list.items, text)
  itemBox:SetText("")
  itemBox:SetFocus()
  rebuildItemRows()
end)

itemBox:SetScript("OnEnterPressed", function()
  addOrSaveItem:Click()
end)

local TRIGGER_CHOICES = {
  { key = "login", label = "Login" },
  { key = "death", label = "Death" },
}

local function isListDisabled(listId)
  ensureDB()
  return ChecklistDB.listDisabled[listId] == true
end

local function setListDisabled(listId, disabled)
  ensureDB()
  ChecklistDB.listDisabled[listId] = disabled and true or false
end

local function clearTriggersForList(listId)
  ensureDB()
  for trigger, id in pairs(ChecklistDB.triggerList) do
    if id == listId then
      ChecklistDB.triggerList[trigger] = nil
    end
  end
end

local function listHasAnyTriggers(listId)
  ensureDB()
  for _, t in ipairs(TRIGGER_CHOICES) do
    if ChecklistDB.triggerList[t.key] == listId then
      return true
    end
  end
  return false
end

local function listTriggerSummary(listId)
  ensureDB()
  if isListDisabled(listId) or not listHasAnyTriggers(listId) then return "None" end
  local found = {}
  for _, t in ipairs(TRIGGER_CHOICES) do
    if ChecklistDB.triggerList[t.key] == listId then
      table.insert(found, t.label)
    end
  end
  if #found == 0 then return "None" end
  if #found == 1 then return found[1] end
  return "Multiple"
end

-- When using keepShownOnClick, Classic's dropdown does not automatically recompute
-- checkmarks/colors from closures. Refresh visible buttons in-place.
local function refreshOpenDropdownVisuals(dd, listId)
  local listFrame = _G and _G.DropDownList1
  if not listFrame or not listFrame:IsShown() then return end
  if listFrame.dropdown ~= dd then return end

  local disabled = isListDisabled(listId)
  local hasAny = listHasAnyTriggers(listId)

  local function setButtonTextColor(button, r, g, b)
    local fs = button.GetFontString and button:GetFontString() or nil
    if not fs then fs = button.NormalText end
    if not fs and button.GetName then
      fs = _G[button:GetName() .. "NormalText"]
    end
    if fs and fs.SetTextColor then
      fs:SetTextColor(r, g, b)
    end
  end

  local function setButtonChecked(button, checked)
    if button.SetChecked then
      button:SetChecked(checked)
      return
    end
    if button.invisibleButton and button.invisibleButton.SetChecked then
      button.invisibleButton:SetChecked(checked)
      return
    end
    if button.Check then
      button.Check:SetShown(checked)
      button.checked = checked and true or false
    end
  end

  for i = 1, (listFrame.numButtons or 0) do
    local button = _G["DropDownList1Button" .. i]
    if button and button:IsShown() then
      local text = button:GetText()
      if text == "None" then
        local checked = disabled or (not hasAny)
        setButtonChecked(button, checked)
        if disabled then
          setButtonTextColor(button, 0.55, 0.55, 0.55)
        else
          setButtonTextColor(button, 1, 1, 1)
        end
      else
        for _, t in ipairs(TRIGGER_CHOICES) do
          if text == t.label then
            setButtonChecked(button, ChecklistDB.triggerList[t.key] == listId)
            if disabled then
              setButtonTextColor(button, 0.55, 0.55, 0.55)
            else
              setButtonTextColor(button, 1, 1, 1)
            end
            break
          end
        end
      end
    end
  end
end

local function initListEventDropdown(dd, listId)
  UIDropDownMenu_Initialize(dd, function(self, level)
    local disabled = isListDisabled(listId)
    local hasAny = listHasAnyTriggers(listId)

    UIDropDownMenu_AddButton({
      text = "None",
      checked = disabled or (not hasAny),
      func = function()
        -- Toggle "None" without wiping selected triggers.
        setListDisabled(listId, not isListDisabled(listId))
        UIDropDownMenu_SetText(dd, listTriggerSummary(listId))
        refreshOpenDropdownVisuals(dd, listId)
      end,
      isNotRadio = true,
      keepShownOnClick = true,
    }, level)

    UIDropDownMenu_AddSeparator(level)

    for _, t in ipairs(TRIGGER_CHOICES) do
      UIDropDownMenu_AddButton({
        text = t.label,
        checked = (ChecklistDB.triggerList[t.key] == listId),
        colorCode = disabled and "|cff888888" or nil,
        func = function()
          ensureDB()
          -- Any explicit selection enables the list again.
          setListDisabled(listId, false)
          -- Toggle this trigger to point at this list (only one list per trigger).
          if ChecklistDB.triggerList[t.key] == listId then
            ChecklistDB.triggerList[t.key] = nil
          else
            ChecklistDB.triggerList[t.key] = listId
          end
          -- If all triggers are off, treat the list as disabled (so "None" is selected).
          if not listHasAnyTriggers(listId) then
            setListDisabled(listId, true)
          end
          UIDropDownMenu_SetText(dd, listTriggerSummary(listId))
          refreshOpenDropdownVisuals(dd, listId)
        end,
        isNotRadio = true,
        keepShownOnClick = true,
      }, level)
    end
  end)
end

local function deleteListById(idToDelete)
  ensureDB()
  if not idToDelete or not ChecklistDB.lists[idToDelete] then return end
  if ChecklistDB.defaultListId == idToDelete then
    return
  end
  ChecklistDB.lists[idToDelete] = nil
  ChecklistDB.listDisabled[idToDelete] = nil
  for trigger, id in pairs(ChecklistDB.triggerList) do
    if id == idToDelete then
      ChecklistDB.triggerList[trigger] = nil
    end
  end
  if selectedListId == idToDelete then
    selectedListId = nil
  end
  if renameListId == idToDelete then
    renameListId = nil
  end
  ensureAtLeastOneList()
end

local function rebuildListRows()
  ensureAtLeastOneList()
  ensureDefaultListId()
  local ids = listIdsSorted()
  for i, id in ipairs(ids) do
    local row = ensureRow(i)
    row._id = id
    row.name:SetText(listName(id))
    if id == selectedListId then
      row.name:SetTextColor(1, 0.82, 0)
    else
      row.name:SetTextColor(1, 1, 1)
    end

    initListEventDropdown(row.event, id)
    UIDropDownMenu_SetText(row.event, listTriggerSummary(id))

    row:SetScript("OnClick", function()
      selectedListId = id
      renameListId = nil
      addOrRename:SetText("Add")
      listNameBox:SetText("")
      clearItemEdit()
      rebuildListRows()
      rebuildItemRows()
    end)
    row.edit:SetScript("OnClick", function()
      ensureDB()
      selectedListId = id
      renameListId = id
      listNameBox:SetText(listName(id))
      addOrRename:SetText("Save")
      rebuildListRows()
      clearItemEdit()
      rebuildItemRows()
    end)
    row.remove:SetScript("OnClick", function()
      if next(ChecklistDB.lists) == nil then return end
      deleteListById(id)
      rebuildListRows()
      if not selectedListId then
        selectedListId = ChecklistDB.defaultListId or ChecklistDB.triggerList.login
      end
      clearItemEdit()
      rebuildItemRows()
    end)
    if ChecklistDB.defaultListId == id then
      row.remove:Disable()
      row.remove:SetAlpha(0.4)
    else
      row.remove:Enable()
      row.remove:SetAlpha(1)
    end
    row:Show()
  end
  for i = #ids + 1, #listRows do
    listRows[i]:Hide()
  end
  listsContent:SetHeight(math.max(1, (#ids * 32) + 4))
end

addOrRename:SetScript("OnClick", function()
  ensureDB()
  ensureAtLeastOneList()
  local name = (listNameBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then return end

  if renameListId and ChecklistDB.lists[renameListId] then
    ChecklistDB.lists[renameListId].name = name
    selectedListId = renameListId
    renameListId = nil
    addOrRename:SetText("Add")
    listNameBox:SetText("")
    listNameBox:ClearFocus()
    rebuildListRows()
    return
  end

  local id
  if Checklist_CreateList then
    id = Checklist_CreateList(name)
  else
    id = makeId()
    ChecklistDB.lists[id] = { name = name, items = {} }
  end
  selectedListId = id
  rebuildListRows()
  clearItemEdit()
  rebuildItemRows()
  listNameBox:SetText("")
  listNameBox:ClearFocus()
end)

listNameBox:SetScript("OnEnterPressed", function()
  addOrRename:Click()
end)

panel.refresh = function()
  ensureDB()
  enabled:SetChecked(ChecklistDB.enabled and true or false)
  minimapHide:SetChecked(ChecklistDB.minimap and ChecklistDB.minimap.hide and true or false)

  ensureAtLeastOneList()
  ensureDefaultListId()
  if ChecklistDB.openListId and ChecklistDB.lists[ChecklistDB.openListId] then
    selectedListId = ChecklistDB.openListId
    ChecklistDB.openListId = nil
  end
  if not selectedListId then
    selectedListId = ChecklistDB.defaultListId or ChecklistDB.triggerList.login
    if not selectedListId or not ChecklistDB.lists[selectedListId] then
      selectedListId = listIdsSorted()[1]
    end
  end
  rebuildListRows()
  clearItemEdit()
  rebuildItemRows()
end

panel.default = function()
  ensureDB()
  ChecklistDB.enabled = true
  ChecklistDB.lists = {}
  ChecklistDB.triggerList = {}
  selectedListId = nil
  panel.refresh()
end

panel.okay = function()
  -- no-op (saved live)
end

panel.cancel = function()
  -- no-op
end

panel:SetScript("OnShow", function()
  ensureDB()
  if not panel.__dropdownInit then
    panel.__dropdownInit = true
  end
  -- Keep the scroll child wide enough so controls don't wrap unexpectedly.
  if scrollFrame and root and scrollFrame.GetWidth then
    root:SetWidth(math.max(420, (scrollFrame:GetWidth() or 0) - 16))
  end
  panel.refresh()
end)

if InterfaceOptions_AddCategory then
  InterfaceOptions_AddCategory(panel)
end

SLASH_CHECKLISTOPTIONS1 = "/checklistoptions"
SLASH_CHECKLISTOPTIONS2 = "/cloptions"
SlashCmdList.CHECKLISTOPTIONS = function()
  if Settings and Settings.OpenToCategory and panel.__category then
    Settings.OpenToCategory(panel.__category.ID)
    return
  end
  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel.name)
    InterfaceOptionsFrame_OpenToCategory(panel.name)
    return
  end
  print("Checklist: options UI not available on this client build")
end

if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
  local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
  panel.__category = category
  Settings.RegisterAddOnCategory(category)
end
