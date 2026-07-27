Scriptname BennyPocketDimensionMarkScript Extends ActiveMagicEffect

ObjectReference Property aaBennyPocketDimensionRecallLocationMarker Auto
Message Property aaBennyPocketDimensionMarkedMessage Auto
Message Property aaBennyPocketDimensionMarkErrorMessage Auto
Location Property aaBennyShelterLocation Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    If akCaster.IsInLocation(aaBennyShelterLocation)
        aaBennyPocketDimensionMarkErrorMessage.Show()
        Return
    EndIf
    aaBennyPocketDimensionRecallLocationMarker.MoveTo(akCaster)
    aaBennyPocketDimensionMarkedMessage.Show()
EndEvent