# dialogdb
# NPC DIALOG Storage and Selection

Will store NPC dialog into a table

You can select the dialog if the NPC is targeted and has Dialog for that zone.

##Table Layout
[ServerName][NPC Name][Zone][DialogDescription] = Dialog

Zone checks for either Current Zone name or 'allzones'
'allzones' is dialog for any zone you see the NPC in. Ex.Priest of Discord and Soul Binder 

# NPC Dialog DB Commands
## Current Zone:
/dialogdb add ["description"] ["command"] Adds to Current Zone description and command
/dialogdb add ["Value"] Adds to Current Zone description and command = Value 

##NPC Dialog DB All Zones:
/dialogdb addall ["description"] ["command"] Adds to All Zones description and command
/dialogdb addall ["Value"] Adds to All Zones description and command = Value