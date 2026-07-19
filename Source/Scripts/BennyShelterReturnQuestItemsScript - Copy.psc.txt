Scriptname BennyShelterReturnQuestItemsScript extends ReferenceAlias

GlobalVariable Property aaBennySortQuestItems Auto
GlobalVariable Property aaBennyIsSorting Auto

Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
    If aaBennyIsSorting.GetValueInt() == 1 && aaBennySortQuestItems.GetValueInt() == 0
        If akItemReference
            If akItemReference.GetNumReferenceAliases()
                Debug.Trace("[Benny'sShelter] Returning quest item: " + akBaseItem.GetName())
                Game.GetPlayer().AddItem(akItemReference, aiItemCount, abSilent = True)
            EndIf
        EndIf
    EndIf
EndEvent