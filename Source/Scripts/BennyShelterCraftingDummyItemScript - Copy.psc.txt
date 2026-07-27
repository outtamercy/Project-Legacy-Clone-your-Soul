Scriptname BennyShelterCraftingDummyItemScript extends ObjectReference

Actor Property PlayerRef Auto
MiscObject Property DummyItem Auto
FormList Property RecievedItems Auto

Event OnContainerChanged(ObjectReference akNewContainer, ObjectReference akOldContainer)
    If akNewContainer == PlayerRef
        PlayerRef.RemoveItem(DummyItem, 1, True)
        int listSize = RecievedItems.GetSize()
        int index = 0
        While index < listSize
            PlayerRef.AddItem(RecievedItems.GetAt(index), 1)
            index += 1
        EndWhile
    EndIf
EndEvent