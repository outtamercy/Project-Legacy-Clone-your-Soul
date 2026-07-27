Scriptname BennyShelterTrackingScript extends ActiveMagicEffect

Actor Property PlayerRef auto
ObjectReference Property aaBennyTrackerMarkerRef auto
Location Property aaBennyShelterLocation Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    If akCaster.IsInLocation(aaBennyShelterLocation)
        Return
    EndIf
    Debug.Trace("[Benny'sShelter] Player has changed cells - updating tracker marker.")
    Utility.Wait(0.1)
    aaBennyTrackerMarkerRef.MoveTo(PlayerRef)
EndEvent