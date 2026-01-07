-- ChecklistUI.lua
-- Popup checklist window. Content comes from SavedVariables lists (see Checklist.lua).

local FALLBACK_ITEMS = {
  "Open /checklist options and add items.",
}

local function getItems(trigger)
  if Checklist_GetItemsForTrigger then
    local items = Checklist_GetItemsForTrigger(trigger)
    if type(items) == "table" and #items > 0 then
      return items
    end
  end
  return FALLBACK_ITEMS
end

local function getListIdForTrigger(trigger)
  if not ChecklistDB then return nil end
  if trigger == "manual" then
    return ChecklistDB.defaultListId
  end
  if ChecklistDB.triggerList then
    return ChecklistDB.triggerList[trigger]
  end
  return nil
end

local function getTitle(trigger)
  if Checklist_GetListNameForTrigger then
    local name = Checklist_GetListNameForTrigger(trigger)
    if type(name) == "string" and name ~= "" then
      return name
    end
  end
  return ""
end

local function keyFor(trigger, index)
  return trigger .. ":" .. tostring(index)
end

local frame, content, checkboxes, titleFS
local function ensureUI()
  if frame then return end

  frame = CreateFrame("Frame", "ChecklistFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(360, 420)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:Hide()

  -- Replace the template title with a 3-part title bar:
  -- Left: "Checklist" | Center: list title | Right: addon version
  frame.TitleText:SetText("")

  local titleBar = CreateFrame("Frame", nil, frame)
  titleBar:SetPoint("TOPLEFT", 10, -5)
  -- Leave room for the close (X) button on the right side of BasicFrameTemplate.
  titleBar:SetPoint("TOPRIGHT", -34, -5)
  titleBar:SetHeight(20)

  local icon = titleBar:CreateTexture(nil, "OVERLAY")
  icon:SetSize(14, 14)
  icon:SetPoint("LEFT", 0, 0)
  -- Reuse the same built-in texture as the minimap button icon.
  -- Use a neutral (white) check texture and tint it gold.
  icon:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  icon:SetVertexColor(1, 0.82, 0)

  local left = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  left:SetPoint("LEFT", icon, "RIGHT", 4, 0)
  left:SetJustifyH("LEFT")
  left:SetText("Checklist")

  titleFS = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleFS:SetPoint("CENTER", 0, 0)
  titleFS:SetJustifyH("CENTER")

  local right = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  right:SetPoint("RIGHT", 0, 0)
  right:SetJustifyH("RIGHT")
  right:SetText(Checklist_GetVersion and Checklist_GetVersion() or "")

  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -32)
  scroll:SetPoint("BOTTOMRIGHT", -30, 44)

  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)

  checkboxes = {}

  local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  close:SetSize(90, 22)
  close:SetPoint("BOTTOMRIGHT", -12, 12)
  close:SetText("Close")
  close:SetScript("OnClick", function() frame:Hide() end)

  local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  reset:SetSize(90, 22)
  reset:SetPoint("RIGHT", close, "LEFT", -8, 0)
  reset:SetText("Reset")
  reset:SetScript("OnClick", function()
    ChecklistDB.checked = {}
    if frame._lastTrigger then
      Checklist_ShowChecklist(frame._lastTrigger)
    end
  end)

  local edit = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  edit:SetSize(90, 22)
  edit:SetPoint("BOTTOMLEFT", 12, 12)
  edit:SetText("Edit")
  edit:SetScript("OnClick", function()
    local listId = frame and frame._lastListId or (ChecklistDB and ChecklistDB.defaultListId) or nil
    if Checklist_OpenOptions then
      Checklist_OpenOptions(listId)
    elseif SlashCmdList and SlashCmdList.CHECKLISTOPTIONS then
      SlashCmdList.CHECKLISTOPTIONS()
    end
  end)
end

local function setCheckboxCount(n)
  for i = #checkboxes + 1, n do
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 6, -((i - 1) * 28))
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    cb.text:SetJustifyH("LEFT")
    cb:SetScript("OnClick", function(self)
      if not self._key then return end
      ChecklistDB.checked[self._key] = self:GetChecked() and true or nil
    end)
    checkboxes[i] = cb
  end
  for i = n + 1, #checkboxes do
    checkboxes[i]:Hide()
  end
end

function Checklist_ShowChecklist(trigger)
  ensureUI()
  trigger = trigger or "manual"
  frame._lastTrigger = trigger
  frame._lastListId = getListIdForTrigger(trigger)

  local items = getItems(trigger)
  titleFS:SetText(getTitle(trigger))

  setCheckboxCount(#items)
  for i, text in ipairs(items) do
    local cb = checkboxes[i]
    cb._key = keyFor(trigger, i)
    cb:SetChecked(ChecklistDB.checked[cb._key] and true or false)
    cb.text:SetText(text)
    cb:Show()
  end

  content:SetHeight(math.max(1, (#items * 28) + 10))

  frame:Show()
  frame:Raise()
end
