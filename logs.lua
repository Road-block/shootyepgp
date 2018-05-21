local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")
local CP = AceLibrary("Compost-2.0")
local L = AceLibrary("AceLocale-2.2"):new("shootyepgp")

sepgp_logs = sepgp:NewModule("sepgp_logs", "AceDB-2.0")
sepgp_logs.tmp = CP:Acquire()

function sepgp_logs:OnEnable()
  if not T:IsRegistered("sepgp_logs") then
    T:Register("sepgp_logs",
      "children", function()
        T:SetTitle(L["shootyepgp logs"])
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", L["Refresh"],
          "tooltipText", L["Refresh window"],
          "func", function() sepgp_logs:Refresh() end
        )
        D:AddLine(
          "text", L["Clear"],
          "tooltipText", L["Clear Logs."],
          "func", function() sepgp_log = {} sepgp_logs:Refresh() end
        )
      end      
    )
  end
  if not T:IsAttached("sepgp_logs") then
    T:Open("sepgp_logs")
  end
end

function sepgp_logs:OnDisable()
  T:Close("sepgp_logs")
end

function sepgp_logs:Refresh()
  T:Refresh("sepgp_logs")
end

function sepgp_logs:setHideScript()
  local i = 1
  local tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  while (tablet) and i<100 do
    if tablet.owner ~= nil and tablet.owner == "sepgp_logs" then
      sepgp:make_escable(string.format("Tablet20DetachedFrame%d",i),"add")
      tablet:SetScript("OnHide",nil)
      tablet:SetScript("OnHide",function()
          if not T:IsAttached("sepgp_logs") then
            T:Attach("sepgp_logs")
            this:SetScript("OnHide",nil)
          end
        end)
      break
    end    
    i = i+1
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  end  
end

function sepgp_logs:Top()
  if T:IsRegistered("sepgp_logs") and (T.registry.sepgp_logs.tooltip) then
    T.registry.sepgp_logs.tooltip.scroll=0
  end  
end

function sepgp_logs:Toggle(forceShow)
  self:Top()
  if T:IsAttached("sepgp_logs") then
    T:Detach("sepgp_logs") -- show
    if (T:IsLocked("sepgp_logs")) then
      T:ToggleLocked("sepgp_logs")
    end
    self:setHideScript()
  else
    if (forceShow) then
      sepgp_logs:Refresh()
    else
      T:Attach("sepgp_logs") -- hide
    end
  end  
end

function sepgp_logs:reverse(arr)
  CP:Recycle(sepgp_logs.tmp)
  for _,val in ipairs(arr) do
    table.insert(sepgp_logs.tmp,val)
  end
  local i, j = 1, table.getn(sepgp_logs.tmp)
  while i < j do
    sepgp_logs.tmp[i], sepgp_logs.tmp[j] = sepgp_logs.tmp[j], sepgp_logs.tmp[i]
    i = i + 1
    j = j - 1
  end
  return sepgp_logs.tmp
end

function sepgp_logs:BuildLogsTable()
  -- {timestamp,line}
  return self:reverse(sepgp_log)
end

function sepgp_logs:OnTooltipUpdate()
  local cat = T:AddCategory(
      "columns", 2,
      "text",  C:Orange(L["Time"]),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange(L["Action"]),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT"
    )
  local t = sepgp_logs:BuildLogsTable()
  for i = 1, table.getn(t) do
    local timestamp, line = unpack(t[i])
    cat:AddLine(
      "text", C:Silver(timestamp),
      "text2", line
    )
  end  
end

-- GLOBALS: sepgp_saychannel,sepgp_groupbyclass,sepgp_groupbyarmor,sepgp_groupbyrole,sepgp_raidonly,sepgp_decay,sepgp_minep,sepgp_reservechannel,sepgp_main,sepgp_progress,sepgp_discount,sepgp_log,sepgp_dbver,sepgp_looted
-- GLOBALS: sepgp,sepgp_prices,sepgp_standings,sepgp_bids,sepgp_loot,sepgp_reserves,sepgp_alts,sepgp_logs
