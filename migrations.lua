function sepgp:v2tov3()
  local count = 0
  for i = 1, GetNumGuildMembers(1) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    local epv2 = sepgp:get_ep_v2(name,note)
    local gpv2 = sepgp:get_gp_v2(name,officernote)
    local epv3 = sepgp:get_ep_v3(name,officernote)
    local gpv3 = sepgp:get_gp_v3(name,officernote)
    if (epv3 and gpv3) then
      -- do nothing, we've migrated already
    elseif (epv2 and gpv2) and (epv2 > 0 and gpv2 >= sepgp.VARS.basegp) then
      count = count + 1
      -- self:defaultPrint(string.format("epv2:%s,gpv2:%s,i:%s,n:%s,o:%s",epv2,gpv2,i,name,officernote))
      sepgp:update_epgp_v3(epv2,gpv2,i,name,officernote)
    end
  end
  self:defaultPrint(string.format("Updated %d members to v3 storage.",count))
  sepgp_dbver = 3
end