Scriptname BennyShelterBedroomUpgradeScript extends ObjectReference

Actor Property PlayerRef Auto
ObjectReference Property aaBennyShelterOBedroomChest Auto
ObjectReference Property aaBennyShelterOBedroomEndTable Auto
ObjectReference Property aaBennyShelterOBedroomWardrobe Auto

ObjectReference Property aaBennyShelterNBedroomChest Auto
ObjectReference Property aaBennyShelterNBedroomEndTable Auto
ObjectReference Property aaBennyShelterNBedroomWardrobe Auto

Event OnContainerChanged(ObjectReference akNewContainer, ObjectReference akOldContainer)
    If akNewContainer == PlayerRef
        aaBennyShelterOBedroomChest.RemoveAllItems(aaBennyShelterNBedroomChest)
        aaBennyShelterOBedroomEndTable.RemoveAllItems(aaBennyShelterNBedroomEndTable)
        aaBennyShelterOBedroomWardrobe.RemoveAllItems(aaBennyShelterNBedroomWardrobe)
    EndIf
EndEvent