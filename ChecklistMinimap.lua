-- ChecklistMinimap.lua
-- Minimap button: left-click opens checklist, right-click opens options, drag to reposition.

local function clampAngle(a)
  a = tonumber(a) or 0
  a = a % 360
  if a < 0 then a = a + 360 end
  return a
end

local function setButtonPosition(btn)
  if not ChecklistDB or not ChecklistDB.minimap then return end
  local angle = clampAngle(ChecklistDB.minimap.angle or 225)
  local radius = 80
  local rad = math.rad(angle)
  local x = math.cos(rad) * radius
  local y = math.sin(rad) * radius
  btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function ensureMinimapDefaults()
  if not ChecklistDB then ChecklistDB = {} end
  if not ChecklistDB.minimap then ChecklistDB.minimap = {} end
  if ChecklistDB.minimap.hide == nil then ChecklistDB.minimap.hide = false end
  if ChecklistDB.minimap.angle == nil then ChecklistDB.minimap.angle = 225 end
end

local function toggleMinimapButton()
  ensureMinimapDefaults()
  ChecklistDB.minimap.hide = not ChecklistDB.minimap.hide
  if Checklist_MinimapButton then
    if ChecklistDB.minimap.hide then
      Checklist_MinimapButton:Hide()
    else
      Checklist_MinimapButton:Show()
      setButtonPosition(Checklist_MinimapButton)
    end
  end
end

function Checklist_ToggleMinimapButton()
  toggleMinimapButton()
end

local function openOptions()
  if SlashCmdList and SlashCmdList.CHECKLISTOPTIONS then
    SlashCmdList.CHECKLISTOPTIONS()
    return
  end
  if Settings and Settings.OpenToCategory and ChecklistOptionsPanel and ChecklistOptionsPanel.__category then
    Settings.OpenToCategory(ChecklistOptionsPanel.__category.ID)
    return
  end
  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory("Checklist")
    InterfaceOptionsFrame_OpenToCategory("Checklist")
    return
  end
end

local function createButton()
  ensureMinimapDefaults()

  local btn = CreateFrame("Button", "Checklist_MinimapButton", Minimap)
  btn:SetFrameStrata("MEDIUM")
  btn:SetSize(31, 31)
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  bg:SetSize(54, 54)
  bg:SetPoint("TOPLEFT")

  local icon = btn:CreateTexture(nil, "ARTWORK")
  -- Use a neutral (white) check texture and tint it gold.
  icon:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  icon:SetVertexColor(1, 0.82, 0)
  icon:SetSize(18, 18)
  icon:SetPoint("CENTER", 1, 1)

  btn._bg = bg
  btn._icon = icon

  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Checklist")
    GameTooltip:AddLine("Left-click: open checklist", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: options", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: move button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      openOptions()
      return
    end
    Checklist_ShowChecklist("manual")
  end)

  btn:RegisterForDrag("LeftButton")
  btn:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function(s)
      local cx, cy = Minimap:GetCenter()
      local mx, my = GetCursorPosition()
      local scale = UIParent:GetScale()
      mx, my = mx / scale, my / scale
      local dx, dy = mx - cx, my - cy
      local angle = math.deg(math.atan2(dy, dx))
      ChecklistDB.minimap.angle = clampAngle(angle)
      s:ClearAllPoints()
      setButtonPosition(s)
    end)
  end)
  btn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
  end)

  btn:ClearAllPoints()
  setButtonPosition(btn)

  if ChecklistDB.minimap.hide then
    btn:Hide()
  else
    btn:Show()
  end

  return btn
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  if Checklist_MinimapButton then return end
  createButton()
end)
