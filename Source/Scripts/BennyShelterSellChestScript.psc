Scriptname BennyShelterSellChestScript extends ObjectReference

ObjectReference Property aaBennyBhaNoteRef Auto
ObjectReference Property aaBennyShelterJunkChestRef Auto
ObjectReference Property aaBennyShelterGoldStrongboxRef Auto
GlobalVariable Property aaBennySellInterval Auto
GlobalVariable Property aaBennyBhaNoteRead Auto
GlobalVariable Property aaBennyLastSellDay Auto
GlobalVariable Property aaBennySellValuePct Auto
GlobalVariable Property GameDaysPassed Auto
Message Property aaBennySellChestMessage Auto
MiscObject Property Gold001 Auto
Actor Property PlayerRef Auto

Event OnLoad()
    ; Do Nothing
EndEvent

Event OnActivate(ObjectReference akActionRef)
    ; Do Nothing
EndEvent

Auto State NoteUnreadState
    Event OnLoad()
        Debug.Trace("[Benny'sShelter] Player has not read Bha's note yet.")
    EndEvent

    Event OnActivate(ObjectReference akActionRef)
        If aaBennyBhaNoteRead.GetValueInt() == 0
            ; Force player to read the note first
            aaBennyBhaNoteRef.Activate(PlayerRef)
            GoToState("NoteReadState")
        Else
            ; Already read, switch to NoteReadState
            GoToState("NoteReadState")
        EndIf
    EndEvent
EndState

State NoteReadState
    Event OnLoad()
        Int CurrentGameDaysPassed = GameDaysPassed.GetValueInt()
        Float CurrentInterval = CurrentGameDaysPassed - aaBennyLastSellDay.GetValueInt()
        Int SellInterval = aaBennySellInterval.GetValueInt()
        Debug.Trace("[Benny'sShelter] Sell Chest loaded. Days since last sell: " + CurrentInterval + ". Sell interval: " + SellInterval + ".")
        If CurrentInterval >= SellInterval
            Int SellIntervalMultiplier = Math.Floor(CurrentInterval / SellInterval)
            Debug.Trace("[Benny'sShelter] Sell interval reached. Multiplier: " + SellIntervalMultiplier)
            Debug.Trace("[Benny'sShelter] Starting sell process ...")
            ; Time to sell junk
            aaBennyLastSellDay.SetValue(CurrentGameDaysPassed)
            Form[] SellItems = aaBennyShelterJunkChestRef.GetContainerForms()
            Int ItemCount = SellItems.Length
            Int ItemsToSell = Utility.RandomInt(1, ItemCount)
            Int TotalSellValue = 0
            Int ii = 0
            Int i = 0
            While i < SellIntervalMultiplier - 1
                Debug.Trace("[Benny'sShelter] Increasing items to sell for interval multiplier. Current items to sell: " + ItemsToSell)
                ItemsToSell += Utility.RandomInt(1, ItemCount)
                i += 1
            EndWhile
            If ItemsToSell > ItemCount
                ItemsToSell = ItemCount
            EndIf
            While ii < ItemsToSell
                Form currentItem = SellItems[ii]
                Int currentItemCount = aaBennyShelterJunkChestRef.GetItemCount(currentItem)
                Float SingleGoldValue = currentItem.GetGoldValue() * aaBennySellValuePct.GetValue()
                Int TotalValue = Math.Floor(SingleGoldValue * currentItemCount)
                If TotalValue > 0
                    aaBennyShelterJunkChestRef.RemoveItem(currentItem, currentItemCount)
                    TotalSellValue += TotalValue
                    Debug.Trace("[Benny'sShelter] Sold " + currentItemCount + " of " + currentItem.GetName() + " for " + TotalValue + " gold.")
                EndIf
                ii += 1
            EndWhile
            If TotalSellValue > 0
                aaBennyShelterGoldStrongboxRef.AddItem(Gold001, TotalSellValue)
            EndIf
            Debug.Trace("[Benny'sShelter] Sell process completed. Items sold: " + ItemsToSell + ", Total gold earned: " + TotalSellValue)
            Utility.wait(4.0) ; Wait a moment before showing message in case player is still loading in.
            aaBennySellChestMessage.Show(ItemsToSell, TotalSellValue)
        Else
            Debug.Trace("[Benny'sShelter] Sell interval not reached yet. Skipping sell process.")
        EndIf
    EndEvent

    Event OnActivate(ObjectReference akActionRef)
        ; Do Nothing
    EndEvent
EndState