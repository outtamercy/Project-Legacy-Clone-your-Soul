Scriptname PL_ManagerQuest extends Quest

Actor Property PlayerRef Auto
Spell Property PL_DPDTeleport Auto

ObjectReference Property ActiveStation Auto
ReferenceAlias Property PL_DialogueProxy Auto

bool Function IsSKSEPluginLoaded() Global Native

Event OnInit()
    if IsSKSEPluginLoaded()
        Debug.Notification("Project Legacy: SKSE plugin loaded.")
    else
        Debug.Notification("Project Legacy: SKSE plugin NOT found.")
    EndIf
    
    if !PlayerRef.HasSpell(PL_DPDTeleport)
        PlayerRef.AddSpell(PL_DPDTeleport)
    EndIf
EndEvent

Function HandleLoadGame()
    if !IsSKSEPluginLoaded()
        return
    endif
    
    Debug.Trace("Project Legacy: Load game hook fired.")
EndFunction