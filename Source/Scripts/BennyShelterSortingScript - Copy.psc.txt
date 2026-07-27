Scriptname BennyShelterSortingScript extends ObjectReference

; Keywords
Keyword Property BYOHHouseCraftingCategorySmithing Auto
Keyword Property VendorItemOreIngot Auto
Keyword Property VendorItemGem Auto
Keyword Property VendorItemFood Auto
Keyword Property VendorItemFoodRaw Auto
Keyword Property VendorItemClothing Auto
Keyword Property VendorItemArmor Auto
Keyword Property VendorItemBook Auto
Keyword Property VendorItemWeapon Auto
Keyword Property VendorItemClutter Auto
Keyword Property VendorItemAnimalHide Auto
Keyword Property VendorItemAnimalPart Auto
Keyword Property VendorItemSoulGem Auto
Keyword Property VendorItemIngredient Auto
Keyword Property VendorItemStaff Auto
Keyword Property VendorItemPoison Auto
Keyword Property VendorItemPotion Auto
Keyword Property VendorItemRecipe Auto
Keyword Property VendorItemFirewood Auto
Keyword Property VendorItemArrow Auto
Keyword Property VendorItemScroll Auto
Keyword Property VendorItemSpellTome Auto
Keyword Property VendorItemJewelry Auto

; Item specific properties
Ingredient Property SaltPile Auto
MiscObject Property Gold001 Auto
MiscObject Property DwarvenCenturionDynamo Auto
Potion Property BYOHFoodFlour Auto

; Containers
ObjectReference Property aaBennyShelterVegetablesBarrelRef Auto
ObjectReference Property aaBennyShelterStewBarrelRef Auto
ObjectReference Property aaBennyShelterFlourChestRef Auto
ObjectReference Property aaBennyShelterLiquorChestRef Auto
ObjectReference Property aaBennyShelterFirewoodChestRef Auto
ObjectReference Property aaBennyShelterRawMeatBarrelRef Auto
ObjectReference Property aaBennyShelterIngredientStrongboxRef Auto
ObjectReference Property aaBennyShelterCookedMeatBarrelRef Auto
ObjectReference Property aaBennyShelterCheeseChestRef Auto
ObjectReference Property aaBennyShelterPotionChestRef Auto
ObjectReference Property aaBennyShelterPoisonChestRef Auto
ObjectReference Property aaBennyShelterBookChestRef Auto
ObjectReference Property aaBennyShelterScrollStrongboxRef Auto
ObjectReference Property aaBennyShelterGoldStrongboxRef Auto
ObjectReference Property aaBennyShelterArmorChestRef Auto
ObjectReference Property aaBennyShelterClothingChestRef Auto
ObjectReference Property aaBennyShelterWeaponChestRef Auto
ObjectReference Property aaBennyShelterAmmoChestRef Auto
ObjectReference Property aaBennyShelterGemStrongboxRef Auto
ObjectReference Property aaBennyShelterSoulgemStrongboxRef Auto
ObjectReference Property aaBennyShelterSaltContainerRef Auto
ObjectReference Property aaBennyShelterOreChestRef Auto
ObjectReference Property aaBennyShelterIngotChestRef Auto
ObjectReference Property aaBennyShelterLeatherChestRef Auto
ObjectReference Property aaBennyShelterMiscChestRef Auto
ObjectReference Property aaBennyShelterRecipeChestRef Auto
ObjectReference Property aaBennyShelterRawFoodBarrelRef Auto
ObjectReference Property aaBennyShelterCookedFoodBarrelRef Auto
ObjectReference Property aaBennyShelterCenturionContainerRef Auto
ObjectReference Property aaBennyShelterJewelryStrongboxRef Auto
ObjectReference Property aaBennyShelterConstructBarrelRef Auto

; Options
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
GlobalVariable Property aaBennySortQuestItems Auto
GlobalVariable Property aaBennyBedroomUpgraded Auto
GlobalVariable Property aaBennyIsSorting Auto

; Sorting Lists
FormList Property aaBennyRecipesList Auto
FormList Property aaBennyOreList Auto

FormList Property aaBennyCheeseList Auto
FormList Property aaBennyCookedMeatsList Auto
FormList Property aaBennyFruitsVegetablesList Auto
FormList Property aaBennyRawMeatsList Auto
FormList Property aaBennySoupsList Auto
FormList Property aaBennyLiquorList Auto

FormList Property aaBennyConstructList Auto

; Misc
Actor Property PlayerRef Auto
Message Property aaBennySortingStarted Auto
Message Property aaBennySortingBusy Auto
Message Property aaBennySortingComplete Auto
Message Property aaBennySortingConfirm Auto

Auto State NotSorting
    Event OnActivate(ObjectReference akActionRef)
        GoToState("Sorting")
        Int response = aaBennySortingConfirm.Show()
        If response != 0
            GoToState("NotSorting")
            Return
        EndIf
        aaBennyIsSorting.SetValueInt(1)
        aaBennySortingStarted.Show()
        Form[] PlayerItems = PlayerRef.GetContainerForms()
        Int itemCount = PlayerItems.Length
        Int ItemsSorted = 0
        Int i = 0

        ; Sorting Options
        bool sortArmor = aaBennySortArmor.GetValueInt() > 0
        bool sortAmmo = aaBennySortAmmo.GetValueInt() > 0
        bool sortBook = aaBennySortBook.GetValueInt() > 0
        bool sortClutter = aaBennySortClutter.GetValueInt() > 0
        bool sortFirewood = aaBennySortFirewood.GetValueInt() > 0
        bool sortFood = aaBennySortFood.GetValueInt() > 0
        bool sortGem = aaBennySortGem.GetValueInt() > 0
        bool sortGold = aaBennySortGold.GetValueInt() > 0
        bool sortIngredient = aaBennySortIngredient.GetValueInt() > 0
        bool sortLeather = aaBennySortLeather.GetValueInt() > 0
        bool sortOre = aaBennySortOre.GetValueInt() > 0
        bool sortPoisons = aaBennySortPoisons.GetValueInt() > 0
        bool sortPotions = aaBennySortPotions.GetValueInt() > 0
        bool sortScroll = aaBennySortScroll.GetValueInt() > 0
        bool sortSoulGem = aaBennySortSoulGem.GetValueInt() > 0
        bool sortTome = aaBennySortTome.GetValueInt() > 0
        bool sortWeapons = aaBennySortWeapons.GetValueInt() > 0
        bool sortJewelry = aaBennySortJewelry.GetValueInt() > 0
        bool sortClothing = aaBennyBedroomUpgraded.GetValueInt() > 0
        bool sortQuestItems = aaBennySortQuestItems.GetValueInt() > 0

        While i < itemCount
            Form currentItem = PlayerItems[i]
            int currentItemCount = PlayerRef.GetItemCount(currentItem)
            bool Sorted = False

            bool isFavorited = Game.IsObjectFavorited(currentItem)
            bool isEquipped = PlayerRef.IsEquipped(currentItem)
            bool equippedRight = PlayerRef.GetEquippedWeapon() == currentItem
            bool equippedLeft = PlayerRef.GetEquippedWeapon(True) == currentItem
            bool isClothing = currentItem.HasKeyword(VendorItemClothing)
            bool isArmor = currentItem.HasKeyword(VendorItemArmor)
            bool isJewelry = currentItem.HasKeyword(VendorItemJewelry)
            bool isQuestItem = False

            ; If !sortQuestItems ; If quest item sorting is disabled, detect quest items
            ;     If !isFavorited && !isEquipped && !equippedRight && !equippedLeft ; ... Unless they're equipped or favorited
            ;         PlayerRef.RemoveItem(currentItem, 1, True, aaBennyShelterQuestItemChestRef)
            ;         aaBennyShelterQuestItemChestRef.RemoveAllItems(aaBennyShelterQuestItemReturnChestRef, abRemoveQuestItems = False)
            ;         Int questItemCount = aaBennyShelterQuestItemChestRef.GetItemCount(currentItem)
            ;         If questItemCount > 0
            ;             aaBennyShelterQuestItemChestRef.RemoveAllItems(aaBennyShelterQuestItemReturnChestRef, abRemoveQuestItems = True)
            ;             isQuestItem = True
            ;         EndIf
            ;     EndIf
            ; EndIf

            If !isQuestItem ; If quest item sorting is allowed, this will always be false
                If currentItem == Gold001 ; Gold Sorting
                    If sortGold
                        PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterGoldStrongboxRef)
                        Sorted = True
                    EndIf
                ElseIf currentItem == SaltPile ; Salt Sorting
                    If sortIngredient
                        PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterSaltContainerRef)
                        Sorted = True
                    EndIf
                ElseIf currentItem == DwarvenCenturionDynamo ; Centurion Dynamo Sorting
                    If sortClutter
                        PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterCenturionContainerRef)
                        Sorted = True
                    EndIf
                ElseIf currentItem == BYOHFoodFlour ; Flour Sorting
                    If sortFood
                        PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterFlourChestRef)
                        Sorted = True
                    EndIf
                ElseIf aaBennyConstructList.HasForm(currentItem) ; Construct cubes sorting
                    If !isFavorited
                        PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterConstructBarrelRef)
                        Sorted = True
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemOreIngot) ; Ore/Ingots Sorting
                    If sortOre
                        If aaBennyOreList.HasForm(currentItem)
                            PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterOreChestRef)
                            Sorted = True
                        Else
                            PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterIngotChestRef)
                            Sorted = True
                        EndIf
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemBook) && !currentItem.HasKeyword(VendorItemScroll) ; Book Sorting
                    If aaBennySortBook.GetValueInt() > 0
                        If aaBennyRecipesList.HasForm(currentItem) || currentItem.HasKeyword(VendorItemRecipe)
                            PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterRecipeChestRef)
                            Sorted = True
                        Else
                            PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterBookChestRef)
                            Sorted = True
                        EndIf
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemFood) || currentItem.HasKeyword(VendorItemFoodRaw) ; Food Sorting
                    If sortFood
                        If !isFavorited
                            If aaBennyLiquorList.HasForm(currentItem)
                                PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterLiquorChestRef)
                                Sorted = True
                            ElseIf aaBennyCheeseList.HasForm(currentItem)
                                PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterCheeseChestRef)
                                Sorted = True
                            ElseIf aaBennyCookedMeatsList.HasForm(currentItem)
                                PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterCookedMeatBarrelRef)
                                Sorted = True
                            ElseIf aaBennyRawMeatsList.HasForm(currentItem)
                                PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterRawMeatBarrelRef)
                                Sorted = True
                            ElseIf aaBennyFruitsVegetablesList.HasForm(currentItem)
                                PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterVegetablesBarrelRef)
                                Sorted = True
                            ElseIf aaBennySoupsList.HasForm(currentItem)
                                PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterStewBarrelRef)
                                Sorted = True
                            ElseIf !currentItem.HasKeyword(VendorItemFoodRaw)
                                PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterCookedFoodBarrelRef)
                                Sorted = True
                            Else
                                PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterRawFoodBarrelRef)
                                Sorted = True
                            EndIf
                        EndIf
                    EndIf
                ElseIf isClothing || isArmor && !isJewelry ; Armor Sorting
                    If sortArmor
                        If !isFavorited
                            If !isEquipped
                                If sortClothing && isClothing && !isArmor
                                    PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterClothingChestRef)
                                    Sorted = True
                                Else
                                    PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterArmorChestRef)
                                    Sorted = True
                                EndIf
                            EndIf
                        EndIf
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemWeapon) ; Weapon Sorting
                    If sortWeapons
                        If !isFavorited
                            If !equippedRight && !equippedLeft
                                PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterWeaponChestRef)
                                Sorted = True
                            EndIf
                        EndIf
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemArrow) ; Ammo Sorting
                    If sortAmmo
                        If !isFavorited
                            If !isEquipped
                                PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterAmmoChestRef)
                                Sorted = True
                            EndIf
                        EndIf
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemGem) ; Gem Sorting
                    If sortGem
                        PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterGemStrongboxRef)
                        Sorted = True
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemSoulGem) ; Soul Gem Sorting
                    If sortSoulGem
                        PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterSoulgemStrongboxRef)
                        Sorted = True
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemIngredient) ; Ingredient Sorting
                    If sortIngredient
                        PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterIngredientStrongboxRef)
                        Sorted = True
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemStaff) ; Staff Sorting
                    If sortWeapons
                        If !isFavorited
                            If !equippedRight && !equippedLeft
                                PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterWeaponChestRef)
                                Sorted = True
                            EndIf
                        EndIf
                    EndIf
                ElseIf isJewelry ; Jewelry Sorting
                    If sortJewelry
                        If !isFavorited
                            If !isEquipped
                                PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterJewelryStrongboxRef)
                                Sorted = True
                            EndIf
                        EndIf
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemPoison) ; Poison Sorting
                    If sortPoisons
                        If !isFavorited
                            PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterPoisonChestRef)
                            Sorted = True
                        EndIf
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemPotion) ; Potion Sorting
                    If sortPotions
                        If !isFavorited
                            PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterPotionChestRef)
                            Sorted = True
                        EndIf
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemScroll) ; Scroll Sorting
                    If sortScroll
                        If !isFavorited
                            PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterScrollStrongboxRef)
                            Sorted = True
                        EndIf
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemClutter) || currentItem.HasKeyword(BYOHHouseCraftingCategorySmithing) ; Clutter Sorting
                    If sortClutter
                        PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterMiscChestRef)
                        Sorted = True
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemFirewood)
                    If sortFirewood
                        PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterFirewoodChestRef)
                        Sorted = True
                    EndIf
                ElseIf currentItem.HasKeyword(VendorItemAnimalHide) || currentItem.HasKeyword(VendorItemAnimalPart)
                    If sortLeather
                        PlayerRef.RemoveItem(currentItem, currentItemCount, True, aaBennyShelterLeatherChestRef)
                        Sorted = True
                    EndIf
                Else
                    Debug.Trace("[Benny'sShelter] Item " + currentItem.GetName() + " did not match any sorting criteria.")
                    Sorted = False
                EndIf
            EndIf
            If Sorted
                ItemsSorted += currentItemCount
                Debug.Trace("[Benny'sShelter] Sorted " + currentItemCount + " of " + currentItem.GetName())
            Else
                Debug.Trace("[Benny'sShelter] Did not sort " + currentItemCount + " of " + currentItem.GetName())
            EndIf
            i += 1
        EndWhile
        aaBennySortingComplete.Show(ItemsSorted)
        aaBennyIsSorting.SetValueInt(0)
        GoToState("NotSorting")
    EndEvent
EndState

State Sorting
    Event OnActivate(ObjectReference akActionRef)
        aaBennySortingBusy.Show()
    EndEvent
EndState