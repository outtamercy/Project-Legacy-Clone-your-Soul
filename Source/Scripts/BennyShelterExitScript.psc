Scriptname BennyShelterExitScript extends ObjectReference  

ObjectReference Property aaBennySaltChamberActivatorRef Auto
ObjectReference Property aaBennyPlayerLocationMarker Auto
ObjectReference Property aaBennyShelterExitRef Auto
Actor Property PlayerRef Auto  

Event OnActivate(ObjectReference akActionRef)
    aaBennySaltChamberActivatorRef.PlayAnimation("Close")
    aaBennyShelterExitRef.PlayAnimation("StartClose")
    Utility.wait(1.0)
    aaBennyShelterExitRef.PlayAnimation("PickUp")
    Utility.wait(0.5)
    PlayerRef.MoveTo(aaBennyPlayerLocationMarker)
EndEvent