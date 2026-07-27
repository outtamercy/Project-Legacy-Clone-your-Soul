Scriptname BennyDismantleConstructScript extends Actor  

Message Property aaBennyDismantleConstructMessage Auto
Message Property aaBennyConstructDiedMessage Auto
MiscObject Property aaBennyConstructParts Auto
Potion Property ReturnConstructCube Auto
Actor Property PlayerRef Auto
Int Property ReturnedPartsCount Auto

Auto State NotDismantling
    Event OnActivate(ObjectReference akActionRef)
        If akActionRef == PlayerRef
            GoToState("Dismantling")
            int choice = aaBennyDismantleConstructMessage.Show()
            If choice == 0
                PlayerRef.AddItem(ReturnConstructCube, 1, True)
                Self.Kill(PlayerRef)
            Else
                GoToState("NotDismantling")
            EndIf
        EndIf
    EndEvent

    Event OnDeath(Actor akKiller)
        If akKiller != PlayerRef
            If ReturnedPartsCount > 0
                aaBennyConstructDiedMessage.Show(ReturnedPartsCount)
                PlayerRef.AddItem(aaBennyConstructParts, ReturnedPartsCount, True)
            EndIf
        EndIf
    EndEvent
EndState

State Dismantling
    Event OnActivate(ObjectReference akActionRef)
        ; Do Nothing
    EndEvent

    Event OnDeath(Actor akKiller)
        ; Do Nothing
    EndEvent
EndState