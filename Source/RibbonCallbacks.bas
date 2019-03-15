Attribute VB_Name = "RibbonCallbacks"
' Declarations generated by Custom UI Editor
Option Explicit

Private XLRiskRibbonUI As IRibbonUI
Private Running As Boolean

'Callback for customUI.onLoad
Sub OnRibbonLoad(ribbon As IRibbonUI)
    Set XLRiskRibbonUI = ribbon
End Sub


'Callback for BtnSetup onAction
Sub RibbonShowOptions(control As IRibbonControl)
  ShowOptions
  XLRiskRibbonUI.InvalidateControl "ComboIterations"
End Sub

'Callback for BtnSetup getEnabled
Sub RibbonGetEnabled(control As IRibbonControl, ByRef returnedVal)
    If control.ID = "BtnStop" Then
        returnedVal = Running
    Else
        returnedVal = Not Running
    End If
End Sub

'Callback for BtnSamples onAction
Sub RibbonShowSamples(control As IRibbonControl, pressed As Boolean)
  ProduceRandomSample = Not ProduceRandomSample
  Application.Calculate
End Sub

'Callback for BtnSamples getPressed
Sub RibbonShowSamplesGetPressed(control As IRibbonControl, ByRef returnedVal)
  returnedVal = ProduceRandomSample
End Sub

'Callback for BtnAddOutput onAction
Sub RibbonAddOutput(control As IRibbonControl)
  AddOutput
End Sub

'Callback for ComboIterations getText
Sub RibbonIterationsText(control As IRibbonControl, ByRef returnedVal)
    Dim XLRisk As Worksheet
     
    On Error Resume Next
    Err.Clear
    Set XLRisk = ActiveWorkbook.Worksheets("XLRisk")
    If Err = 0 Then
        returnedVal = CStr(XLRisk.Range("Iterations"))
    Else
        'XLRisk has not been setup
        returnedVal = 1000  'default
    End If
End Sub

'Callback for ComboIterations onChange
Sub RibbonSetIterations(control As IRibbonControl, text As String)
' Action for the AddOutput command button
    Dim XLRisk As Worksheet
    
    Set XLRisk = SetUpXLRisk
    On Error GoTo InvalidNumber
    XLRisk.Range("Iterations") = CInt(text)
    Exit Sub
InvalidNumber:
    MsgBox ("Invalid Number")
End Sub

' This is an auxialiary routine to force the update of the enabled state of the buttons
Sub DelayedSimulate()
    On Error Resume Next
    Simulate
    Running = False
    XLRiskRibbonUI.Invalidate
End Sub

'Callback for BtnRun onAction
Sub RibbonSimulate(control As IRibbonControl)
    On Error Resume Next
    Running = True
    XLRiskRibbonUI.Invalidate
    'Simulate
    Application.OnTime Now + TimeSerial(0, 0, 1), "DelayedSimulate"
    'Running = False
    'XLRiskRibbonUI.Invalidate
End Sub

'Callback for BtnStop onAction
Sub RibbonStopSim(control As IRibbonControl, pressed As Boolean)
    StopSim
End Sub

'Callback for BtnAbout onAction
Sub RibbonShowAboutBox(control As IRibbonControl)
  ShowAboutBox
End Sub

