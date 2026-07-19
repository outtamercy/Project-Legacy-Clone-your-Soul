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
    
    ; --- JCNG Cross-Game Restore ---
    Int jRegistry = JValue.ReadFromFile("Data/SKSE/Plugins/ProjectLegacy/slot_registry.json")
    if !jRegistry
        return
    endif
    
    Int jSlots = JMap.getObj(jRegistry, "slots")
    if !jSlots
        return
    endif
    
    int i = 0
    while i < Stations.Length
        ObjectReference station = Stations[i]
        if station
            PL_StationScript stationScript = station as PL_StationScript
            if stationScript
                int slotIdx = stationScript.SlotIndex
                Int jSlotData = JMap.getObj(jSlots, "slot_" + slotIdx)
                if jSlotData && JMap.getInt(jSlotData, "bound") == 1
                    stationScript.TryRestoreSlot()
                endif
            endif
        endif
        i += 1
    endWhile
EndFunction