Scriptname BennyShelterEntryScript extends activemagiceffect  

ObjectReference Property aaBennySaltChamberActivatorRef Auto
ObjectReference Property aaBennyPlayerLocationMarker Auto
ObjectReference Property aaBennyShelterInteriorMarker Auto
ObjectReference Property aaBennyShelterExitRef Auto
ObjectReference Property aaBennySoulBindingStandRef Auto
GlobalVariable Property aaBennySoulBound Auto
GlobalVariable Property aaBennySaltChamberRepaired Auto
Spell Property aaBennyPDCarryWeightBuffSpell Auto
Potion Property aaBennyShelterEntryDevice Auto
Location Property aaBennyShelterLocation Auto
Actor Property PlayerRef Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    bool PlayerInShelterLocation = PlayerRef.IsInLocation(aaBennyShelterLocation)
    If PlayerInShelterLocation
        PlayerRef.AddItem(aaBennyShelterEntryDevice, 1, True)
        Debug.Notification("You are already inside the shelter.")
    Else
        PlayerRef.GetCombatState()
        If PlayerRef.GetCombatState() == 1
            PlayerRef.AddItem(aaBennyShelterEntryDevice, 1, True)
            Debug.Notification("Cannot deploy shelter while in combat.")
        Else
            aaBennyPlayerLocationMarker.MoveTo(PlayerRef)
            PlayerRef.MoveTo(aaBennyShelterInteriorMarker)
            If aaBennySaltChamberRepaired.GetValueInt() == 1
                aaBennySaltChamberActivatorRef.PlayAnimation("Open")
            EndIf
            aaBennyShelterExitRef.PlayAnimation("SetDown")
            aaBennySoulBindingStandRef.PlayAnimation("SetDown")
            Utility.wait(0.5)
            aaBennyShelterExitRef.PlayAnimation("Open")
            If aaBennySoulBound.GetValueInt() == 1
                 aaBennySoulBindingStandRef.PlayAnimation("Open")
            EndIf
            PlayerRef.AddSpell(aaBennyPDCarryWeightBuffSpell)
        EndIf
    EndIf
EndEvent