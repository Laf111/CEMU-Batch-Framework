@if (@this==@isBatch) @then
    @echo off
    setlocal enableextensions

    set "file=%~f1"
    if not exist "%file%" goto :eof

    cscript //nologo //e:jscript "%~f0" /file:"%file%"

    endlocal

    exit /b
@end
    var file = WScript.Arguments.Named.Item('file').replace(/\\/g,'\\\\');
    var wmi = GetObject('winmgmts:{impersonationLevel=impersonate}!\\\\.\\root\\cimv2')
    var files = new Enumerator(wmi.ExecQuery('Select Version from CIM_datafile where name=\''+file+'\''))

    while (!files.atEnd()){
        WScript.StdOut.WriteLine(files.item().Version);
        files.moveNext();
    };
    WScript.Quit(0)
