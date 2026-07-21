Scriptname PL_PlayerLoadGameAlias extends ReferenceAlias

Event OnPlayerLoadGame()
    (GetOwningQuest() as PL_ManagerQuest).HandleLoadGame()
EndEvent