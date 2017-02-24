@ECHO OFF
::
::   Name: maintenance.cmd
::   Author: White Star Software
::   Date: 25 January 2017
::
::   Purpose: Create an outage on the ProTop Dashboard
::
::
::   Parameters: Action: "On", "Off", "Status"
::               Length: N (Length of outage in hours if arg1 = "on")
::

:: Delay variable expansion to runtime

Setlocal EnableDelayedExpansion

:: Grab environment vars

IF NOT EXIST "%PROTOP%\bin\protopenv.bat" (
   echo Unable to locate %PROTOP%\bin\protopenv.bat
   GOTO :ABEND
)

CALL "%PROTOP%\bin\protopenv.bat"

:: VARIABLES

:: Switch these around for normal use
::SET EKKO=echo
SET EKKO=

SET AND=IF
SET MLOG="%LOGDIR%\maintenance.log"
SET MFLAG="%TMPDIR%\MAINTENANCE"
SET "USAGE1=Usage: maintenance.cmd 'on' n ^(Hours^)^|off^|status"
SET "USAGE2=   ie: maintenance.cmd on 3"
SET "USAGE3=       maintenance.cmd off"
SET "USAGE4=       maintenance.cmd status"

::   Process Parameters

IF "%1" == "" (
   CALL :SUB_USAGE
   GOTO :ABEND
)

SET ACTION=%1

IF NOT "%ACTION%"=="on" %AND% NOT "%ACTION%"=="off" %AND% NOT "%ACTION%"=="status" (
   CALL :SUB_USAGE
   GOTO :ABEND
)

IF "%ACTION%"=="on" (

   IF "%2"=="" (
      CALL :SUB_USAGE
      GOTO :ABEND
   )
   echo %2| findstr /r "^[1-9][0-9]*$">NUL

   IF NOT %errorlevel% equ 0 (
      echo "Error: Duration must be a positive integer"
      GOTO :ABEND
    )
   SET DURATION=%2
)

cd "%PROTOP%"

IF NOT EXIST "%TMPDIR%" md "%TMPDIR%"
IF NOT EXIST "%LOGDIR%" md "%LOGDIR%"

IF NOT EXIST "%PROTOP%\etc\custid.cfg" (
   echo "Error: Cannot find custid.cfg - exiting"
   GOTO :ABEND
)

FOR %%a in ("%PROTOP%\etc\custid.cfg") do if %%~za equ 0 (
   echo "Error: custid.cfg = 0 bytes"
   GOTO :ABEND
)

FOR /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c.%%a.%%b)
FOR /f "tokens=1-2 delims=/:" %%a in ("%TIME%") do (set mytime=%%a.%%b)

SET NOW=%mydate% %mytime%
SET /P CUSTID=<"%PROTOP%\etc\custid.cfg"
  
:: Now start to process the actual commands.

:: Redirection at the beginning of the line avoids trailing space going to stdout


IF "%ACTION%"=="on" (

   echo %NOW% %DURATION% > %MFLAG%
   echo %NOW% ON %DURATION% >>%MLOG% 

   ECHO Commencing Maintenance Mode for %DURATION% hours

   del /s "%TMPDIR%\*.flg" >NUL 2>&1

   set QSTR=sitename^=%CUSTID%^&dbIdList^=all^&description^=Created^+by^+maintenance.cmd
   
   set QSTR=!QSTR!^&duration=%DURATION%^&oper=add^&req=maintenance

   >>%MLOG% echo curl -X POST --data "!QSTR!" %PTHOST%/cgi-bin/pt3admin.cgi 2>&1
   >>%MLOG% %EKKO% curl -X POST --data "!QSTR!" %PTHOST%/cgi-bin/pt3admin.cgi 2>&1

   GOTO END
)


IF "%ACTION%"=="off" (

   IF NOT EXIST %MFLAG% (
      echo Maintenance mode is already off
      GOTO :END
   )

   ECHO Ending Maintenance Mode, restarting protop agents

   %EKKO% DEL %MFLAG% >>%MLOG%


   IF EXIST %MFLAG% (
      echo Failed! Maintenance Mode is still on
      GOTO :ABEND
   )

   >>%MLOG% echo %NOW% OFF

   set QSTR=sitename=%CUSTID%^&oper=del^&req=maintenance

   >>%MLOG% echo curl -X DELETE --data "!QSTR!" %PTHOST%/cgi-bin/pt3admin.cgi 2>&1

   >>%MLOG% %EKKO% curl -X DELETE --data "!QSTR!" %PTHOST%/cgi-bin/pt3admin.cgi 2>&1

   GOTO END
)


IF "%ACTION%"=="status" (
 
   IF EXIST %MFLAG% (
      SET /P TMP=<%MFLAG%
      echo Maintenance Mode has been on since !TMP!
      GOTO :END
   )

   echo Maintenance Mode is OFF
   GOTO END
)

GOTO :END

:SUB_USAGE
   ECHO.
   ECHO %USAGE1% 
   ECHO %USAGE2%  
   ECHO %USAGE3%
   ECHO %USAGE4%
   ECHO.
   EXIT /B

:ABEND

:END
