# shootyepgp
Guild Helper addon for EPGP loot system in WoW (1.12)

## setup
shootyepgp requires some modifications to guild permissions related to public and officer notes by the guild leader. 
- public and officer notes must be set to visible by all.
- public and officer notes **must** be editable **only** by the EPGP admins (officer rank and higher as an example)

## usage
All settings and functions are available from the shootyepgp icon on minimap or FuBar

## features
- EPGP standings list (all)
- Reserves - *standby list EP* - with alts support (admin and all)
- Item Bids list (admin/ML)
- Item GP prices on item tooltips (all)
- Export standings to cvs (all)
- Configurable EPGP Decay (admin)
- Configurable Offspec discount (all)
- Guild Progression GP multiplier (all)

The basic member functionality can be used even by members without the addon. 
- bidding by `/w masterlooter +` (for main spec) or `/w masterlooter -` (for off spec) after the loot officer links a piece of loot and asks for bids in raid chat.
- joining the guild reserves chat channel and responding with `/x +` (where x is the number of the custom channel) or `/x +MainName` if on an alt.
