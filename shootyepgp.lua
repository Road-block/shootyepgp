sepgp = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceHook-2.1", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "AceModuleCore-2.0", "FuBarPlugin-2.0")
sepgp:SetModuleMixins("AceDebug-2.0")
local D = AceLibrary("Dewdrop-2.0")
local BZ = AceLibrary("Babble-Zone-2.2")

local playerName = (UnitName("player"))
local shooty_basegp = 135
local shooty_baseaward_ep = 100
local shooty_decay = 0.85
local shooty_max = 10000
local shooty_timeout = 45
local shooty_reservechan = "Reserves"
local shooty_reservecall = string.format("{shootyepgp}Type \"+\" in this channel if on main, or \"+<MainName>\" if on alt within %dsec.",shooty_timeout)
local shooty_reserveanswer = "^(%+)(%a*)$"
local out = "|cff9664c8shootyepgp:|r %s"
local lastUpdate = 0
local needInit = true
local shooty_debugchat
local running_check,running_bid
local partyUnit,raidUnit = {},{}
local reserves_blacklist,bids_blacklist = {},{}
do
  for i=1,40 do
    raidUnit[i] = "raid"..i
  end
  for i=1,4 do
    partyUnit[i] = "party"..i
  end
end

sepgp.reserves = {}
sepgp.timer = CreateFrame("Frame")
sepgp.timer.cd_text = ""
sepgp.timer:Hide()
sepgp.timer:SetScript("OnUpdate",function() sepgp.OnUpdate(this,arg1) end)

sepgp.bids_main,sepgp.bids_off,sepgp.bid_item = {},{},{}

function sepgp:OnInitialize() -- ADDON_LOADED (1) unless LoD
  if sepgp_saychannel == nil then sepgp_saychannel = "GUILD" end
  if sepgp_decay == nil then sepgp_decay = shooty_decay end
  if sepgp_progress == nil then sepgp_progress = "T1" end
  if sepgp_discount == nil then sepgp_discount = 0.25 end
  sepgp.extratip = CreateFrame("GameTooltip","shootyepgp_tooltip",UIParent,"GameTooltipTemplate")
end

function sepgp:AceEvent_FullyInitialized() -- SYNTHETIC EVENT, later than PLAYER_LOGIN, PLAYER_ENTERING_WORLD (3)
  for i=1,NUM_CHAT_WINDOWS do
    local tab = getglobal("ChatFrame"..i.."Tab")
    local cf = getglobal("ChatFrame"..i)
    local tabName = tab:GetText()
    if tab ~= nil and (string.lower(tabName) == "debug") then
      shooty_debugchat = cf
      ChatFrame_RemoveAllMessageGroups(shooty_debugchat)
      shooty_debugchat:SetMaxLines(1024)
      break
    end
  end 

  if (not sepgp_main) or (sepgp_main == "") then
    StaticPopup_Show("SHOOTY_EPGP_SET_MAIN")
  end

  if not self:IsEventScheduled("shootyepgpChannelInit") then
    self:ScheduleEvent("shootyepgpChannelInit",self.getReserveStatus,2,self)
  end

  -- if pfUI loaded, skin the extra tooltip
  if (pfUI) and pfUI.api and pfUI.api.CreateBackdrop and pfUI_config and pfUI_config.tooltip and pfUI_config.tooltip.alpha then
    pfUI.api.CreateBackdrop(sepgp.extratip,nil,nil,pfUI_config.tooltip.alpha)
  end
  -- hook tooltip to add our GP values
  sepgp:TipHook()
end

function sepgp:OnEnable() -- PLAYER_LOGIN (2)
  sepgp:RegisterEvent("GUILD_ROSTER_UPDATE",function() 
      if (arg1) then -- member join /leave
        self:SetRefresh(true)
      end
    end)
  sepgp:RegisterEvent("RAID_ROSTER_UPDATE",function()
      self:SetRefresh(true)
    end)
  sepgp:RegisterEvent("PARTY_MEMBERS_CHANGED",function()
      self:SetRefresh(true)
    end)
  sepgp:RegisterEvent("CHAT_MSG_RAID","captureLootCall")
  sepgp:RegisterEvent("CHAT_MSG_RAID_LEADER","captureLootCall")
  sepgp:RegisterEvent("CHAT_MSG_RAID_WARNING","captureLootCall")
  sepgp:RegisterEvent("CHAT_MSG_WHISPER","captureBid")

  if (IsInGuild()) then
    if (GetNumGuildMembers()==0) then
      GuildRoster()
    end
  end

  if AceLibrary("AceEvent-2.0"):IsFullyInitialized() then
    self:AceEvent_FullyInitialized()
  else
    self:RegisterEvent("AceEvent_FullyInitialized")
  end

end

function sepgp:OnMenuRequest()
  D:FeedAceOptionsTable(self:buildMenu())
end

function sepgp:TipHook()
  self:SecureHook(GameTooltip, "SetBagItem", function(this, bag, slot)
    sepgp:AddDataToTooltip(GameTooltip, GetContainerItemLink(bag, slot))
  end
  )  -- we leave it in for now so they can check if they were billed the correct GP
  self:SecureHook(GameTooltip, "SetLootItem", function(this, slot)
    sepgp:AddDataToTooltip(GameTooltip, GetLootSlotLink(slot))
  end
  )
  self:SecureHook(GameTooltip, "SetLootRollItem", function(this, id)
    sepgp:AddDataToTooltip(GameTooltip, GetLootRollItemLink(id))
  end
  ) 
  self:SecureHook("SetItemRef", function(link, name, button)
    if (link and name and ItemRefTooltip) then
      if (strsub(link, 1, 6) ~= "Player") then
        if (ItemRefTooltip:IsVisible()) then
          if (not DressUpFrame:IsVisible()) then
            sepgp:AddDataToTooltip(ItemRefTooltip, link)
          end
          ItemRefTooltip.isDisplayDone = nil
        end
      end
    end
  end
  ) 
  self:HookScript(GameTooltip, "OnHide", function()
    if sepgp.extratip:IsVisible() then sepgp.extratip:Hide() end
    self.hooks[GameTooltip]["OnHide"]()
  end
  )
  self:HookScript(ItemRefTooltip, "OnHide", function()
    if sepgp.extratip:IsVisible() then sepgp.extratip:Hide() end
    self.hooks[ItemRefTooltip]["OnHide"]()
  end
  )
end

function sepgp:getReserveStatus()
  if (IsInGuild()) then
    local guildName = (GetGuildInfo("player"))
    if (guildName) and guildName ~= "" then
      sepgp_reservechannel = string.format("%sReserves",(string.gsub(guildName," ","")))
    end
  end
  if sepgp_reservechannel == nil then sepgp_reservechannel = shooty_reservechan end  
  local reservesChannelID = tonumber((GetChannelName(sepgp_reservechannel)))
  if (reservesChannelID) and (reservesChannelID ~= 0) then
    sepgp:reservesToggle(true)
  end
end

function sepgp:AddDataToTooltip(tooltip,itemlink,itemstring)
  local price
  if (itemstring) then
    price = sepgp_prices:GetPrice(itemstring,sepgp_progress)
  elseif (itemlink) then
    price = sepgp_prices:GetPrice(itemlink,sepgp_progress)
  end
  if not price then return end
  local textRight = string.format("cost:|cff32cd32%d|r offspec:|cff20b2aa%d|r",price,math.floor(price*sepgp_discount))
  if (tooltip:NumLines() < 29) then
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("|cff9664c8shootyepgp|r",textRight)
    tooltip:Show()
  else
    sepgp.extratip:ClearLines()
    sepgp.extratip:SetOwner(tooltip,"ANCHOR_NONE")
    sepgp.extratip:ClearAllPoints()
    sepgp.extratip:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 0, -5)
    sepgp.extratip:SetPoint("TOPRIGHT", tooltip, "BOTTOMRIGHT", 0, -5)
    sepgp.extratip:AddDoubleLine("|cff9664c8shootyepgp|r",textRight)
    sepgp.extratip:Show()
  end
end

function sepgp:OnUpdate(elapsed)
  sepgp.timer.count_down = sepgp.timer.count_down - elapsed
  lastUpdate = lastUpdate + elapsed
  if sepgp.timer.count_down <= 0 then
    running_check = nil
    sepgp.timer:Hide()
    sepgp.timer.cd_text = "|cffff0000Finished|r"
    sepgp_reserves:Refresh()
  else
    sepgp.timer.cd_text = string.format("|cff00ff00%02d|r|cffffffffsec|r",sepgp.timer.count_down)
  end
  if lastUpdate > 0.5 then
    lastUpdate = 0
    sepgp_reserves:Refresh()
  end
end

-------------------
-- Communication
-------------------
function sepgp:flashFrame(frame)
  local tabFlash = getglobal(frame:GetName().."TabFlash")
  if ( not frame.isDocked or (frame == SELECTED_DOCK_FRAME) or UIFrameIsFlashing(tabFlash) ) then
    return
  end
  tabFlash:Show()
  UIFrameFlash(tabFlash, 0.25, 0.25, 60, nil, 0.5, 0.5)
end

function sepgp:debugPrint(msg)
  if (shooty_debugchat) then
    shooty_debugchat:AddMessage(string.format(out,msg))
    sepgp:flashFrame(shooty_debugchat)
  else
    sepgp:defaultPrint(msg)
  end
end

function sepgp:defaultPrint(msg)
  if not DEFAULT_CHAT_FRAME:IsVisible() then
    FCF_SelectDockFrame(DEFAULT_CHAT_FRAME)
  end
  DEFAULT_CHAT_FRAME:AddMessage(string.format(out,msg))
end

function sepgp:simpleSay(msg)
  SendChatMessage(string.format("shootyepgp: %s",msg), sepgp_saychannel)
end

function sepgp:adminSay(msg)
  -- API is broken on Elysium
  -- local g_listen, g_speak, officer_listen, officer_speak, g_promote, g_demote, g_invite, g_remove, set_gmotd, set_publicnote, view_officernote, edit_officernote, set_guildinfo = GuildControlGetRankFlags() 
  -- if (officer_speak) then
  SendChatMessage(string.format("shootyepgp: %s",msg),"OFFICER")
  -- end
end

---------------------
-- EPGP Operations
---------------------
function sepgp:init_notes(guild_index,note,officernote)
  if not tonumber(note) or (tonumber(note) < 0) then
    GuildRosterSetPublicNote(guild_index,0)
  end
  if not tonumber(officernote) or (tonumber(officernote) < shooty_basegp) then
    GuildRosterSetOfficerNote(guild_index,shooty_basegp)
  end
end

function sepgp:update_ep(getname,ep)
  for i = 1, GetNumGuildMembers(1) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    if (name==getname) then 
      sepgp:init_notes(i,note,officernote)
      GuildRosterSetPublicNote(i,ep)
    end
  end
end

function sepgp:update_gp(getname,gp)
  for i = 1, GetNumGuildMembers(1) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    if (name==getname) then 
      sepgp:init_notes(i,note,officernote)
      GuildRosterSetOfficerNote(i,gp) 
    end
  end
end

function sepgp:get_ep(getname,note) -- gets ep by name or note
  if (note) then
    if tonumber(note)==nil then return 0 end
  end
  for i = 1, GetNumGuildMembers(1) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    if tonumber(note)==nil then note=0 end
    if (name==getname) then return tonumber(note) end
  end
  return(0)
end

function sepgp:get_gp(getname,officernote) -- gets gp by name or officernote
  if (officernote) then
    if tonumber(officernote)==nil then return shooty_basegp end
  end
  for i = 1, GetNumGuildMembers(1) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    if tonumber(officernote)==nil then officernote=shooty_basegp end
    if (name==getname) then return tonumber(officernote) end
  end
  return(shooty_basegp)
end

function sepgp:award_raid_ep(ep) -- awards ep to raid members in zone
  if GetNumRaidMembers()>0 then
    sepgp:simpleSay(string.format("Giving %d ep to all raidmembers",ep))
    for i = 1, GetNumRaidMembers(true) do
      local name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i)
      sepgp:givename_ep(name,ep)
    end
  else UIErrorsFrame:AddMessage("You aren't in a raid dummy",1,0,0)end
end

function sepgp:award_reserve_ep(ep) -- awards ep to reserve list
  if table.getn(sepgp.shooty_reserves) > 0 then
    sepgp:simpleSay(string.format("Giving %d ep to active reserves",ep))
    for i, name in ipairs(sepgp.shooty_reserves) do
      sepgp:givename_ep(name,ep)
    end
    sepgp.reserves = {}
    reserves_blacklist = {}
  end
end

function sepgp:givename_ep(getname,ep) -- awards ep to a single character
  sepgp:debugPrint(string.format("Giving %d ep to %s",ep,getname))
  ep = ep + sepgp:get_ep(getname)
  sepgp:update_ep(getname,ep)
end

function sepgp:givename_gp(getname,gp) -- assigns gp to a single character
  sepgp:debugPrint(string.format("Giving %d gp to %s",gp,getname))
  local oldgp = sepgp:get_gp(getname)
  local newgp = gp + oldgp
  sepgp:adminSay(string.format("Awarding %d GP to %s. (Previous: %d, New: %d)",gp,getname,oldgp,newgp))
  sepgp:update_gp(getname,newgp)
end

function sepgp:decay_epgp() -- decays entire roster's ep and gp
  for i = 1, GetNumGuildMembers(1) do
    local name,_,_,_,class,_,ep,gp,_,_ = GetGuildRosterInfo(i)
    ep = tonumber(ep)
    gp = tonumber(gp)
    if ep == nil then 
  	else 
      ep = math.max(0,sepgp:num_round(ep*sepgp_decay))
  	  GuildRosterSetPublicNote(i,ep)
  	  gp = math.max(shooty_basegp,sepgp:num_round(gp*sepgp_decay))
  	  GuildRosterSetOfficerNote(i,gp)
    end
  end
  local msg = string.format("all ep and gp decayed by %d%%",(1-sepgp_decay)*100)
  sepgp:simpleSay(msg)
end

function sepgp:gp_reset()
   for i = 1, GetNumGuildMembers(1) do
     GuildRosterSetOfficerNote(i, shooty_basegp)
   end
   sepgp:debugPrint(string.format("All GP has been reset to %d.",shooty_basegp))
end

---------
-- Menu
---------
local T = AceLibrary("Tablet-2.0")

sepgp.defaultMinimapPosition = 180
sepgp.cannotDetachTooltip = true
sepgp.tooltipHidderWhenEmpty = false
sepgp.hasIcon = "Interface\\Icons\\INV_Misc_Orb_04"

function sepgp:OnTooltipUpdate()
  T:SetHint("|cffffff00Click|r to toggle Standings. \n|cffffff00Ctrl+Click|r to toggle Reserves. \n|cffffff00Alt+Click|r to toggle Bids. \n|cffffff00Right-Click|r for Options.")
end

function sepgp:OnClick()
  if (IsControlKeyDown()) then
    sepgp_reserves:Toggle()
  elseif (IsAltKeyDown()) then
    sepgp_bids:Toggle()
  else
    sepgp_standings:Toggle()
  end
end

function sepgp:SetRefresh(flag)
  needRefresh = flag
  if (flag) then
    sepgp_standings:Refresh()
  end
end

function sepgp:buildRosterTable()
  local g, r = { }, { }
  local numGuildMembers = GetNumGuildMembers(1)
  if (sepgp_raidonly) and GetNumRaidMembers() > 0 then
    for i = 1, GetNumRaidMembers(true) do
      local name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i) 
      r[name] = true
    end
  end
  for i = 1, numGuildMembers do
    local member_name,_,_,_,class,_,ep,gp,_,_ = GetGuildRosterInfo(i)
    if (sepgp_raidonly) and next(r) then
      if r[member_name] then
        table.insert(g,{["name"]=member_name,["class"]=class})
      end
    else
      table.insert(g,{["name"]=member_name,["class"]=class})
    end    
  end
  return g
end

function sepgp:buildClassMemberTable(roster,epgp)
  local desc,usage
  if epgp == "ep" then
    desc = "Account EPs to %s."
    usage = "<EP>"
  elseif epgp == "gp" then
    desc = "Account GPs to %s."
    usage = "<GP>"
  end
  local c = { }
  for i,member in ipairs(roster) do
    local class,name = member.class, member.name
    if c[class] == nil then
      c[class] = { }
      c[class].type = "group"
      c[class].name = class
      c[class].desc = class .. " members"
      c[class].hidden = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end
      c[class].args = { }
    end
    if c[class].args[name] == nil then
      c[class].args[name] = { }
      c[class].args[name].type = "text"
      c[class].args[name].name = name
      c[class].args[name].desc = string.format(desc,name)
      c[class].args[name].usage = usage
      if epgp == "ep" then
        c[class].args[name].get = "suggestedAwardEP"
        c[class].args[name].set = function(v) sepgp:givename_ep(name, tonumber(v)) end
      elseif epgp == "gp" then
        c[class].args[name].get = false
        c[class].args[name].set = function(v) sepgp:givename_gp(name, tonumber(v)) end
      end
      c[class].args[name].validate = function(v) return (type(v) == "number" or tonumber(v)) and tonumber(v) < shooty_max end
    end
  end
  return c
end

local options
function sepgp:buildMenu()
  if not (options) then
    options = {
    type = "group",
    desc = "shootyepgp options",
    handler = self,
    args = { }
    }
    options.args["ep"] = {
      type = "group",
      name = "+EPs to Member",
      desc = "Account EPs for member.",
      order = 10,
      hidden = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,
    }
    options.args["ep_raid"] = {
      type = "text",
      name = "+EPs to Raid",
      desc = "Award EPs to all raid members.",
      order = 20,
      get = "suggestedAwardEP",
      set = function(v) sepgp:award_raid_ep(tonumber(v)) end,
      usage = "<EP>",
      hidden = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,
      validate = function(v)
        local n = tonumber(v)
        return n and n >= 0 and n < shooty_max
      end
    }
    options.args["gp"] = {
      type = "group",
      name = "+GPs to Member",
      desc = "Account GPs for member.",
      order = 30,
      hidden = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,
    }
    options.args["ep_reserves"] = {
      type = "text",
      name = "+EPs to Reserves",
      desc = "Award EPs to all active Reserves.",
      order = 40,
      get = "suggestedAwardEP",
      set = function(v) sepgp:award_reserve_ep(tonumber(v)) end,
      usage = "<EP>",
      hidden = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,
      validate = function(v)
        local n = tonumber(v)
        return n and n >= 0 and n < shooty_max
      end    
    }
    options.args["reserves"] = {
      type = "toggle",
      name = "Enable Reserves",
      desc = "Participate in Standby Raiders List.\n|cffff0000Requires Main Character Name.|r",
      order = 50,
      get = function() return (sepgp.reservesChannelID ~= nil) and (sepgp.reservesChannelID ~= 0) end,
      set = function(v) sepgp:reservesToggle(v) end,
      disabled = function() return (sepgp_main == nil) end
    }
    options.args["afkcheck_reserves"] = {
      type = "execute",
      name = "AFK Check Reserves",
      desc = "AFK Check Reserves List",
      order = 60,
      hidden = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,
      func = function() sepgp:afkcheck_reserves() end
    }
    options.args["set_main"] = {
      type = "text",
      name = "Set Main",
      desc = "Set your Main Character for Reserve List.",
      order = 70,
      usage = "<MainChar>",
      get = function() return sepgp_main end,
      set = function(v) sepgp_main = (sepgp:verifyGuildMember(v)) end,
    }    
    options.args["raid_only"] = {
      type = "toggle",
      name = "Raid Only",
      desc = "Only show members in raid.",
      order = 80,
      get = function() return not not sepgp_raidonly end,
      set = function(v) 
        sepgp_raidonly = not sepgp_raidonly
        sepgp:SetRefresh(true)
      end,
    }
    options.args["report_channel"] = {
      type = "text",
      name = "Reporting channel",
      desc = "Channel used by reporting functions.",
      order = 90,
      get = function() return sepgp_saychannel end,
      set = function(v) sepgp_saychannel = v end,
      validate = { "PARTY", "RAID", "GUILD", "OFFICER" },
    }
    options.args["progress_tier"] = {
      type = "text",
      name = "Raid Progress",
      desc = "Highest Tier the Guild is raiding.\nUsed to adjust GP Prices.",
      order = 95,
      get = function() return sepgp_progress end,
      set = function(v) sepgp_progress = v sepgp_bids:Refresh() end,
      validate = { ["T3"]="4.Naxxramas", ["T2.5"]="3.Temple of Ahn\'Qiraj", ["T2"]="2.Blackwing Lair", ["T1"]="1.Molten Core"},
    }
    options.args["decay"] = {
      type = "execute",
      name = "Decay EPGP",
      desc = string.format("Decays all EPGP by %d%%",(1-(sepgp_decay or shooty_decay))*100),
      order = 100,
      hidden = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,
      func = function() sepgp:decay_epgp() end
    }    
    options.args["set_decay"] = {
      type = "range",
      name = "Set Decay %",
      desc = "Set Decay percentage (Admin only).",
      order = 110,
      usage = "<Decay>",
      get = function() return (1.0-sepgp_decay) end,
      set = function(v) sepgp_decay = (1 - v) end,
      min = 0.01,
      max = 0.5,
      step = 0.01,
      bigStep = 0.05,
      isPercent = true,
      hidden = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,    
    }
    options.args["set_discount"] = {
      type = "range",
      name = "Offspec Price %",
      desc = "Set Offspec / Resistance Items GP Percent.",
      order = 115,
      get = function() return sepgp_discount end,
      set = function(v) sepgp_discount = v end,
      min = 0,
      max = 1,
      step = 0.05,
      isPercent = true
    }
    options.args["reset"] = {
     type = "execute",
     name = "Reset GP",
     desc = string.format("gives everybody %d basic GP (Admin only).",shooty_basegp),
     order = 120,
     hidden = function() return not (IsGuildLeader()) end,
     func = function() sepgp:gp_reset() end
    }
  end
  if (needInit) or (needRefresh) then
    local members = sepgp:buildRosterTable()
    self:debugPrint(string.format("Scanning %d members for EP/GP data. (%s)",table.getn(members),(sepgp_raidonly and "Raid" or "Full")))
    options.args["ep"].args = sepgp:buildClassMemberTable(members,"ep")
    options.args["gp"].args = sepgp:buildClassMemberTable(members,"gp")
    if (needInit) then needInit = false end
    if (needRefresh) then needRefresh = false end
  end
  return options
end

---------------
-- Reserves
---------------
function sepgp:reservesToggle(flag)
  local reservesChannelID = tonumber((GetChannelName(sepgp_reservechannel)))
  if (flag) then -- we want in
    if (reservesChannelID) and reservesChannelID ~= 0 then
      sepgp.reservesChannelID = reservesChannelID
      if not self:IsEventRegistered("CHAT_MSG_CHANNEL") then
        sepgp:RegisterEvent("CHAT_MSG_CHANNEL","captureReserveChatter")
      end
      return true
    else
      sepgp:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE","reservesChannelChange")
      JoinChannelByName(sepgp_reservechannel)
      return
    end
  else -- we want out
    if (reservesChannelID) and reservesChannelID ~= 0 then
      sepgp:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE","reservesChannelChange")
      LeaveChannelByName(sepgp_reservechannel)
      return
    else
      if sepgp:IsEventRegistered("CHAT_MSG_CHANNEL") then
        sepgp:UnregisterEvent("CHAT_MSG_CHANNEL")
      end      
      return false
    end
  end
end

function sepgp:reservesChannelChange(msg,_,_,_,_,_,_,_,channel)
  if (msg) and (channel) and (channel == sepgp_reservechannel) then
    if msg == "YOU_JOINED" then
      sepgp.reservesChannelID = tonumber((GetChannelName(sepgp_reservechannel)))
      RemoveChatWindowChannel(DEFAULT_CHAT_FRAME:GetID(), sepgp_reservechannel)
      sepgp:RegisterEvent("CHAT_MSG_CHANNEL","captureReserveChatter")
    elseif msg == "YOU_LEFT" then
      sepgp.reservesChannelID = nil 
      if sepgp:IsEventRegistered("CHAT_MSG_CHANNEL") then
        sepgp:UnregisterEvent("CHAT_MSG_CHANNEL")
      end
    end
    sepgp:UnregisterEvent("CHAT_MSG_CHANNEL_NOTICE")
    D:Close()
  end
end

function sepgp:afkcheck_reserves()
  if (running_check) then return end
  if sepgp.reservesChannelID ~= nil and ((GetChannelName(sepgp.reservesChannelID)) == sepgp.reservesChannelID) then
    reserves_blacklist = {}
    sepgp.reserves = {}
    running_check = true
    sepgp.timer.count_down = shooty_timeout
    sepgp.timer:Show()
    SendChatMessage(shooty_reservecall,"CHANNEL",nil,sepgp.reservesChannelID)
    sepgp_reserves:Toggle(true)
  end
end

function sepgp:sendReserverResponce()
  if sepgp.reservesChannelID ~= nil then
    if (sepgp_main) then
      if sepgp_main == playerName then
        SendChatMessage("+","CHANNEL",nil,sepgp.reservesChannelID)
      else
        SendChatMessage(string.format("+%s",sepgp_main),"CHANNEL",nil,sepgp.reservesChannelID)
      end
    end
  end
end

function sepgp:captureReserveChatter(text, sender, _, _, _, _, _, _, channel)
  if not (channel) or not (channel == sepgp_reservechannel) then return end
  local reserve, reserve_class, reserve_rank, reserve_alt = nil,nil,nil,nil
  local r,_,rdy,name = string.find(text,shooty_reserveanswer)
  if (r) and (running_check) then
    if (rdy) then
      if (name) and (name ~= "") then
        if (not sepgp:inRaid(name)) then
          reserve, reserve_class, reserve_rank = sepgp:verifyGuildMember(name)
          if reserve ~= sender then
            reserve_alt = sender
          end
        end
      else
        if (not sepgp:inRaid(sender)) then
          reserve, reserve_class, reserve_rank = sepgp:verifyGuildMember(sender)    
        end
      end
      if reserve and reserve_class and reserve_rank then
        if reserve_alt then
          if not reserves_blacklist[reserve_alt] then
            reserves_blacklist[reserve_alt] = true
            table.insert(sepgp.reserves,{reserve,reserve_class,reserve_rank,reserve_alt})
          else
            sepgp:defaultPrint(string.format("|cffff0000%s|r trying to add %s to Reserves, but has already added a member. Discarding!",reserve_alt,reserve))
          end
        else
          if not reserves_blacklist[reserve] then
            reserves_blacklist[reserve] = true
            table.insert(sepgp.reserves,{reserve,reserve_class,reserve_rank})
          else
            sepgp:defaultPrint(string.format("|cffff0000%s|r has already been added to Reserves. Discarding!",reserve))
          end
        end
      end
    end
    return
  end
  local q = string.find(text,"^{shootyepgp}Type")
  if (q) and not (running_check) then
    if (not UnitInRaid("player")) or (not sepgp:inRaid(sender)) then
      StaticPopup_Show("SHOOTY_EPGP_RESERVE_AFKCHECK_RESPONCE")
    end
  end
end

---------
-- Bids
---------
local lootCall = {}
lootCall.whisp = {
  "^(w)[%s%p%c]+.+",".+[%s%p%c]+(w)$",".+[%s%p%c]+(w)[%s%p%c]+.*",".*[%s%p%c]+(w)[%s%p%c]+.+",
  "^(whisper)[%s%p%c]+.+",".+[%s%p%c]+(whisper)$",".+[%s%p%c]+(whisper)[%s%p%c]+.*",".*[%s%p%c]+(whisper)[%s%p%c]+.+",
  ".+[%s%p%c]+(bid)[%s%p%c]*.*",".*[%s%p%c]*(bid)[%s%p%c]+.+"
}
lootCall.ms = {".+(%+).*",".*(%+).+", ".+(ms).*",".*(ms).+", ".+(mainspec).*",".*(mainspec).+"}
lootCall.os = {".+(%-).*",".*(%-).+", ".+(os).*",".*(os).+", ".+(offspec).*",".*(offspec).+"}
function sepgp:captureLootCall(text, sender)
  if not (IsRaidLeader() or self:lootMaster()) then return end
  if not sender == playerName then return end
  if not (string.find(text, "|Hitem:", 1, true)) then return end
  local lowtext = string.lower(text)
  local whisperkw_found, mskw_found, oskw_found, link_found
  local _, itemLink, itemColor, itemString, itemName
  for _,f in ipairs(lootCall.whisp) do
    whisperkw_found = string.find(lowtext,f)
    if (whisperkw_found) then break end
  end
  for _,f in ipairs(lootCall.ms) do
    mskw_found = string.find(lowtext,f)
    if (mskw_found) then break end
  end
  for _,f in ipairs(lootCall.os) do
    oskw_found = string.find(lowtext,f)
    if (oskw_found) then break end
  end
  if (whisperkw_found) or (mskw_found) or (oskw_found) then
    _,_,itemLink = string.find(text,"(|c%x+|H.+|h%[.+%]|h|r)")
    if (itemLink) and (itemLink ~= "") then
      link_found, _, itemColor, itemString, itemName = string.find(itemLink, "^(|c%x+)|H(.+)|h(%[.+%])")
    end
    if (link_found) then
      self:clearBids()
      sepgp.bid_item.link = itemString
      sepgp.bid_item.linkFull = itemLink
      sepgp.bid_item.name = string.format("%s%s|r",itemColor,itemName)
      self:ScheduleEvent("shootyepgpBidTimeout",self.clearBids,360,self)
      running_bid = true
      self:debugPrint("Capturing Bids for 6min.")
      sepgp_bids:Toggle(true)
    end
  end
end

local lootBid = {}
lootBid.ms = {"(%+)",".+(%+).*",".*(%+).+",".*(%+).*","(ms)"}
lootBid.os = {"(%-)",".+(%-).*",".*(%-).+",".*(%-).*","(os)"}
function sepgp:captureBid(text, sender)
  if not (running_bid) then return end
  if not (IsRaidLeader() or self:lootMaster()) then return end
  if not sepgp.bid_item.link then return end
  local mskw_found,oskw_found
  local lowtext = string.lower(text)
  for _,f in ipairs(lootBid.ms) do
    mskw_found = string.find(text,f)
    if (mskw_found) then break end
  end
  for _,f in ipairs(lootBid.os) do
    oskw_found = string.find(text,f)
    if (oskw_found) then break end
  end
  if (mskw_found) or (oskw_found) then
    if self:inRaid(sender) then
      if bids_blacklist[sender] == nil then
        for i = 1, GetNumGuildMembers(1) do
          local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
          if name == sender then
            local ep = self:get_ep(name,note)
            local gp = self:get_gp(name,officernote)
            if (mskw_found) then
              bids_blacklist[sender] = true
              table.insert(sepgp.bids_main,{name,class,ep,gp,ep/gp})
            elseif (oskw_found) then
              bids_blacklist[sender] = true
              table.insert(sepgp.bids_off,{name,class,ep,gp,ep/gp})
            end
            sepgp_bids:Toggle(true)
            sepgp_bids:Refresh()
            return
          end
        end
      end
    end
  end
end

function sepgp:clearBids()
  sepgp:defaultPrint("clearBids")
  sepgp.bid_item = {}
  sepgp.bids_main = {}
  sepgp.bids_off = {}
  bids_blacklist = {}
  if self:IsEventScheduled("shootyepgpBidTimeout") then
    self:CancelScheduledEvent("shootyepgpBidTimeout")
  end
  running_bid = false
  sepgp_bids:Refresh()
end

------------
-- Utility 
------------
function sepgp:num_round(i)
  return math.floor(i+0.5)
end

function sepgp:verifyGuildMember(name)
  for i=1,GetNumGuildMembers(1) do
    local g_name, g_rank, g_rankIndex, g_level, g_class, g_zone, g_note, g_officernote, g_online = GetGuildRosterInfo(i)
    if (string.lower(name) == string.lower(g_name)) and (tonumber(g_level) == MAX_PLAYER_LEVEL) then
      return g_name, g_class, g_rank
    end
  end
  if (name) and name ~= "" then
    sepgp:defaultPrint(string.format("%s not found in the guild or not max level!",name))
  end
  return
end

function sepgp:inRaid(name)
  for i=1,GetNumRaidMembers() do
    if name == (UnitName(raidUnit[i])) then
      return true
    end
  end
  return false
end

function sepgp:lootMaster()
  local method, lootmasterID = GetLootMethod()
  if method == "master" and lootmasterID == 0 then
    return true
  else
    return false
  end
end

local raidZones = {["Molten Core"]="T1",["Onyxia\'s Lair"]="T1.5",["Blackwing Lair"]="T2",["Ahn'Qiraj"]="T2.5",["Naxxramas"]="T3"}
local zone_multipliers = {
  ["T3"] = {["T3"]=1,["T2.5"]=0.75,["T2"]=0.5,["T1.5"]=0.25,["T1"]=0.25},
  ["T2.5"] = {["T3"]=1,["T2.5"]=1,["T2"]=0.7,["T1.5"]=0.4,["T1"]=0.4},
  ["T2"] = {["T3"]=1,["T2.5"]=1,["T2"]=1,["T1.5"]=0.5,["T1"]=0.5},
  ["T1"] = {["T3"]=1,["T2.5"]=1,["T2"]=1,["T1.5"]=1,["T1"]=1}
}
function sepgp:suggestedAwardEP()
  local currentTier, zoneEN, zoneLoc, checkTier, multiplier
  local inInstance, instanceType = IsInInstance()
  if (inInstance == nil) or (instanceType ~= nil and instanceType == "none") then
    currentTier = "T1.5"   
  end
  if (inInstance) and (instanceType == "raid") then
    zoneLoc = GetRealZoneText()
    if (BZ:HasReverseTranslation(zoneLoc)) then
      zoneEN = BZ:GetReverseTranslation(zoneLoc)
      checkTier = raidZones[zoneEN]
      if (checkTier) then
        currentTier = checkTier
      end
    end
  end
  if not currentTier then 
    return shooty_baseaward_ep
  else
    multiplier = zone_multipliers[sepgp_progress][currentTier]
  end
  if (multiplier) then
    return multiplier*shooty_baseaward_ep
  else
    return shooty_baseaward_ep
  end
end

-------------
-- Dialogs
-------------
StaticPopupDialogs["SHOOTY_EPGP_SET_MAIN"] = {
  text = "Set your main to be able to participate in Reserve List EPGP Checks.",
  button1 = TEXT(ACCEPT),
  button2 = TEXT(CANCEL),
  hasEditBox = 1,
  maxLetters = 12,
  OnAccept = function()
    local editBox = getglobal(this:GetParent():GetName().."EditBox")
    sepgp_main = sepgp:verifyGuildMember(editBox:GetText())
  end,
  OnShow = function()
    getglobal(this:GetName().."EditBox"):SetText(sepgp_main or "")
    getglobal(this:GetName().."EditBox"):SetFocus()
  end,
  OnHide = function()
    if ( ChatFrameEditBox:IsVisible() ) then
      ChatFrameEditBox:SetFocus()
    end
    getglobal(this:GetName().."EditBox"):SetText("")
  end,
  EditBoxOnEnterPressed = function()
    local editBox = getglobal(this:GetParent():GetName().."EditBox")
    sepgp_main = sepgp:verifyGuildMember(editBox:GetText())
    this:GetParent():Hide()
  end,
  EditBoxOnEscapePressed = function()
    this:GetParent():Hide()
  end,
  timeout = 0,
  exclusive = 1,
  whileDead = 1,
  hideOnEscape = 1  
}
StaticPopupDialogs["SHOOTY_EPGP_RESERVE_AFKCHECK_RESPONCE"] = {
  text = "Reserves: AFKCheck. Are you available?",
  button1 = TEXT(YES),
  button2 = TEXT(NO),
  OnAccept = function()
    sepgp:sendReserverResponce()
  end,
  timeout = shooty_timeout,
  exclusive = 1,
  showAlert = 1,
  whileDead = 1,
  hideOnEscape = 1  
}
