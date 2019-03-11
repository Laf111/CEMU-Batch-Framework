Option Explicit

Dim strPath, objArgs, messageText

Set objArgs = WScript.Arguments

' message
messageText = objArgs(0)

strPath = SelectFolder( "", messageText )
If strPath = vbNull Then
    WScript.Echo """NONE"""
Else
    WScript.Echo """" & Replace(strPath," ","?") & """"
End If

Function SelectFolder( myStartFolder, messageText )
' This function opens a "Select Folder" dialog and will
' return the fully qualified path of the selected folder
'
' Argument:
'     myStartFolder    [string]    the root folder where you can start browsing;
'                                  if an empty string is used, browsing starts
'                                  on the local computer
'
' Returns:
' A string containing the fully qualified path of the selected folder


    ' Standard housekeeping
    Dim objFolder, objItem, objShell
    
    ' Custom error handling
    On Error Resume Next
    SelectFolder = vbNull

    ' Create a dialog object
    
    
    Set objShell  = CreateObject( "Shell.Application" )
    Set objFolder = objShell.BrowseForFolder( 0, messageText, 0, myStartFolder )
    
    ' Return the path of the selected folder
    If IsObject( objfolder ) Then SelectFolder = objFolder.Self.Path

    ' Standard housekeeping
    Set objFolder = Nothing
    Set objshell  = Nothing
    On Error Goto 0
End Function