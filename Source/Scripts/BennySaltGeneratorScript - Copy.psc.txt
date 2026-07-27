Scriptname BennySaltGeneratorScript extends ObjectReference  

ObjectReference Property aaBennyGearAssemblyMissing Auto
ObjectReference Property aaBennyPistonMissing Auto
GlobalVariable Property aaBennySaltChamberTutorialShown Auto
GlobalVariable Property aaBennySaltChamberRepaired Auto
GlobalVariable Property aaBennySaltChamberAmount Auto
MiscObject Property DwarvenCenturionDynamo Auto
MiscObject Property DwarvenCog Auto
MiscObject Property IngotDwarven Auto
Message Property aaBennySaltChamberMessage Auto
Message Property aaBennySaltChamberTutorial Auto
Message Property aaBennySaltChamberRepairMessage Auto
Ingredient Property SaltPile Auto
Actor Property PlayerRef Auto

Event OnActivate(ObjectReference akActionRef)
    ; Do nothing
EndEvent

Auto State ShowUnrepairedMessage
    Event OnActivate(ObjectReference akActionRef)
        If aaBennySaltChamberRepaired.GetValueInt() == 0
            aaBennySaltChamberRepairMessage.Show()
            GoToState("Unrepaired")
        Else
            GoToState("Repaired")
        EndIf
    EndEvent
EndState

State Unrepaired
    Event OnActivate(ObjectReference akActionRef)
        If aaBennySaltChamberRepaired.GetValueInt() == 0
            If PlayerRef.GetItemCount(DwarvenCog) >= 2 && PlayerRef.GetItemCount(IngotDwarven) >= 4
                PlayerRef.RemoveItem(DwarvenCog, 2, True)
                PlayerRef.RemoveItem(IngotDwarven, 4, True)
                aaBennySaltChamberRepaired.SetValueInt(1)
                aaBennyGearAssemblyMissing.Enable(True)
                aaBennyPistonMissing.Enable(True)
                Debug.Notification("You have repaired the Crystallization Chamber.")
                GoToState("Repaired")
            Else
                aaBennySaltChamberRepairMessage.Show()
            EndIf
        Else
            GoToState("Repaired")
        EndIf
    EndEvent
EndState

State Repaired
    Event OnActivate(ObjectReference akActionRef)
        If aaBennySaltChamberTutorialShown.GetValueInt() == 0
            aaBennySaltChamberTutorial.Show(aaBennySaltChamberAmount.GetValue())
            aaBennySaltChamberTutorialShown.SetValueInt(1)
        Else
            Int dynamoCount = PlayerRef.GetItemCount(DwarvenCenturionDynamo)
            If dynamoCount > 0
                PlayerRef.RemoveItem(DwarvenCenturionDynamo, 1, True)
                PlayerRef.AddItem(SaltPile, aaBennySaltChamberAmount.GetValueInt(), True)
                Debug.Notification("The Crystallization Chamber has produced " + aaBennySaltChamberAmount.GetValueInt() + " Salt Piles.")
            Else
                aaBennySaltChamberMessage.Show()
            EndIf
        EndIf
    EndEvent
EndState