local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")

sepgp_bids = sepgp:NewModule("sepgp_bids", "AceDB-2.0")
sepgp_bids.tipOwner = CreateFrame("Frame","shootyepgp_bids_tipowner",UIParent)
sepgp_bids.tipOwner:Show()

function sepgp_bids:OnEnable()
  if not T:IsRegistered("sepgp_bids") then
    T:Register("sepgp_bids",
      "children", function()
        T:SetTitle("shootyepgp bids")
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", "Refresh",
          "tooltipText", "Refresh window",
          "func", function() sepgp_bids:Refresh() end
        )
      end      
    )
  end
  if not T:IsAttached("sepgp_bids") then
    T:Open("sepgp_bids")
  end
end

function sepgp_bids:OnDisable()
  T:Close("sepgp_bids")
end

function sepgp_bids:Refresh()
  T:Refresh("sepgp_bids")
end

function sepgp_bids:Toggle(forceShow)
  if T:IsAttached("sepgp_bids") then
    T:Detach("sepgp_bids")
    if (T:IsLocked("sepgp_bids")) then
      T:ToggleLocked("sepgp_bids")
    end
    --[[if not (sepgp:IsEventScheduled("shootyepgpBidRefresh")) then
      sepgp:ScheduleRepeatingEvent("shootyepgpBidRefresh", self.Refresh, 5, self)
    end]]
  elseif (forceShow) then
  else
    T:Attach("sepgp_bids")
    if GameTooltip:IsOwned(self.tipOwner) and GameTooltip:IsShown() then
      GameTooltip:Hide()
    end
    --[[if (sepgp:IsEventScheduled("shootyepgpBidRefresh")) then
      sepgp:CancelScheduledEvent("shootyepgpBidRefresh")
    end]]
  end
end

function sepgp_bids:lineTooltip(item,line)
  if line and line.highlight then
    if not sepgp:IsHooked(line.highlight,"Show") then
      sepgp:SecureHook(line.highlight,"Show",function()
        if not (GameTooltip:IsOwned(sepgp_bids.tipOwner) and GameTooltip:IsShown()) then
          GameTooltip:SetOwner(sepgp_bids.tipOwner,"ANCHOR_CURSOR")
          GameTooltip:SetHyperlink(item)
          GameTooltip:Show()
        end
      end)
    end
    if not sepgp:IsHooked(line.highlight,"Hide") then
      sepgp:SecureHook(line.highlight,"Hide",function()
        if GameTooltip:IsOwned(sepgp_bids.tipOwner) and GameTooltip:IsShown() then
          GameTooltip:Hide()
        end
      end)
    end
  end  
end

function sepgp_bids:announceWinnerMS(name, pr)
  if GetNumRaidMembers()>0 then
    SendChatMessage(string.format("Highest MainSpec Bid is %s with %dPR",name,pr),"RAID")
  end
end

function sepgp_bids:announceWinnerOS(name, pr)
  if GetNumRaidMembers()>0 then
    SendChatMessage(string.format("Highest OffSpec Bid is %s with %dPR",name,pr),"RAID")
  end
end

function sepgp_bids:BuildBidsTable()
  -- {name,class,ep,gp,ep/gp}
  table.sort(sepgp.bids_main, function(a,b)
    return a[5] > b[5]
  end)
  table.sort(sepgp.bids_off, function(a,b)
    return a[5] > b[5]
  end)
  return sepgp.bids_main, sepgp.bids_off
end

function sepgp_bids:OnTooltipUpdate()
  if not (sepgp.bid_item and sepgp.bid_item.link) then return end
  local link = sepgp.bid_item.link
  local itemName = sepgp.bid_item.name
  local price = sepgp_prices:GetPrice(link,sepgp_progress)
  local offspec
  if not price then 
    price = "<n/a>"
    offspec = "<n/a>"
  else
    offspec = math.floor(price*sepgp_discount)
  end
  local bidcat = T:AddCategory(
      "columns", 3,    
      "text", C:Orange("Bid Item"), "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("GP Cost"),     "child_text2R", 50/255, "child_text2G", 205/255, "child_text2B", 50/255, "child_justify2", "RIGHT",
      "text3", C:Orange("OffSpec"),  "child_text3R", 32/255, "child_text3G", 178/255, "child_text3B", 170/255, "child_justify3", "RIGHT",      
      "hideBlankLine", true
    )
  bidcat:AddLine(
      "text", itemName,
      "text2", price,
      "text3", offspec,
      "func", "lineTooltip", "arg1", self, "arg2", link, "arg3", this
    )
  local maincatHeader = T:AddCategory(
      "columns", 1,
      "text", C:Gold("MainSpec Bids")
    ):AddLine("text","")
  local maincat = T:AddCategory(
      "columns", 4,
      "text",  C:Orange("Name"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("ep"),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT",
      "text3", C:Orange("gp"),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify3", "RIGHT",
      "text4", C:Orange("pr"),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT",
      "hideBlankLine", true
    )
  local tm = self:BuildBidsTable()
  for i = 1, table.getn(tm) do
    local name, class, ep, gp, pr = unpack(tm[i])
    maincat:AddLine(
      "text", C:Colorize(BC:GetHexColor(class), name),
      "text2", string.format("%.4g", ep),
      "text3", string.format("%.4g", gp),
      "text4", string.format("%.4g", pr),
      "func", "announceWinnerMS", "arg1", self, "arg2", name, "arg3", pr
    )
  end
  local offcatHeader = T:AddCategory(
      "columns", 1,
      "text", C:Silver("OffSpec Bids")
    ):AddLine("text","") 
  local offcat = T:AddCategory(
      "columns", 4,
      "text",  C:Orange("Name"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("ep"),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT",
      "text3", C:Orange("gp"),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify3", "RIGHT",
      "text4", C:Orange("pr"),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT",
      "hideBlankLine", true
    )
  local _,to = self:BuildBidsTable()
  for i = 1, table.getn(to) do
    local name, class, ep, gp, pr = unpack(to[i])
    offcat:AddLine(
      "text", C:Colorize(BC:GetHexColor(class), name),
      "text2", string.format("%.4g", ep),
      "text3", string.format("%.4g", gp),
      "text4", string.format("%.4g", pr),
      "func", "announceWinnerOS", "arg1", self, "arg2", name, "arg3", pr
    )
  end  
end