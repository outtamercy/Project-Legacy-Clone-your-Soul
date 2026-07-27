Scriptname BennyShelterSwitchesScript extends ObjectReference

ObjectReference[] Property SwitchedOnRefs Auto
ObjectReference[] Property SwitchedOffRefs Auto
GlobalVariable Property ControlVariable Auto
Bool Property FadeInOut Auto

Event OnLoad()
    UpdateReferences()
EndEvent

Event OnActivate(ObjectReference akActionRef)
    If ControlVariable.GetValueInt() == 0
        ControlVariable.SetValueInt(1)
    Else
        ControlVariable.SetValueInt(0)
    EndIf
    UpdateReferences()
EndEvent

Function UpdateReferences()
    bool isEnabled = ControlVariable.GetValueInt() > 0
    If isEnabled
        int count = SwitchedOnRefs.Length
        int i = 0
        While i < count
            SwitchedOnRefs[i].Enable(FadeInOut)
            i += 1
        EndWhile
        i = 0
        count = SwitchedOffRefs.Length
        While i < count
            SwitchedOffRefs[i].Disable(FadeInOut)
            i += 1
        EndWhile
    Else
        int count = SwitchedOffRefs.Length
        int i = 0
        While i < count
            SwitchedOffRefs[i].Enable(FadeInOut)
            i += 1
        EndWhile
        i = 0
        count = SwitchedOnRefs.Length
        While i < count
            SwitchedOnRefs[i].Disable(FadeInOut)
            i += 1
        EndWhile
    EndIf
EndFunction