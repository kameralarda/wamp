@echo off
setlocal enabledelayedexpansion

:: Check for administrator privileges
NET FILE 1>NUL 2>NUL
if not %errorLevel% == 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -Verb RunAs -FilePath 'cmd' -ArgumentList '/c cd /d ""%~dp0"" && %~0'"
    exit /b
)

:: Configuration
set INSTALL_DIR=C:\WebStack
set APACHE_DIR=%INSTALL_DIR%\Apache24
set PHP_DIR=%INSTALL_DIR%\PHP
set MYSQL_DIR=%INSTALL_DIR%\MySQL
set PHPMYADMIN_DIR=%APACHE_DIR%\htdocs\phpmyadmin

set VC_REDIST_X86=https://aka.ms/vs/17/release/vc_redist.x86.exe
set VC_REDIST_X64=https://aka.ms/vs/17/release/vc_redist.x64.exe
set APACHE_URL=https://www.apachelounge.com/download/VS17/binaries/httpd-2.4.63-250207-win64-VS17.zip
set PHP_URL=https://windows.php.net/downloads/releases/php-8.4.4-Win32-vs17-x64.zip
set MYSQL_URL=https://dev.mysql.com/get/Downloads/MySQL-9.2/mysql-9.2.0-winx64.zip
set PHPMYADMIN_URL=https://files.phpmyadmin.net/phpMyAdmin/5.2.2/phpMyAdmin-5.2.2-all-languages.zip
set COMPOSER_URL=https://getcomposer.org/Composer-Setup.exe

:: Create installation directory
mkdir "%INSTALL_DIR%" 2>NUL

:: Download files
echo Downloading required files...
powershell -Command "Invoke-WebRequest -Uri '%VC_REDIST_X86%' -OutFile '%INSTALL_DIR%\vc_redist.x86.exe'"
powershell -Command "Invoke-WebRequest -Uri '%VC_REDIST_X64%' -OutFile '%INSTALL_DIR%\vc_redist.x64.exe'"
powershell -Command "Invoke-WebRequest -Uri '%APACHE_URL%' -OutFile '%INSTALL_DIR%\apache.zip'"
powershell -Command "Invoke-WebRequest -Uri '%PHP_URL%' -OutFile '%INSTALL_DIR%\php.zip'"
powershell -Command "Invoke-WebRequest -Uri '%MYSQL_URL%' -OutFile '%INSTALL_DIR%\mysql.zip'"
powershell -Command "Invoke-WebRequest -Uri '%PHPMYADMIN_URL%' -OutFile '%INSTALL_DIR%\phpmyadmin.zip'"
powershell -Command "Invoke-WebRequest -Uri '%COMPOSER_URL%' -OutFile '%INSTALL_DIR%\Composer-Setup.exe'"

:: Install VC Redistributables
echo Installing VC Redistributables...
start /wait %INSTALL_DIR%\vc_redist.x86.exe /install /quiet /norestart
start /wait %INSTALL_DIR%\vc_redist.x64.exe /install /quiet /norestart

:: Extract Apache
echo Installing Apache...
powershell -Command "Expand-Archive -Path '%INSTALL_DIR%\apache.zip' -DestinationPath '%APACHE_DIR%' -Force"

:: Extract PHP
echo Installing PHP...
powershell -Command "Expand-Archive -Path '%INSTALL_DIR%\php.zip' -DestinationPath '%PHP_DIR%' -Force"
copy "%PHP_DIR%\php.ini-development" "%PHP_DIR%\php.ini" /Y
echo Configuring PHP...
(
echo extension_dir="ext"
echo extension=curl
echo extension=gd
echo extension=mbstring
echo extension=mysqli
echo extension=pdo_mysql
echo extension=openssl
) >> "%PHP_DIR%\php.ini"

:: Configure Apache
echo Configuring Apache...
set PHP_INI_DIR=%PHP_DIR%
set PHP_MOD_DIR=%PHP_DIR%

(
echo LoadModule php_module "%PHP_DIR%\php8apache2_4.dll"
echo AddHandler application/x-httpd-php .php
echo PHPIniDir "%PHP_DIR%"
echo DocumentRoot "%APACHE_DIR%\htdocs"
echo ^<Directory "%APACHE_DIR%\htdocs"^>
echo     Options Indexes FollowSymLinks
echo     AllowOverride All
echo     Require all granted
echo ^</Directory^>
) >> "%APACHE_DIR%\conf\httpd.conf"

:: Install Apache service
echo Installing Apache service...
cd /d "%APACHE_DIR%\bin"
httpd.exe -k install
sc config Apache2.4 start= auto
net start Apache2.4

:: Install MySQL
echo Installing MySQL...
powershell -Command "Expand-Archive -Path '%INSTALL_DIR%\mysql.zip' -DestinationPath '%MYSQL_DIR%' -Force"

cd /d "%MYSQL_DIR%\bin"
mysqld --initialize-insecure --console
mysqld --install
net start mysql

:: Set MySQL root password (default: root)
echo Setting MySQL root password...
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';"

:: Install Composer
echo Installing Composer...
start /wait %INSTALL_DIR%\Composer-Setup.exe --install-directory="%INSTALL_DIR%" --quiet

:: Install phpMyAdmin
echo Installing phpMyAdmin...
powershell -Command "Expand-Archive -Path '%INSTALL_DIR%\phpmyadmin.zip' -DestinationPath '%PHPMYADMIN_DIR%' -Force"
rename "%PHPMYADMIN_DIR%\phpMyAdmin-5.2.2-all-languages" phpmyadmin
copy "%PHPMYADMIN_DIR%\config.sample.inc.php" "%PHPMYADMIN_DIR%\config.inc.php" /Y

:: Add to PATH
setx PATH "%PHP_DIR%;%MYSQL_DIR%\bin;%INSTALL_DIR%;%PATH%" /M

:: Restart Apache
echo Restarting Apache...
net stop Apache2.4
net start Apache2.4

:: Cleanup
del /q "%INSTALL_DIR%\*.zip" "%INSTALL_DIR%\*.exe"

echo Installation complete!
echo Apache: http://localhost/
echo phpMyAdmin: http://localhost/phpmyadmin
echo MySQL username: root | Password: root
echo PHP: %PHP_DIR%
echo MySQL: %MYSQL_DIR%
echo Composer installed in: %INSTALL_DIR%

start http://localhost
start http://localhost/phpmyadmin
