@ECHO OFF

IF EXIST "%JOB_NAME%build.properties" ( ECHO "#build properties file" > %JOB_NAME%build.properties )

SET PDT_NAME=lol
IF "%DEV_LINE%" == "trunk" (
     SET BUILD_OBJ=%JOB_NAME%
)ELSE (
     SET BUILD_OBJ=%DEV_LINE:branches/=%
)

ECHO DEV_LINE=%DEV_LINE%
ECHO TEST_VERSION_PATH=%TEST_VERSION_PATH%
IF "%IS_RELEASEBUILD%" == "true" (
     setlocal enableDelayedExpansion
     SET BUILD_OBJ=%DEV_LINE:tags/=%
     echo.BUILD_OBJ is: !BUILD_OBJ!
     IF "%TEST_VERSION_PATH%" == "" (
          ECHO TAG_NAME=!BUILD_OBJ! >> %JOB_NAME%build.properties
     )ELSE (
             set search="\<[0-9]*-[0-9]*-r[0-9]*\>"
             call :split "%TEST_VERSION_PATH%"
     )
     goto :end
)

:split
set list=%1
FOR /F  "tokens=1* delims=/\" %%A IN (%list%) DO (
     echo %%A
     set val=%%A
     setlocal enableDelayedExpansion
     echo !val!|findstr /r /c:"!search!" >nul && (
          echo FOUND
          set buildversion=!val!
          ECHO.buildversion is: !buildversion!
          FOR /F "tokens=2 delims=-" %%J IN ("!buildversion!") DO (
               IF "%%J" == "" exit 1
               set buildnum=%%J
          )
          ECHO.buildnum is: !buildnum!
          ECHO RELEASE_VERSION=!buildnum! >> %JOB_NAME%build.properties
          ECHO TAG_NAME=LOL_!buildnum!_REL >> %JOB_NAME%build.properties
     ) || (
          echo NOT FOUND
          set buildversion=""
          IF NOT "%%B" == "" ( call :split "%%B")
     )
)

:end
ECHO BUILD_OBJ=%BUILD_OBJ% >> %JOB_NAME%build.properties
ECHO PDT_NAME=%PDT_NAME% >> %JOB_NAME%build.properties
