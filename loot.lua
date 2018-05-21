local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")
local L = AceLibrary("AceLocale-2.2"):new("shootyepgp")

sepgp_loot = sepgp:NewModule("sepgp_loot", "AceDB-2.0")

function sepgp_loot:OnEnable()
  if not T:IsRegistered("sepgp_loot") then
    T:Register("sepgp_loot",
      "children", function()
        T:SetTitle(L["shootyepgp loot info"])
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", L["Refresh"],
          "tooltipText", L["Refresh window"],
          "func", function() sepgp_loot:Refresh() end
        )
        D:AddLine(
          "text", L["Clear"],
          "tooltipText", L["Clear Loot."],
          "func", function() sepgp_looted = {} sepgp_loot:Refresh() end
        )        
      end      
    )
  end
  if not T:IsAttached("sepgp_loot") then
    T:Open("sepgp_loot")
  end
end

function sepgp_loot:OnDisable()
  T:Close("sepgp_loot")
end

function sepgp_loot:Refresh()
  T:Refresh("sepgp_loot")
end

function sepgp_loot:setHideScript()
  local i = 1
  local tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  while (tablet) and i<100 do
    if tablet.owner ~= nil and tablet.owner == "sepgp_loot" then
      sepgp:make_escable(string.format("Tablet20DetachedFrame%d",i),"add")
      tablet:SetScript("OnHide",nil)
      tablet:SetScript("OnHide",function()
          if not T:IsAttached("sepgp_loot") then
            T:Attach("sepgp_loot")
            this:SetScript("OnHide",nil)
          end
        end)
      break
    end    
    i = i+1
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  end  
end

function sepgp_loot:Top()
  if T:IsRegistered("sepgp_loot") and (T.registry.sepgp_loot.tooltip) then
    T.registry.sepgp_loot.tooltip.scroll=0
  end  
end

function sepgp_loot:Toggle(forceShow)
  self:Top()
  if T:IsAttached("sepgp_loot") then
    T:Detach("sepgp_loot") -- show
    if (T:IsLocked("sepgp_loot")) then
      T:ToggleLocked("sepgp_loot")
    end
    self:setHideScript()
  else
    if (forceShow) then
      sepgp_loot:Refresh()
    else
      T:Attach("sepgp_loot") -- hide
    end
  end  
end

function sepgp_loot:BuildLootTable()
  table.sort(sepgp_looted, function(a,b)
    if (a[1] ~= b[1]) then return a[1] > b[1]
    else return a[2] > b[2] end
  end)
  return sepgp_looted
end

function sepgp_loot:OnClickItem(data)

end

function sepgp_loot:OnTooltipUpdate()
  local cat = T:AddCategory(
      "columns", 5,
      "text",  C:Orange(L["Time"]),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange(L["Item"]),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   0, "child_justify2", "LEFT",
      "text3", C:Orange(L["Binds"]),  "child_text3R",   0, "child_text3G",   1, "child_text3B",   0, "child_justify3", "CENTER",
      "text4", C:Orange(L["Looter"]),  "child_text4R",   0, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT",
      "text5", C:Orange(L["GP Action"]),  "child_text5R",   0, "child_text5G",   1, "child_text5B",   0, "child_justify5", "RIGHT"         
    )
  local t = self:BuildLootTable()
  for i = 1, table.getn(t) do
    local timestamp,player,player_color,itemLink,bind,price,off_price,action = unpack(t[i])
    cat:AddLine(
      "text", timestamp,
      "text2", itemLink,
      "text3", bind,
      "text4", player_color,
      "text5", action--,
--      "func", "OnClickItem", "arg1", self, "arg2", t[i]
    )
  end
end

-- GLOBALS: sepgp_saychannel,sepgp_groupbyclass,sepgp_groupbyarmor,sepgp_groupbyrole,sepgp_raidonly,sepgp_decay,sepgp_minep,sepgp_reservechannel,sepgp_main,sepgp_progress,sepgp_discount,sepgp_log,sepgp_dbver,sepgp_looted
-- GLOBALS: sepgp,sepgp_prices,sepgp_standings,sepgp_bids,sepgp_loot,sepgp_reserves,sepgp_alts,sepgp_logs
