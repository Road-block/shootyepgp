local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")
local CP = AceLibrary("Compost-2.0")

sepgp_logs = sepgp:NewModule("sepgp_logs", "AceDB-2.0")
sepgp_logs.tmp = CP:Acquire()

function sepgp_logs:OnEnable()
  if not T:IsRegistered("sepgp_logs") then
    T:Register("sepgp_logs",
      "children", function()
        T:SetTitle("shootyepgp logs")
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", "Refresh",
          "tooltipText", "Refresh window",
          "func", function() sepgp_logs:Refresh() end
        )
        D:AddLine(
          "text", "Clear",
          "tooltipText", "Clear Logs.",
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
  local detachedFrame, tablet
  for i=1,5 do
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
    if tablet and tablet.owner ~= nil and tablet.owner == "sepgp_logs" then
      if not (tablet:GetScript("OnHide")) then
        tablet:SetScript("OnHide",function()
            if not T:IsAttached("sepgp_logs") then
              T:Attach("sepgp_logs")
              this:SetScript("OnHide",nil)
            end
          end)
      end
    end
  end
end

function sepgp_logs:Toggle(forceShow)
  if T:IsAttached("sepgp_logs") then
    T:Detach("sepgp_logs")
    if (T:IsLocked("sepgp_logs")) then
      T:ToggleLocked("sepgp_logs")
    end
    self:setHideScript()
  elseif (forceShow) then
    sepgp_logs:Refresh()
  else
    T:Attach("sepgp_logs")
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
      "text",  C:Orange("Time"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("Action"),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT"
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

-- GLOBALS: sepgp_saychannel,sepgp_groupbyclass,sepgp_raidonly,sepgp_decay,sepgp_reservechannel,sepgp_main,sepgp_progress,sepgp_discount,sepgp_log,sepgp_dbver,sepgp_looted
-- GLOBALS: sepgp,sepgp_prices,sepgp_standings,sepgp_bids,sepgp_loot,sepgp_reserves,sepgp_logs