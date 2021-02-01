Set objArgs = WScript.Arguments
Dim returnValue : returnValue = 0

' message
messageText = objArgs(0)

If (objArgs.Count = 1) Then
    createobject("wscript.shell").popup messageText, 20, "CEMU's BatchFw", 64
Else
    If (objArgs.Count = 2) Then
        critLevel = objArgs(1)
        If (critLevel = "pop8sec") Then
            createobject("wscript.shell").popup messageText, 8, "CEMU's BatchFw", 64
        Else
            ' critLevel values : 

            ' Constant              Value   Description
            ' -----------------------------------
            ' vbOKOnly              0       Display OK button only.
            ' vbOKCancel            1       Display OK and Cancel buttons.
            ' vbAbortRetryIgnore    2       Display Abort, Retry, and Ignore buttons.
            ' vbYesNoCancel         3       Display Yes, No, and Cancel buttons.
            ' vbYesNo               4       Display Yes and No buttons.
            ' vbRetryCancel         5       Display Retry and Cancel buttons.
            ' vbCritical            16      Display Critical Message icon.
            ' vbQuestion            32      Display Warning Query icon.
            ' vbExclamation         48      Display Warning Message icon.
            ' vbInformation         64      Display Information Message icon.
            ' vbDefaultButton1      0       First button is default.
            ' vbDefaultButton2      256     Second button is default.
            ' vbDefaultButton3      512     Third button is default.
            ' vbDefaultButton4      768     Fourth button is default.
            ' vbApplicationModal    0       Application modal. The user must respond to the message box before continuing work in the current application.
            ' vbSystemModal         4096    System modal. On Microsoft Win16 systems, all applications are suspended until the user responds to the message box. 
            '                               On Microsoft Win32 systems, this constant provides an application modal message box that always remains on top of any other programs that you have running
            '   
            ' ex : 
            '       vbOKOnly+vbCritical+vbSystemModal                                    = 4112
            '       vbOKOnly+vbQuestion+vbSystemModal                                    = 4128
            '       vbOKOnly+vbExclamation+vbSystemModal                                 = 4144
            '       vbOKOnly+vbInformation+vbSystemModal                                 = 4160
            '       
            '       vbRetryCancel+vbCritical+vbSystemModal                               = 4117   
            '       vbRetryCancel+vbCritical+vbSystemModal+vbDefaultButton2              = 4373
            '
            '       vbRetryCancel+vbQuestion+vbSystemModal                               = 4133   
            '       vbRetryCancel+vbQuestion+vbSystemModal+vbDefaultButton2              = 4389
            '
            '       vbRetryCancel+vbExclamation+vbSystemModal                            = 4149   
            '       vbRetryCancel+vbExclamation+vbSystemModal+vbDefaultButton2           = 4405
            '
            '       vbRetryCancel+vbInformation+vbSystemModal                            = 4165   
            '       vbRetryCancel+vbInformation+vbSystemModal+vbDefaultButton2           = 4421

            ' open msg box
            returnValue = MsgBox(messageText, critLevel, "CEMU's BatchFw")

            ' The MsgBox function has the following return values:
            ' 
            ' Constant    Value   Button
            ' --------------------------
            ' vbOK        1       OK
            ' vbCancel    2       Cancel
            ' vbAbort     3       Abort
            ' vbRetry     4       Retry
            ' vbIgnore    5       Ignore
            ' vbYes       6       Yes
            ' vbNo        7       No

        End If
    End If
End If

WScript.Quit(returnValue)

