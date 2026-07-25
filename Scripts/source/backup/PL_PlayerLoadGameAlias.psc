Scriptname PL_PlayerLoadGameAlias extends ReferenceAlias

; OnPlayerLoadGame is MISSED on saves where this alias initializes during
; that very load — OnInit covers the first-load case, OnPlayerLoadGame
; covers every load after.
Event OnInit()
    (GetOwningQuest() as PL_ManagerQuest).HandleLoadGame()
EndEvent

Event OnPlayerLoadGame()
    (GetOwningQuest() as PL_ManagerQuest).HandleLoadGame()
EndEvent
