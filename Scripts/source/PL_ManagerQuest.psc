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
    ; never construct actors inside the load storm — every mod on the list is
    ; running load handlers right now. queue the sweep for when it settles.
    Debug.Trace("PL/Manager: load detected, restore sweep queued")
    RegisterForSingleUpdate(5.0)
EndFunction

Event OnUpdate()
    Debug.Trace("PL/Manager: restore sweep start")
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
EndEvent