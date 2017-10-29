local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")

sepgp_standings = sepgp:NewModule("sepgp_standings", "AceDB-2.0")
local shooty_export = CreateFrame("Frame", "shooty_exportframe", UIParent)
shooty_export:SetWidth(250)
shooty_export:SetHeight(150)
shooty_export:SetPoint('TOP', UIParent, 'TOP', 0,-80)
shooty_export:SetFrameStrata('DIALOG')
shooty_export:Hide()
shooty_export:SetBackdrop({
  bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
  edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = {left = 5, right = 5, top = 5, bottom = 5}
  })
shooty_export:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
shooty_export:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
shooty_export.title = shooty_export:CreateFontString(nil,"OVERLAY")
shooty_export.title:SetPoint("TOP",0,-5)
shooty_export.title:SetFont("Fonts\\FRIZQT__.TTF", 12)
shooty_export.title:SetWidth(200)
shooty_export.title:SetJustifyH("LEFT")
shooty_export.title:SetJustifyV("CENTER")
shooty_export.title:SetText(C:Gold("Ctrl-C to copy. Esc to close."))
shooty_export.title:SetShadowOffset(1, -1)
shooty_export.edit = CreateFrame("EditBox", "shooty_exportedit", shooty_export)
shooty_export.edit:SetMultiLine(true)
shooty_export.edit:SetAutoFocus(true)
shooty_export.edit:EnableMouse(true)
shooty_export.edit:SetMaxLetters(0)
shooty_export.edit:SetHistoryLines(1)
shooty_export.edit:SetFont('Fonts\\ARIALN.ttf', 12, 'THINOUTLINE')
shooty_export.edit:SetWidth(290)
shooty_export.edit:SetHeight(190)
shooty_export.edit:SetScript("OnEscapePressed", function() 
    shooty_export.edit:SetText("")
    shooty_export:Hide() 
  end)
shooty_export.AddSelectText = function(txt)
  shooty_export.edit:SetText(txt)
  shooty_export.edit:HighlightText()
end
shooty_export.scroll = CreateFrame("ScrollFrame", "shooty_exportscroll", shooty_export, 'UIPanelScrollFrameTemplate')
shooty_export.scroll:SetPoint('TOPLEFT', shooty_export, 'TOPLEFT', 8, -30)
shooty_export.scroll:SetPoint('BOTTOMRIGHT', shooty_export, 'BOTTOMRIGHT', -30, 8)
shooty_export.scroll:SetScrollChild(shooty_export.edit)
table.insert(UISpecialFrames,"shooty_exportframe")

function sepgp_standings:OnEnable()
  if not T:IsRegistered("sepgp_standings") then
    T:Register("sepgp_standings",
      "children", function()
        T:SetTitle("shootyepgp standings")
        self:OnTooltipUpdate()
      end,
  		"showTitleWhenDetached", true,
  		"showHintWhenDetached", true,
  		"cantAttach", true,
  		"menu", function()
        D:AddLine(
          "text", "Raid Only",
          "tooltipText", "Only show members in raid.",
          "checked", sepgp_raidonly,
          "func", function() sepgp_standings:ToggleRaidOnly() end
        )      
        D:AddLine(
          "text", "Group by class",
          "tooltipText", "Group members by class.",
          "checked", sepgp_groupbyclass,
          "func", function() sepgp_standings:ToggleGroupByClass() end
        )
        D:AddLine(
          "text", "Refresh",
          "tooltipText", "Refresh window",
          "func", function() sepgp_standings:Refresh() end
        )
        D:AddLine(
          "text", "Export",
          "tooltipText", "Export standings to csv.",
          "func", function() sepgp_standings:Export() end
        )
  		end
    )
  end
  if not T:IsAttached("sepgp_standings") then
    T:Open("sepgp_standings")
  end
end

function sepgp_standings:OnDisable()
  T:Close("sepgp_standings")
end

function sepgp_standings:Refresh()
  T:Refresh("sepgp_standings")
end

function sepgp_standings:Export()
  local t = {}
  for i = 1, GetNumGuildMembers(1) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    local ep = (sepgp:get_ep_v3(name,officernote) or 0) --DONE: update v3
    local gp = (sepgp:get_gp_v3(name,officernote) or sepgp.VARS.basegp) --DONE: update v3
    if ep > 0 then
      table.insert(t,{name,ep,gp,ep/gp})
    end
  end 
  table.sort(t, function(a,b)
      return tonumber(a[4]) > tonumber(b[4])
    end)
  shooty_export:Show()
  local txt = "Name;EP;GP;PR\n"
  for i,val in ipairs(t) do
    txt = string.format("%s%s;%d;%d;%.4f\n",txt,val[1],val[2],val[3],val[4])
  end
  shooty_export.AddSelectText(txt)
end

function sepgp_standings:setHideScript()
  local detachedFrame, tablet
  for i=1,5 do
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
    if tablet and tablet.owner ~= nil and tablet.owner == "sepgp_standings" then
      if not (tablet:GetScript("OnHide")) then
        tablet:SetScript("OnHide",function()
            if not T:IsAttached("sepgp_standings") then
              T:Attach("sepgp_standings")
              this:SetScript("OnHide",nil)
            end
          end)
      end
    end
  end
end

function sepgp_standings:Toggle()
  if T:IsAttached("sepgp_standings") then
    T:Detach("sepgp_standings")
    if (T:IsLocked("sepgp_standings")) then
      T:ToggleLocked("sepgp_standings")
    end
    self:setHideScript()
  else
    T:Attach("sepgp_standings")
  end
end

function sepgp_standings:ToggleGroupByClass()
  sepgp_groupbyclass = not sepgp_groupbyclass 
  self:Refresh()
end

function sepgp_standings:ToggleRaidOnly()
  sepgp_raidonly = not sepgp_raidonly
  self:Refresh()
  sepgp:SetRefresh(true)
end

-- Builds a standings table with record:
-- name, class, EP, GP, PR
-- and sorted by PR
function sepgp_standings:BuildStandingsTable()
  local t = { }
  local r = { }
  if (sepgp_raidonly) and GetNumRaidMembers() > 0 then
    for i = 1, GetNumRaidMembers(true) do
      local name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i) 
      r[name] = true
    end
  end
  for i = 1, GetNumGuildMembers(1) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    local ep = (sepgp:get_ep_v3(name,officernote) or 0) --DONE: update v3
    local gp = (sepgp:get_gp_v3(name,officernote) or sepgp.VARS.basegp) --DONE: update v3
    if ep > 0 then
      if (sepgp_raidonly) and next(r) then
        if r[name] then
          table.insert(t,{name,class,ep,gp,ep/gp})
        end
      else
      	table.insert(t,{name,class,ep,gp,ep/gp})
      end
    end
  end
  if (sepgp_groupbyclass) then
    table.sort(t, function(a,b)
      if (a[2] ~= b[2]) then return a[2] > b[2]
      else return a[5] > b[5] end
    end)
  else
    table.sort(t, function(a,b)
    return a[5] > b[5]
    end)
  end
  return t
end

function sepgp_standings:OnTooltipUpdate()
  local cat = T:AddCategory(
      "columns", 4,
      "text",  C:Orange("Name"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("ep"),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT",
      "text3", C:Orange("gp"),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify3", "RIGHT",
      "text4", C:Orange("pr"),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT"
    )
  local t = self:BuildStandingsTable()
  for i = 1, table.getn(t) do
    local name, class, ep, gp, pr = unpack(t[i])
    cat:AddLine(
      "text", C:Colorize(BC:GetHexColor(class), name),
      "text2", string.format("%.4g", ep),
      "text3", string.format("%.4g", gp),
      "text4", string.format("%.4g", pr)
    )
  end
end

