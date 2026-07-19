Scriptname BennyShelterMCMScript extends MCM_ConfigBase

; ---- Project Legacy ----
Actor Property PlayerRef Auto
MiscItem Property PL_PortalCube Auto

; ---- Benny Shelter globals ----
GlobalVariable Property aaBennySaltChamberAmount Auto

GlobalVariable Property aaBennySortArmor Auto
GlobalVariable Property aaBennySortAmmo Auto
GlobalVariable Property aaBennySortBook Auto
GlobalVariable Property aaBennySortClutter Auto
GlobalVariable Property aaBennySortFirewood Auto
GlobalVariable Property aaBennySortFood Auto
GlobalVariable Property aaBennySortGem Auto
GlobalVariable Property aaBennySortGold Auto
GlobalVariable Property aaBennySortIngredient Auto
GlobalVariable Property aaBennySortLeather Auto
GlobalVariable Property aaBennySortOre Auto
GlobalVariable Property aaBennySortPoisons Auto
GlobalVariable Property aaBennySortPotions Auto
GlobalVariable Property aaBennySortScroll Auto
GlobalVariable Property aaBennySortSoulGem Auto
GlobalVariable Property aaBennySortTome Auto
GlobalVariable Property aaBennySortWeapons Auto
GlobalVariable Property aaBennySortJewelry Auto
GlobalVariable Property aaBennySellValuePct Auto
GlobalVariable Property aaBennySellInterval Auto
GlobalVariable Property aaBennySortQuestItems Auto

Event OnConfigInit()
    aaBennySaltChamberAmount.SetValue(GetModSettingInt("iSaltGeneratorAmount:General"))

    aaBennySortArmor.SetValueInt(GetModSettingBool("bSortArmor:Sorting") as int)
    aaBennySortAmmo.SetValueInt(GetModSettingBool("bSortAmmo:Sorting") as int)
    aaBennySortBook.SetValueInt(GetModSettingBool("bSortBook:Sorting") as int)
    aaBennySortClutter.SetValueInt(GetModSettingBool("bSortClutter:Sorting") as int)
    aaBennySortFirewood.SetValueInt(GetModSettingBool("bSortFirewood:Sorting") as int)
    aaBennySortFood.SetValueInt(GetModSettingBool("bSortFood:Sorting") as int)
    aaBennySortGem.SetValueInt(GetModSettingBool("bSortGem:Sorting") as int)
    aaBennySortGold.SetValueInt(GetModSettingBool("bSortGold:Sorting") as int)
    aaBennySortIngredient.SetValueInt(GetModSettingBool("bSortIngredient:Sorting") as int)
    aaBennySortLeather.SetValueInt(GetModSettingBool("bSortLeather:Sorting") as int)
    aaBennySortOre.SetValueInt(GetModSettingBool("bSortOre:Sorting") as int)
    aaBennySortPoisons.SetValueInt(GetModSettingBool("bSortPoisons:Sorting") as int)
    aaBennySortPotions.SetValueInt(GetModSettingBool("bSortPotions:Sorting") as int)
    aaBennySortScroll.SetValueInt(GetModSettingBool("bSortScrolls:Sorting") as int)
    aaBennySortSoulGem.SetValueInt(GetModSettingBool("bSortSoulGems:Sorting") as int)
    aaBennySortTome.SetValueInt(GetModSettingBool("bSortTome:Sorting") as int)
    aaBennySortWeapons.SetValueInt(GetModSettingBool("bSortWeapons:Sorting") as int)
    aaBennySortJewelry.SetValueInt(GetModSettingBool("bSortJewelry:Sorting") as int)
    aaBennySellValuePct.SetValue(GetModSettingFloat("fSellValuePct:General"))
    aaBennySellInterval.SetValue(GetModSettingInt("iSellIntervalDays:General"))
    aaBennySortQuestItems.SetValueInt(GetModSettingBool("bSortQuestItems:Sorting") as int)
EndEvent

Event OnSettingChange(string a_ID)
    If a_ID == "iSaltGeneratorAmount:General"
        aaBennySaltChamberAmount.SetValue(GetModSettingInt(a_ID))
    ElseIf a_ID == "bSortArmor:Sorting"
        aaBennySortArmor.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortAmmo:Sorting"
        aaBennySortAmmo.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortBook:Sorting"
        aaBennySortBook.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortClutter:Sorting"
        aaBennySortClutter.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortFirewood:Sorting"
        aaBennySortFirewood.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortFood:Sorting"
        aaBennySortFood.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortGem:Sorting"
        aaBennySortGem.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortGold:Sorting"
        aaBennySortGold.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortIngredient:Sorting"
        aaBennySortIngredient.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortLeather:Sorting"
        aaBennySortLeather.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortOre:Sorting"
        aaBennySortOre.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortPoisons:Sorting"
        aaBennySortPoisons.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortPotions:Sorting"
        aaBennySortPotions.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortScrolls:Sorting"
        aaBennySortScroll.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortSoulGems:Sorting"
        aaBennySortSoulGem.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortTome:Sorting"
        aaBennySortTome.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortWeapons:Sorting"
        aaBennySortWeapons.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "bSortJewelry:Sorting"
        aaBennySortJewelry.SetValueInt(GetModSettingBool(a_ID) as int)
    ElseIf a_ID == "fSellValuePct:General"
        aaBennySellValuePct.SetValue(GetModSettingFloat(a_ID))
    ElseIf a_ID == "iSellIntervalDays:General"
        aaBennySellInterval.SetValue(GetModSettingInt(a_ID))
    ElseIf a_ID == "bSortQuestItems:Sorting"
        aaBennySortQuestItems.SetValueInt(GetModSettingBool(a_ID) as int)
    EndIf
EndEvent

Event OnSettingSelect(string a_ID)
    If a_ID == "bGivePortalCube:General"
        If PlayerRef.GetItemCount(PL_PortalCube) == 0
            PlayerRef.AddItem(PL_PortalCube, 1, false)
            Debug.Notification("Project Legacy: Portal Cube added.")
        Else
            Debug.Notification("Project Legacy: You already have a Portal Cube.")
        EndIf
    EndIf
EndEvent