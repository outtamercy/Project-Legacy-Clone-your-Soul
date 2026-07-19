Scriptname BennyShelterSellChestScript extends ObjectReference

ObjectReference Property aaBennyShelterJunkChestRef Auto
ObjectReference Property aaBennyShelterGoldStrongboxRef Auto
GlobalVariable Property aaBennySellInterval Auto
GlobalVariable Property aaBennyLastSellDay Auto
GlobalVariable Property aaBennySellValuePct Auto
GlobalVariable Property GameDaysPassed Auto
Message Property aaBennySellChestMessage Auto

int Function ProcessSellChest(ObjectReference junkChest, ObjectReference goldChest, float sellPct) Global Native

Event OnLoad()
    Int CurrentGameDaysPassed = GameDaysPassed.GetValueInt()
    Float CurrentInterval = CurrentGameDaysPassed - aaBennyLastSellDay.GetValueInt()
    Int SellInterval = aaBennySellInterval.GetValueInt()

    If CurrentInterval >= SellInterval
        aaBennyLastSellDay.SetValue(CurrentGameDaysPassed)
        
        int totalGold = ProcessSellChest(aaBennyShelterJunkChestRef, aaBennyShelterGoldStrongboxRef, aaBennySellValuePct.GetValue())
        
        If totalGold > 0
            aaBennySellChestMessage.Show(0, totalGold)
        EndIf
    EndIf
EndEvent

Event OnActivate(ObjectReference akActionRef)
    ; Do Nothing
EndEvent