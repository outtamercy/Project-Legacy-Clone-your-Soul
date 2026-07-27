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
    ; the sweep is now CHEAP — TryRestoreSlot does no actor work, only
    ; registry checks + prompt refreshes. the delay stays purely so the
    ; registry reload (dll side) has settled before we read it.
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
    Debug.Trace("PL/Manager: restore sweep done — all vessels dormant until summoned")
EndEvent
