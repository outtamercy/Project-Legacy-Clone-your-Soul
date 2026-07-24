Scriptname PL_PlayerLoadGameAlias extends ReferenceAlias

Event OnPlayerLoadGame()
    (GetOwningQuest() as PL_ManagerQuest).HandleLoadGame()
EndEvent
Event OnInit()
    ; on saves where this alias initializes DURING the load (any save that
    ; predates it), OnPlayerLoadGame already fired before we registered —
    ; queue the sweep manually so restore works on first sight
    (GetOwningQuest() as PL_ManagerQuest).HandleLoadGame()
EndEvent