Scriptname BennyShelterSellChestScript extends ObjectReference

ObjectReference Property aaBennyBhaNoteRef Auto
ObjectReference Property aaBennyShelterJunkChestRef Auto
ObjectReference Property aaBennyShelterGoldStrongboxRef Auto
GlobalVariable Property aaBennySellValuePct Auto
GlobalVariable Property aaBennyBhaNoteRead Auto
GlobalVariable Property aaBennySellInterval Auto   ; DEPRECATED — instant sell killed the clock. leave filled in ck, costs nothing
GlobalVariable Property aaBennyLastSellDay Auto    ; DEPRECATED — same
GlobalVariable Property GameDaysPassed Auto        ; DEPRECATED — same
Message Property aaBennySellChestMessage Auto
MiscObject Property Gold001 Auto
Actor Property PlayerRef Auto

int Function ProcessSellChest(ObjectReference junkChest, ObjectReference goldChest, float sellPct) Global Native

Event OnLoad()
    ; Do Nothing
EndEvent

Event OnActivate(ObjectReference akActionRef)
    ; Do Nothing
EndEvent

Auto State NoteUnreadState
    Event OnActivate(ObjectReference akActionRef)
        If aaBennyBhaNoteRead.GetValueInt() == 0
            ; Force player to read the note first — the tutorial gate stays
            aaBennyBhaNoteRef.Activate(PlayerRef)
            GoToState("NoteReadState")
        Else
            GoToState("NoteReadState")
        EndIf
    EndEvent
EndState

State NoteReadState
    Event OnActivate(ObjectReference akActionRef)
        ; Do Nothing — the chest itself opens normally
    EndEvent
EndState

; INSTANT SELL: drop junk in, close the lid, gold lands in the strongbox.
; no interval, no lottery, no waiting. the dll liquidates, papyrus announces.
Event OnClose(ObjectReference akContainer)
    If aaBennyBhaNoteRead.GetValueInt() == 0
        return  ; hasn't done the tutorial yet — nothing sells
    EndIf
    Int TotalSellValue = ProcessSellChest(aaBennyShelterJunkChestRef, aaBennyShelterGoldStrongboxRef, aaBennySellValuePct.GetValue())
    If TotalSellValue > 0
        Debug.Trace("[Benny'sShelter] Instant sell complete. Total gold earned: " + TotalSellValue)
        Debug.Notification("Benny fences the lot. " + TotalSellValue + " gold lands in the strongbox.")
    EndIf
EndEvent
