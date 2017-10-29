local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")

sepgp_loot = sepgp:NewModule("sepgp_loot", "AceDB-2.0")

function sepgp_loot:OnEnable()
  if not T:IsRegistered("sepgp_loot") then
    T:Register("sepgp_loot",
      "children", function()
        T:SetTitle("shootyepgp loot info")
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", "Refresh",
          "tooltipText", "Refresh window",
          "func", function() sepgp_loot:Refresh() end
        )
        D:AddLine(
          "text", "Clear",
          "tooltipText", "Clear Loot.",
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
  local detachedFrame, tablet
  for i=1,5 do
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
    if tablet and tablet.owner ~= nil and tablet.owner == "sepgp_loot" then
      if not (tablet:GetScript("OnHide")) then
        tablet:SetScript("OnHide",function()
            if not T:IsAttached("sepgp_loot") then
              T:Attach("sepgp_loot")
              this:SetScript("OnHide",nil)
            end
          end)
      end
    end
  end
end

function sepgp_loot:Toggle(forceShow)
  if T:IsAttached("sepgp_loot") then
    T:Detach("sepgp_loot")
    if (T:IsLocked("sepgp_loot")) then
      T:ToggleLocked("sepgp_loot")
    end
    self:setHideScript()
  elseif (forceShow) then
    sepgp_loot:Refresh()
  else
    T:Attach("sepgp_loot")
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
      "text",  C:Orange("Time"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("Item"),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   0, "child_justify2", "LEFT",
      "text3", C:Orange("Binds"),  "child_text3R",   0, "child_text3G",   1, "child_text3B",   0, "child_justify3", "CENTER",
      "text4", C:Orange("Looter"),  "child_text4R",   0, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT",
      "text5", C:Orange("GP Action"),  "child_text5R",   0, "child_text5G",   1, "child_text5B",   0, "child_justify5", "RIGHT"         
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