Scriptname BennyShelterTrackerMarkerScript extends ObjectReference

Actor Property PlayerRef Auto

Event OnCellDetach()
    PlayerRef.GetCombatState()
    If PlayerRef.GetCombatState() == 0
        Debug.Trace("[Benny'sShelter] Player has left cell - updating tracker marker.")
        Utility.Wait(0.1)
        MoveTo(PlayerRef)
    EndIf
EndEvent