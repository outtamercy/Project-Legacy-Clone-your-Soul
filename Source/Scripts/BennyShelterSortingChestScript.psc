Scriptname BennyShelterSortingChestScript extends ObjectReference

BennyShelterSortingUtil SortingUtil
Quest Property aaBennyMCMQuest Auto
Message Property aaBennySortingBusy Auto
GlobalVariable Property aaBennyIsSorting Auto

Event OnInit()
    SortingUtil = aaBennyMCMQuest as BennyShelterSortingUtil
EndEvent

Event OnPlayerLoadGame()
    SortingUtil = aaBennyMCMQuest as BennyShelterSortingUtil
EndEvent

Event OnClose(ObjectReference akContainer)
    bool isSorting = aaBennyIsSorting.GetValueInt() > 0
    If isSorting
        aaBennySortingBusy.Show()
        Return
    EndIf
    (aaBennyMCMQuest as BennyShelterSortingUtil).SortItemsFromContainer(self)
EndEvent