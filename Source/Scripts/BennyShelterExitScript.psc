Scriptname BennyShelterExitScript extends ObjectReference  

Potion Property aaBennyShelterEntryDevice Auto
ObjectReference Property aaBennySaltChamberActivatorRef Auto
ObjectReference Property aaBennyPlayerLocationMarker Auto
ObjectReference Property aaBennyShelterExitRef Auto
FormList Property aaBennyTeleportedAlliesList Auto
Spell Property aaBennyPDCarryWeightBuffSpell Auto
Actor Property PlayerRef Auto  

; Reset state on load for updating mid-save
Event OnLoad()
    GoToState("NotLeaving")
EndEvent

Auto State NotLeaving
    Event OnLoad()
        ; DoNothing
    EndEvent

    Event OnActivate(ObjectReference akActionRef)
        GoToState("Leaving")
        PlayerRef.RemoveSpell(aaBennyPDCarryWeightBuffSpell)
        aaBennySaltChamberActivatorRef.PlayAnimation("Close")
        aaBennyShelterExitRef.PlayAnimation("StartClose")
        int i = 0
        int teleportedAlliesCount = aaBennyTeleportedAlliesList.GetSize()
        While i < teleportedAlliesCount
            Actor ally = aaBennyTeleportedAlliesList.GetAt(i) as Actor
            If ally
                ally.MoveTo(aaBennyPlayerLocationMarker)
            EndIf
            i += 1
        EndWhile
        aaBennyTeleportedAlliesList.Revert()
        Utility.wait(1.0)
        aaBennyShelterExitRef.PlayAnimation("PickUp")
        Utility.wait(0.5)
        PlayerRef.AddItem(aaBennyShelterEntryDevice, 1, True)
        PlayerRef.MoveTo(aaBennyPlayerLocationMarker)
        GoToState("NotLeaving")
    EndEvent
EndState

State Leaving
    Event OnLoad()
        ; DoNothing
    EndEvent

    Event OnActivate(ObjectReference akActionRef)
        ; Do Nothing
    EndEvent
EndState