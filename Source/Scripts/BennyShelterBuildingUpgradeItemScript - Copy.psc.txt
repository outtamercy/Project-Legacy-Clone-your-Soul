Scriptname BennyShelterBuildingUpgradeItemScript extends ObjectReference

Actor Property PlayerRef Auto
MiscObject Property UpgradeItem Auto
ObjectReference[] Property ItemsToEnable Auto
ObjectReference[] Property ItemsToDisable Auto
GlobalVariable Property UpgradedVariable Auto

Event OnContainerChanged(ObjectReference akNewContainer, ObjectReference akOldContainer)
    If UpgradedVariable.GetValue() == 1
        ; Already upgraded, do nothing
        Return
    EndIf
    If akNewContainer == PlayerRef
        PlayerRef.RemoveItem(UpgradeItem, 1, True)
        UpgradedVariable.SetValue(1) ; Mark as upgraded before enable/disable, this prevents double upgrades
        int index = 0
        ; Enable items first (for floor reasons)
        While index < ItemsToEnable.Length
            ItemsToEnable[index].Enable()
            index += 1
        EndWhile
        index = 0
        ; Disable old items
        While index < ItemsToDisable.Length
            ItemsToDisable[index].Disable()
            index += 1
        EndWhile
    EndIf
EndEvent