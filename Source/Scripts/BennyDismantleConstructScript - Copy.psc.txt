Scriptname BennyDismantleConstructScript extends Actor  

Message Property aaBennyDismantleConstructMessage Auto
Message Property aaBennyConstructDiedMessage Auto
MiscObject Property aaBennyConstructParts Auto
Potion Property ReturnConstructCube Auto
Actor Property PlayerRef Auto
Int Property ReturnedPartsCount Auto

Event OnActivate(ObjectReference akActionRef)
    If akActionRef == PlayerRef
        aaBennyDismantleConstructMessage.Show()
        PlayerRef.AddItem(ReturnConstructCube, 1, True)
        Self.Kill(PlayerRef)
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