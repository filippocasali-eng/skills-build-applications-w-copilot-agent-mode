@echo off
REM MarketPilot AI - build dell'APK di debug su Windows.
REM Requisiti: JDK 17+ (JAVA_HOME) e Android SDK (ANDROID_HOME o local.properties).
setlocal
cd /d "%~dp0\.."

if "%JAVA_HOME%"=="" (
  echo [ERRORE] JAVA_HOME non impostato. Installa Android Studio o un JDK 17 e imposta JAVA_HOME.
  exit /b 1
)
if not exist local.properties (
  if "%ANDROID_HOME%"=="" if "%ANDROID_SDK_ROOT%"=="" (
    if exist "%LOCALAPPDATA%\Android\Sdk" (
      echo sdk.dir=%LOCALAPPDATA:\=\\%\\Android\\Sdk> local.properties
      echo Creato local.properties con l'SDK di Android Studio.
    ) else (
      echo [ERRORE] Android SDK non trovato. Installa Android Studio oppure imposta ANDROID_HOME.
      exit /b 1
    )
  )
)

echo Compilazione ed esecuzione dei test unitari...
call gradlew.bat testDebugUnitTest :core:model:test :core:common:test :core:network:test :domain:indicators:test :domain:market:test :domain:scoring:test :domain:risk:test :domain:portfolio:test :domain:papertrading:test :domain:backtesting:test :data:providers:test
if errorlevel 1 (
  echo [ATTENZIONE] Alcuni test sono falliti: controlla i report in */build/reports/tests.
)

echo Creazione APK...
call gradlew.bat :app:assembleDebug
if errorlevel 1 (
  echo [ERRORE] Build fallita.
  exit /b 1
)
echo.
echo APK pronto: %CD%\app\build\outputs\apk\debug\app-debug.apk
echo Copialo sul telefono oppure: adb install -r app\build\outputs\apk\debug\app-debug.apk
endlocal
