local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")
local L = AceLibrary("AceLocale-2.2"):new("shootyepgp")

sepgp_alts = sepgp:NewModule("sepgp_alts", "AceDB-2.0")

function sepgp_alts:OnEnable()
  if not T:IsRegistered("sepgp_alts") then
    T:Register("sepgp_alts",
      "children", function()
        T:SetTitle(L["shootyepgp alts"])
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", L["Refresh"],
          "tooltipText", L["Refresh window"],
          "func", function() sepgp_alts:Refresh() end
        )
      end      
    )
  end
  if not T:IsAttached("sepgp_alts") then
    T:Open("sepgp_alts")
  end
end

function sepgp_alts:OnDisable()
  T:Close("sepgp_alts")
end

function sepgp_alts:Refresh()
  T:Refresh("sepgp_alts")
end

function sepgp_alts:setHideScript()
  local i = 1
  local tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  while (tablet) and i<100 do
    if tablet.owner ~= nil and tablet.owner == "sepgp_alts" then
      sepgp:make_escable(string.format("Tablet20DetachedFrame%d",i),"add")
      tablet:SetScript("OnHide",nil)
      tablet:SetScript("OnHide",function()
          if not T:IsAttached("sepgp_alts") then
            T:Attach("sepgp_alts")
            this:SetScript("OnHide",nil)
          end
        end)
      break
    end    
    i = i+1
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  end
end

function sepgp_alts:Top()
  if T:IsRegistered("sepgp_alts") and (T.registry.sepgp_alts.tooltip) then
    T.registry.sepgp_alts.tooltip.scroll=0
  end  
end

function sepgp_alts:Toggle(forceShow)
  self:Top()
  if T:IsAttached("sepgp_alts") then
    T:Detach("sepgp_alts") -- show
    if (T:IsLocked("sepgp_alts")) then
      T:ToggleLocked("sepgp_alts")
    end
    self:setHideScript()
  else
    if (forceShow) then
      sepgp_alts:Refresh()
    else
      T:Attach("sepgp_alts") -- hide
    end
  end
end

function sepgp_alts:OnClickItem(name)
  --ChatFrame_SendTell(name)
end

function sepgp_alts:BuildAltsTable()
  return sepgp.alts
end

function sepgp_alts:OnTooltipUpdate()
  local cat = T:AddCategory(
      "columns", 2,
      "text",  C:Orange(L["Main"]),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange(L["Alts"]),  "child_text2R",   0, "child_text2G",   1, "child_text2B",   0, "child_justify2", "RIGHT"
    )
  local t = self:BuildAltsTable()
  for main, alts in pairs(t) do
    local altstring = ""
    for alt,class in pairs(alts) do
      local coloredalt = C:Colorize(BC:GetHexColor(class), alt)
      if altstring == "" then
        altstring = coloredalt
      else
        altstring = string.format("%s, %s",altstring,coloredalt)
      end
    end
    cat:AddLine(
      "text", main,
      "text2", altstring--,
      --"func", "OnClickItem", "arg1", self, "arg2", main
    )
  end
end

-- GLOBALS: sepgp_saychannel,sepgp_groupbyclass,sepgp_groupbyarmor,sepgp_groupbyrole,sepgp_raidonly,sepgp_decay,sepgp_minep,sepgp_reservechannel,sepgp_main,sepgp_progress,sepgp_discount,sepgp_log,sepgp_dbver,sepgp_looted
-- GLOBALS: sepgp,sepgp_prices,sepgp_standings,sepgp_bids,sepgp_loot,sepgp_reserves,sepgp_alts,sepgp_logs
