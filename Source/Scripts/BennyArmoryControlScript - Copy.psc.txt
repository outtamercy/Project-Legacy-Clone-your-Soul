Scriptname BennyArmoryControlScript extends ObjectReference

ObjectReference Property aaBennyShelterTopFloorAlcoveMidRef Auto
ObjectReference Property aaBennyShelterTopFloorHallMidRef Auto

Message Property aaBennyActivateArmoryMessage Auto
Message Property aaBennyDeactivateArmoryMessage Auto

Auto State ArmoryDisabled
    Event OnActivate(ObjectReference akActionRef)
        int choice = aaBennyActivateArmoryMessage.Show()
        If choice == 0
            aaBennyShelterTopFloorHallMidRef.Enable()
            aaBennyShelterTopFloorAlcoveMidRef.Disable(True)
            GoToState("ArmoryEnabled")
        EndIf
    EndEvent
EndState

State ArmoryEnabled
    Event OnActivate(ObjectReference akActionRef)
        int choice = aaBennyDeactivateArmoryMessage.Show()
        If choice == 0
            aaBennyShelterTopFloorAlcoveMidRef.Enable(True)
            aaBennyShelterTopFloorHallMidRef.Disable(True)
            GoToState("ArmoryDisabled")
        EndIf
    EndEvent
EndState