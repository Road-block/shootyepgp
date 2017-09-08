function sepgp:v2tov3()
  local count = 0
  for i = 1, GetNumGuildMembers(1) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    local ep = sepgp:get_ep_v2(name,note)
    local gp = sepgp:get_gp_v2(name,officernote)
    if ep > 0 and gp >= sepgp.VARS.basegp then
      count = count + 1
      sepgp:update_epgp_v3(ep,gp,i,name,officernote)
      --self:debugPrint(string.format("%s{%d:%d}",name,ep,gp))
    end
  end
  self:defaultPrint(string.format("Updated %d members to v3 storage.",count))
  sepgp_dbver = 3
end