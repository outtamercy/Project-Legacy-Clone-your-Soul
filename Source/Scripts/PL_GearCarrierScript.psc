Scriptname PL_GearCarrierScript extends Actor
; backstop cleanup for gear-FX carriers. the station's spline handler owns
; primary deletion, but a blocked SplineTranslateToRef never returns, and
; the handler thread (and the carrier) would live forever. this timer is
; independent: whatever happens, the carrier is gone within 10 seconds.

Event OnLoad()
    RegisterForSingleUpdate(10.0)
EndEvent

Event OnUpdate()
    self.Delete()
EndEvent
