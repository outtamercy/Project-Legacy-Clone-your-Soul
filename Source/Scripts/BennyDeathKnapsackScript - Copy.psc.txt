Scriptname BennyDeathKnapsackScript extends ObjectReference

ObjectReference Property aaBennyDeathKnapsackMarker Auto
ObjectReference Property aaBennyBackupKnapsackRef Auto
Quest Property aaBennyRetrieveBackpackQuest Auto

Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
    If akDestContainer == aaBennyBackupKnapsackRef
        Return
    EndIf
    If self.GetNumItems() == 0
        self.MoveTo(aaBennyDeathKnapsackMarker)
        aaBennyRetrieveBackpackQuest.SetStage(10)
        aaBennyRetrieveBackpackQuest.SetObjectiveCompleted(0)
        aaBennyRetrieveBackpackQuest.Stop()
    EndIf
EndEvent