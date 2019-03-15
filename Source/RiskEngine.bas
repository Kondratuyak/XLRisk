Attribute VB_Name = "RiskEngine"
Option Explicit
Option Base 1

Public UserStopped As Boolean
Dim SimError As Boolean
Dim SimErrorMsg As String

Public Sub SimIteration(Iter As Integer, RiskInputs As Collection, RiskOutputs As Collection, OutSheet As Worksheet)
    Dim R As Range
    Dim Cell As Range
    Dim Item As Variant
      
    On Error GoTo SSError
        
    'Recalculate
    Application.Calculate
      
    'Produce Output
    Set R = OutSheet.Range("A3").Offset(Iter)
    R = Iter
    Set R = R.Offset(0, 1)
    ' Inputs
    For Each Cell In RiskInputs
        R = Cell
        Set R = R.Offset(0, 1)
    Next Cell
    
    'Outputs
    For Each Item In RiskOutputs
        R = Item(2)
        Set R = R.Offset(0, 1)
    Next Item
    Exit Sub
SSError:
      SimError = True
  SimErrorMsg = "Error in simulation iteration"
End Sub

Public Sub Simulate()
    Dim OutSheet As Worksheet
    Dim AppCalculation
    Dim RiskInputs As Collection
    Dim RiskOutputs As Collection
    Dim XLRisk As Worksheet
    Dim Iterations As Integer
    Dim Iter As Integer
    Dim OldProduceRandomSample As Boolean
    Dim Seed As Double
    
    ' Save Calculation Mode
    AppCalculation = Application.Calculation
    Application.Calculation = xlCalculationManual
    
    ' Save ProduceRandomSample
    OldProduceRandomSample = ProduceRandomSample
    
    On Error GoTo RestoreExcel
        
    Set XLRisk = SetUpXLRisk
    '  Stop Screen Updating?
    Application.ScreenUpdating = XLRisk.Range("ScreenUpdate")
    Application.Cursor = xlWait
    
    Iterations = XLRisk.Range("Iterations")
    
    Set OutSheet = CreateOutputSheet
    
    Set RiskInputs = New Collection
    CollectRiskInputs RiskInputs
    If RiskInputs.Count = 0 Then
        MsgBox "No risk inputs defined", Title:="XLRisk simulation error"
        GoTo RestoreExcel
    End If
    
    Set RiskOutputs = New Collection
    CollectRiskOutputs RiskOutputs
    If RiskOutputs.Count = 0 Then
        MsgBox "No risk outputs defined", Title:="XLRisk simulation error"
        GoTo RestoreExcel
    End If
        
    InitialiseResults RiskInputs, RiskOutputs, OutSheet
    
    'Randomize
    Seed = XLRisk.Range("Seed")
    If Seed <> 0 Then
        'https://stackoverflow.com/questions/16589180/visual-basic-random-number-with-seed-but-in-reverse
        Rnd (-1)
        Randomize (Seed)
    Else
        Randomize
    End If
    
    'Perform simulation
    UserStopped = False
    ProduceRandomSample = True
    For Iter = 1 To Iterations
        If SimError Then
            SimError = False
            MsgBox SimErrorMsg
            Exit For
        End If
        SimIteration Iter, RiskInputs, RiskOutputs, OutSheet
        DoEvents
        'Check whether to Stop
        If UserStopped Then
            UserStopped = False
            MsgBox "The simulation was interrupted"
            Exit For
        End If
        Application.StatusBar = "Iteration: " & CStr(Iter) & "/" & CStr(Iterations)
    Next Iter
    
    OutSheet.Range("A3").CurrentRegion.Columns.AutoFit
    ProduceStatistics Iterations, RiskInputs, RiskOutputs, OutSheet
    OutSheet.Activate
RestoreExcel:
    'Restore Calculation Mode
    Application.Calculation = AppCalculation
    Application.Calculate
    
    ' Restore Status Bar
    Application.StatusBar = False
    
    'Restore ProduceRandomSample
    ProduceRandomSample = OldProduceRandomSample
    
    Application.ScreenUpdating = True
    Application.Cursor = xlDefault
End Sub


Public Sub InitialiseResults(RiskInputs As Collection, RiskOutputs As Collection, WS As Worksheet)
    Dim ER, OutRanges, OutRange As Range
    Dim Cell As Range
    Dim Curr As Range
    Dim I As Integer
    
    With WS
        .Range("B1") = "Inputs"
        .Range("A3") = "Iterations"
    End With
      
    '  Setup risk inputs
    Set Curr = WS.Range("B2")
    For Each Cell In RiskInputs
        Curr = "'" & Cell.Parent.Name & "'!" & Cell.Address
        Curr.Offset(1, 0) = Right(Cell.Formula, Len(Cell.Formula) - 1)
        Set Curr = Curr.Offset(0, 1)
    Next Cell
    'Format Input
    With Range(WS.Range("B1"), WS.Range("B1").Offset(0, RiskInputs.Count - 1))
        If RiskInputs.Count > 1 Then .Merge
        .Font.Bold = True
        .HorizontalAlignment = xlCenter
    End With
    
    '   Setup risk outputs
    Curr.Offset(-1, 0) = "Outputs"
    Curr.Offset(2).Name = "OutputResults"
    For I = 1 To RiskOutputs.Count
        Set Cell = RiskOutputs(I)(2)
        Curr = "'" & Cell.Parent.Name & "'!" & Cell.Address
        Curr.Offset(1, 0) = RiskOutputs(I)(1)
        Set Curr = Curr.Offset(0, 1)
    Next I
    'Format Output
    With Range(WS.Range("B1").Offset(0, 1), WS.Range("B1").Offset(0, RiskOutputs.Count))
        If RiskOutputs.Count > 1 Then .Merge
        .Font.Bold = True
        .HorizontalAlignment = xlCenter
    End With
    
    '   Setup Simulation Statistics
    Set Curr = Curr.Offset(0, 2)
    Curr.Offset(-1, 0) = "Simulation Statistics"
    Curr.Offset(2, -1).Name = "SimStats"
    For I = 1 To RiskOutputs.Count
        Set Cell = RiskOutputs(I)(2)
        Curr = "'" & Cell.Parent.Name & "'!" & Cell.Address
        Curr.Offset(1, 0) = RiskOutputs(I)(1)
        Set Curr = Curr.Offset(0, 1)
    Next I
    'Format Simulation Results
    With Range(WS.Range("SimStats").Offset(-3), WS.Range("SimStats").Offset(-3, RiskOutputs.Count))
        If RiskOutputs.Count > 1 Then .Merge
        .Font.Bold = True
        .HorizontalAlignment = xlCenter
    End With
    
    With WS.Range("B2").CurrentRegion
        .Columns.AutoFit
        .HorizontalAlignment = xlCenter
    End With
End Sub

Sub StatHelper(Cell As Range, StatName As String, StatFormula As String, Address As String, Count As Integer)
    Dim I As Integer
    
    Cell = StatName
    Cell.Offset(0, 1).Formula = "=" & StatFormula & "(" & Address & ")"
End Sub

Sub ProduceStatistics(Iterations As Integer, RiskInputs As Collection, RiskOutputs As Collection, OutSheet As Worksheet)
    Dim FirstOutput As Range
    Dim Cell As Range
    Dim I As Integer
    Dim Address As String
    Dim Count As Integer
    Dim Perc As Integer
    Dim PCount As Integer
    
    Set Cell = OutSheet.Range("OutputResults")
    Set FirstOutput = OutSheet.Range(Cell, Cell.Offset(Iterations - 1))
    Set Cell = OutSheet.Range("SimStats")
    
    Address = FirstOutput.Address(False, False)
    Count = RiskOutputs.Count
    StatHelper Cell, "Mean", "Average", Address, Count
    StatHelper Cell.Offset(1), "Median", "MEDIAN", Address, Count
    StatHelper Cell.Offset(2), "Mode", "MODE.SNGL", Address, Count
    StatHelper Cell.Offset(3), "Std. Deviation", "STDEV.S", Address, Count
    StatHelper Cell.Offset(4), "Variance", "VAR.S", Address, Count
    StatHelper Cell.Offset(5), "Kurtosis", "KURT", Address, Count
    StatHelper Cell.Offset(6), "Skewness", "Skew", Address, Count
    StatHelper Cell.Offset(7), "Minimum", "MIN", Address, Count
    StatHelper Cell.Offset(8), "Maximum", "MAX", Address, Count
    Cell.Offset(9) = "Range"
    Cell.Offset(9, 1).Formula = "=" & Cell.Offset(8, 1).Address(False, False) & "-" & Cell.Offset(7, 1).Address(False, False)
    StatHelper Cell.Offset(10), "Count", "Count", Address, Count
    Cell.Offset(11) = "Error Count"
    Cell.Offset(11, 1).FormulaArray = "=COUNT(IF(ISERROR(" & Address & "), 1, """"))"
    Cell.Offset(12) = "Std. Error"
    Cell.Offset(12, 1).Formula = "=" & Cell.Offset(3, 1).Address(False, False) & "/SQRT(" & Cell.Offset(10, 1).Address(False, False) & ")"
    Cell.Offset(13) = "Confidence Level (95%)"
    Cell.Offset(13, 1).Formula = "=CONFIDENCE.T(5%," & Cell.Offset(3, 1).Address(False, False) & "," & Cell.Offset(10, 1).Address(False, False) & ")"
    If Count > 1 Then Range(Cell.Offset(0, 1), Cell.Offset(13, 1)).Copy Range(Cell.Offset(0, 2), Cell.Offset(13, Count))
    'Percentiles
    Cell.Offset(14) = "Percentiles"
    Perc = 0
    For PCount = 1 To 21
        Cell.Offset(14 + PCount) = Perc / 100
        Cell.Offset(14 + PCount).NumberFormat = "0%"
        Cell.Offset(14 + PCount).HorizontalAlignment = xlRight
        Cell.Offset(14 + PCount, 1).Formula = "=PERCENTILE.INC(" & Address & "," & CStr(Perc) & "%)"
        Perc = Perc + 5
    Next PCount
    If Count > 1 Then Range(Cell.Offset(15, 1), Cell.Offset(15 + 20, 1)).Copy Range(Cell.Offset(15, 2), Cell.Offset(15 + 20, Count))
    Cell.CurrentRegion.Columns.AutoFit
End Sub