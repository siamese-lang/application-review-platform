@REM Maven Wrapper launcher for Windows
@ECHO OFF
SETLOCAL
SET BASE_DIR=%~dp0
SET WRAPPER_JAR=%BASE_DIR%.mvn\wrapper\maven-wrapper.jar
SET WRAPPER_URL=https://repo.maven.apache.org/maven2/org/apache/maven/wrapper/maven-wrapper/3.3.4/maven-wrapper-3.3.4.jar

IF NOT EXIST "%WRAPPER_JAR%" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri '%WRAPPER_URL%' -OutFile '%WRAPPER_JAR%'"
  IF ERRORLEVEL 1 EXIT /B 1
)

java %JAVA_OPTS% -classpath "%WRAPPER_JAR%" "-Dmaven.multiModuleProjectDirectory=%BASE_DIR%" org.apache.maven.wrapper.MavenWrapperMain %*
ENDLOCAL
