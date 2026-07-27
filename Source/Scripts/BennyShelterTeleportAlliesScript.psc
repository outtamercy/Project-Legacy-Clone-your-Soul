Scriptname BennyShelterTeleportAlliesScript extends ActiveMagicEffect

ObjectReference Property aaBennyTeleportAlliesMarkerRef Auto
FormList Property aaBennyTeleportedAlliesList Auto
Actor Property PlayerRef Auto

Event OnEffectFinish(Actor akTarget, Actor akCaster)
    Debug.Trace("BennyShelterTeleportAlliesScript: OnEffectFinish triggered for " + akTarget)
    If akTarget != PlayerRef
        aaBennyTeleportedAlliesList.AddForm(akTarget)
        akTarget.MoveTo(aaBennyTeleportAlliesMarkerRef)
    EndIf
EndEvent