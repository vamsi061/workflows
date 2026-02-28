@echo off
title WSL Docker + Nginx + n8n + MinIO + NCA Toolkit + Kokoro Setup

echo ========================================
echo  WSL Docker + Nginx + AI Stack Server
echo ========================================
echo.

REM ----------------------------------------
REM Check Admin
REM ----------------------------------------

net session >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
 echo ERROR: Run as Administrator
 pause
 exit /b
)

echo Administrator OK ✓
echo.

REM ----------------------------------------
REM Install WSL if Missing
REM ----------------------------------------

echo Checking WSL...

wsl --status >nul 2>&1

IF %ERRORLEVEL% NEQ 0 (

 echo Installing WSL...

 wsl --install -d Ubuntu-24.04

 echo.
 echo Restart PC and run script again.
 pause
 exit /b
)

echo WSL Installed ✓
echo.

REM ----------------------------------------
REM Disable IIS
REM ----------------------------------------

sc query W3SVC >nul 2>&1

IF %ERRORLEVEL% EQU 0 (
 net stop W3SVC >nul 2>&1
 sc config W3SVC start= disabled >nul 2>&1
 net stop IISADMIN >nul 2>&1
 sc config IISADMIN start= disabled >nul 2>&1
)

echo IIS Checked ✓
echo.

REM ----------------------------------------
REM Enable WSL Forwarding
REM ----------------------------------------

echo [wsl2]> "%USERPROFILE%\.wslconfig"
echo localhostForwarding=true>> "%USERPROFILE%\.wslconfig"

echo WSL forwarding enabled ✓
echo.

REM ----------------------------------------
REM Firewall
REM ----------------------------------------

netsh advfirewall firewall add rule name="WSL80" dir=in action=allow protocol=TCP localport=80 >nul 2>&1
netsh advfirewall firewall add rule name="WSL5678" dir=in action=allow protocol=TCP localport=5678 >nul 2>&1
netsh advfirewall firewall add rule name="WSL9000" dir=in action=allow protocol=TCP localport=9000 >nul 2>&1
netsh advfirewall firewall add rule name="WSL9001" dir=in action=allow protocol=TCP localport=9001 >nul 2>&1
netsh advfirewall firewall add rule name="WSL8080" dir=in action=allow protocol=TCP localport=8080 >nul 2>&1
netsh advfirewall firewall add rule name="WSL8880" dir=in action=allow protocol=TCP localport=8880 >nul 2>&1

echo Firewall OK ✓
echo.

REM ----------------------------------------
REM Restart WSL
REM ----------------------------------------

wsl --shutdown
timeout /t 5 >nul

echo WSL Restarted ✓
echo.

REM ----------------------------------------
REM Install Ubuntu if Missing
REM ----------------------------------------

echo Checking Ubuntu-24.04...

wsl -d Ubuntu-24.04 echo OK >nul 2>&1

IF %ERRORLEVEL% NEQ 0 (

 echo Installing Ubuntu-24.04...

 wsl --install -d Ubuntu-24.04

 echo.
 echo Ubuntu installed.
 echo Restart PC and run script again.
 pause
 exit /b

)

echo Ubuntu OK ✓
echo.

REM ----------------------------------------
REM Install Packages
REM ----------------------------------------

echo Installing Docker + Nginx...

wsl -d Ubuntu-24.04 --exec bash -c "
sudo apt update &&
sudo apt install -y docker.io nginx git
"

echo Packages Installed ✓
echo.

REM ----------------------------------------
REM Start Services
REM ----------------------------------------

wsl -d Ubuntu-24.04 --exec bash -c "
sudo service docker restart
sudo service nginx restart
"

echo Services Running ✓
echo.

REM ----------------------------------------
REM n8n Setup
REM ----------------------------------------

echo Setting up n8n...

wsl -d Ubuntu-24.04 --exec bash -c "
mkdir -p ~/.n8n &&
sudo chown -R 1000:1000 ~/.n8n
"

wsl -d Ubuntu-24.04 --exec bash -c "docker inspect n8n > /dev/null 2>&1"

IF %ERRORLEVEL% EQU 0 (

 echo Starting n8n...

 wsl -d Ubuntu-24.04 --exec bash -c "docker start n8n"

) ELSE (

 echo Creating n8n...

 wsl -d Ubuntu-24.04 --exec bash -c "
docker run -d ^
--name n8n ^
-p 5678:5678 ^
-e N8N_SECURE_COOKIE=false ^
-e N8N_HOST=0.0.0.0 ^
-v ~/.n8n:/home/node/.n8n ^
--restart always ^
n8nio/n8n
"

)

echo n8n Ready ✓
echo.

REM ----------------------------------------
REM MinIO Setup
REM ----------------------------------------

echo Setting up MinIO...

wsl -d Ubuntu-24.04 --exec bash -c "
mkdir -p ~/minio-data &&
sudo chown -R 1000:1000 ~/minio-data
"

wsl -d Ubuntu-24.04 --exec bash -c "docker inspect minio > /dev/null 2>&1"

IF %ERRORLEVEL% EQU 0 (

 wsl -d Ubuntu-24.04 --exec bash -c "docker start minio"

) ELSE (

 wsl -d Ubuntu-24.04 --exec bash -c "
docker run -d ^
--name minio ^
-p 9000:9000 ^
-p 9001:9001 ^
-e MINIO_ROOT_USER=admin ^
-e MINIO_ROOT_PASSWORD=password ^
-v ~/minio-data:/data ^
--restart always ^
minio/minio server /data --console-address :9001
"

)

echo MinIO Ready ✓
echo.

REM ----------------------------------------
REM NCA Toolkit Setup
REM ----------------------------------------

echo Setting up NCA Toolkit...

wsl -d Ubuntu-24.04 --exec bash -c "docker inspect nca-toolkit > /dev/null 2>&1"

IF %ERRORLEVEL% EQU 0 (

 wsl -d Ubuntu-24.04 --exec bash -c "docker start nca-toolkit"

) ELSE (

 wsl -d Ubuntu-24.04 --exec bash -c "
docker run -d ^
--name nca-toolkit ^
-p 8080:8080 ^
-e API_KEY=localdev123 ^
--restart always ^
nca-toolkit-local
"

)

echo NCA Toolkit Ready ✓
echo.

REM ----------------------------------------
REM Kokoro Setup
REM ----------------------------------------

echo Setting up Kokoro...

wsl -d Ubuntu-24.04 --exec bash -c "docker inspect kokoro > /dev/null 2>&1"

IF %ERRORLEVEL% EQU 0 (

 wsl -d Ubuntu-24.04 --exec bash -c "docker start kokoro"

) ELSE (

 wsl -d Ubuntu-24.04 --exec bash -c "
docker pull ghcr.io/remsky/kokoro-fastapi-cpu:v0.2.2 &&
docker run -d ^
--name kokoro ^
-p 8880:8880 ^
--restart always ^
ghcr.io/remsky/kokoro-fastapi-cpu:v0.2.2
"

)

echo Kokoro Ready ✓
echo.

REM ----------------------------------------
REM Port Forwarding
REM ----------------------------------------

for /f %%i in ('wsl hostname -I') do set WSLIP=%%i

netsh interface portproxy reset

netsh interface portproxy add v4tov4 listenport=5678 listenaddress=0.0.0.0 connectport=5678 connectaddress=%WSLIP%
netsh interface portproxy add v4tov4 listenport=9000 listenaddress=0.0.0.0 connectport=9000 connectaddress=%WSLIP%
netsh interface portproxy add v4tov4 listenport=9001 listenaddress=0.0.0.0 connectport=9001 connectaddress=%WSLIP%
netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=8080 connectaddress=%WSLIP%
netsh interface portproxy add v4tov4 listenport=8880 listenaddress=0.0.0.0 connectport=8880 connectaddress=%WSLIP%

echo Forwarding Ready ✓
echo.

echo ========================================
echo SERVER READY ✓
echo ========================================

start http://localhost
start http://localhost:5678
start http://localhost:9001
start http://localhost:8080
start http://localhost:8880

pause
