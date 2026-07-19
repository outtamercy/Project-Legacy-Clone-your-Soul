Scriptname BennyPocketDimensionRecallScript Extends ObjectReference

ObjectReference Property aaBennyPocketDimensionRecallLocationMarker Auto
Message Property aaBennyPocketDimensionRecalledMessage Auto
Message Property aaBennyRecallConfirmation Auto
Spell Property aaBennyPDCarryWeightBuffSpell Auto
Actor Property PlayerRef Auto

Event OnActivate(ObjectReference akActionRef)
    Int confirm = aaBennyRecallConfirmation.Show()
    If confirm == 0
        PlayerRef.MoveTo(aaBennyPocketDimensionRecallLocationMarker)
        aaBennyPocketDimensionRecalledMessage.Show()
    EndIf
EndEvent