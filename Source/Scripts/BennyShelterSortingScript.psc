Scriptname BennyShelterSortingScript extends ObjectReference

Actor Property PlayerRef Auto
BennyShelterSortingUtil SortingUtil
Quest Property aaBennyMCMQuest Auto
Message Property aaBennySortingBusy Auto
Message Property aaBennySortingConfirm Auto
ObjectReference Property aaBennyShelterSortingChestRef Auto

Event OnInit()
    SortingUtil = aaBennyMCMQuest as BennyShelterSortingUtil
EndEvent

Event OnPlayerLoadGame()
    SortingUtil = aaBennyMCMQuest as BennyShelterSortingUtil
EndEvent

Auto State NotSorting
    Event OnActivate(ObjectReference akActionRef)
        GoToState("Sorting")
        Int response = aaBennySortingConfirm.Show()
        If response == 0
            (aaBennyMCMQuest as BennyShelterSortingUtil).SortItemsFromContainer(PlayerRef)
        ElseIf response == 1
            aaBennyShelterSortingChestRef.Activate(PlayerRef)
        Else
            GoToState("NotSorting")
            Return
        EndIf
        GoToState("NotSorting")
    EndEvent
EndState

State Sorting
    Event OnActivate(ObjectReference akActionRef)
        aaBennySortingBusy.Show()
    EndEvent
EndState