Scriptname PL_ManagerQuest extends Quest

Actor Property PlayerRef Auto
Spell Property PL_DPDTeleport Auto

ObjectReference[] Property Stations Auto

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
    
    ; no more json registry — JDB (via the natives) is the source of truth now.
    ; TryRestoreSlot self-guards on IsSlotBound, so just ping every station
    ; and let each one decide if it's got a vessel to put back.
    int i = 0
    while i < Stations.Length
        ObjectReference station = Stations[i]
        if station
            PL_StationScript stationScript = station as PL_StationScript
            if stationScript
                stationScript.TryRestoreSlot()
            endif
        endif
        i += 1
    endWhile
EndFunction