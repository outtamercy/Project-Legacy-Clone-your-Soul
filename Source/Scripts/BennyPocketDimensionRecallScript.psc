Scriptname BennyPocketDimensionRecallScript Extends ObjectReference

ObjectReference Property aaBennyPocketDimensionRecallLocationMarker Auto
Message Property aaBennyPocketDimensionRecalledMessage Auto
FormList Property aaBennyTeleportedAlliesList Auto
Message Property aaBennyRecallConfirmation Auto
Spell Property aaBennyPDCarryWeightBuffSpell Auto
Potion Property aaBennyShelterEntryDevice Auto
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
        Int confirm = aaBennyRecallConfirmation.Show()
        If confirm == 0
            int i = 0
            int teleportedAlliesCount = aaBennyTeleportedAlliesList.GetSize()
            While i < teleportedAlliesCount
                Actor ally = aaBennyTeleportedAlliesList.GetAt(i) as Actor
                If ally
                    ally.MoveTo(aaBennyPocketDimensionRecallLocationMarker)
                EndIf
                i += 1
            EndWhile
            aaBennyTeleportedAlliesList.Revert()
            PlayerRef.RemoveSpell(aaBennyPDCarryWeightBuffSpell)
            PlayerRef.MoveTo(aaBennyPocketDimensionRecallLocationMarker)
            aaBennyPocketDimensionRecalledMessage.Show()
            PlayerRef.AddItem(aaBennyShelterEntryDevice, 1, True)
        EndIf
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