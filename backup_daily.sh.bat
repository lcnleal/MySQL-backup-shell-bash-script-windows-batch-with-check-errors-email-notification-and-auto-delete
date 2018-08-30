@echo off
setlocal EnableDelayedExpansion
set dbUser=root
set dbPassword=123456
set backupDir="C:\BACKUP\DB\DIARIO"
set mysqldump="C:\Program Files (x86)\MySQL\MySQL Server 5.5\bin\mysqldump.exe"
set mysqlDataDir="C:\wamp\bin\mysql\mysql5.5.8\data"
set zip="C:\Program Files\7-Zip\7z.exe"
set mysql="C:\Program Files (x86)\MySQL\MySQL Server 5.5\bin\mysql.exe"
set sendEmailApp=C:\BACKUP\ROTINAS\sendEmail.exe
set emailUser=gdados@jaboatao.pe.gov.br
set emailPW=123@jaboatao
set toEmail=luciano.leal@jaboatao.pe.gov.br
set CAMINHO_PASTA_DIARIA=C:\BACKUP\DB\DIARIO
set MAX_DAYS=8
set PORT=3558

:: get date
for /F "tokens=2-4 delims=/ " %%i in ('date /t') do (
	set mm=%%i
	set dd=%%j
	set yy=%%k
)

:: get time
for /F "tokens=5-8 delims=:. " %%i in ('echo.^| time ^| find "current" ') do (
	set hh=%%i
	set mm=%%j
)

:: DATA ::
FOR /F "TOKENS=1-4* DELIMS=/" %%A IN ('DATE/T') DO (
 SET Year=%%C
 SET Month=%%B
 SET Day=%%A
)
FOR %%A IN (%Day%) DO SET Day=%%A
FOR %%A IN (%Month%) DO SET Month=%%A
FOR %%A IN (%Year%) DO SET Year=%%A

::set dirName=%yy%%mm%%dd%_%hh%%mm%
set dirName=db_mysql_%Year%-%Month%-%Day%
set LOG_DA_ROTINA=%backupDir%\%dirName%\logs\log-da-rotina.log
set RELATORIO=%backupDir%\%dirName%\logs\relatorio-da-rotina.log


:: switch to the "data" folder
pushd %mysqlDataDir%
echo %mysqlDataDir%
:: iterate over the folder structure in the "data" folder to get the databases

if not exist %backupDir%\%dirName%\ (
	mkdir %backupDir%\%dirName%\
)

if not exist %backupDir%\%dirName%\logs\ (
	mkdir %backupDir%\%dirName%\logs\
)

:: Excluindo backups antigos
::REMOVE OLD FILES 8 dias
:: set min age of files and folders to delete


:: remove files from %dump_path%
forfiles -p %CAMINHO_PASTA_DIARIA% -m *.* -d -%MAX_DAYS% -c "cmd  /c del /q @path"

:: remove sub directories from %dump_path%
forfiles -p %CAMINHO_PASTA_DIARIA% -d -%MAX_DAYS% -c "cmd /c IF @isdir == TRUE rd /S /Q @path"









echo #################### >> %LOG_DA_ROTINA%
echo Inicio Log da Rotina %Year%-%Month%-%Day%  >> %LOG_DA_ROTINA%
echo Relatorio do backup >> %RELATORIO%
echo[ >> %RELATORIO%
echo Inicio Log da Rotina %Year%-%Month%-%Day%  >> %RELATORIO%
echo[ >> %RELATORIO%

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::test mysql esta funcionando
echo[> C:\BACKUP\temp.sql
%mysql% --host=127.0.0.1 --port=%PORT% --force --user=%dbUser% --password=%dbPasswor%  < C:\BACKUP\temp.sql 2^> C:\BACKUP\test_connection_temp.txt
del C:\BACKUP\temp.sql
set /P result_test_connection=<C:\BACKUP\test_connection_temp.txt
copy %LOG_DA_ROTINA% + C:\BACKUP\test_connection_temp.txt %LOG_DA_ROTINA%
del C:\BACKUP\test_connection_temp.txt
echo[ >> %LOG_DA_ROTINA%


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::dump do banco de dados
echo RESULTADO DOS DUMPS EXECUTADOS DOS SEGUINTES BANCOS DE DADOS: >> %LOG_DA_ROTINA%
echo[ >> %LOG_DA_ROTINA%
for /d %%f in (*) do (

	
	%mysqldump% --host="localhost" --port=%PORT% --user=%dbUser% --log-error=%backupDir%\%dirName%\logs\log-%%f.txt --password=%dbPassword% --verbose --single-transaction --add-drop-table --databases %%f > %backupDir%\%dirName%\%%f.sql 

	findstr /i "erro errno" %backupDir%\%dirName%\logs\log-%%f.txt
	::echo "-------"
	::echo ERRORLEVEL
	::echo !errorlevel!
	::echo %errorlevel%
	echo "-------"
    if !errorlevel!==1 (
		echo ___________[Sucesso].....Banco: %%f >> %LOG_DA_ROTINA%
		echo ___________[Sucesso].....Banco: %%f >> %RELATORIO%
	) else (
		echo ___________[Error].....Banco: %%f >> %LOG_DA_ROTINA%
		echo ___________[Error].....Banco: %%f >> %RELATORIO%
		)
	echo[ >> %RELATORIO%
	echo[ >> %RELATORIO%
	%zip% a -tgzip %backupDir%\%dirName%\%%f.sql.gz %backupDir%\%dirName%\%%f.sql  >> %LOG_DA_ROTINA%
    if !errorlevel!==0 (
		echo ___________Criado TAR.GZ do banco: %backupDir%\%dirName%\%%f.sql.gz >> %RELATORIO%
	) else (
		echo ___________Error na criacao TAR.GZ banco: %backupDir%\%dirName%\%%f.sql.gz >> %RELATORIO%
		)	
	del %backupDir%\%dirName%\%%f.sql
	)
	

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::verificcao dos erros na pasta de logs	
echo Caminho para pasta de log: %backupDir%\%dirName%\logs\ >> %LOG_DA_ROTINA%
echo[ >> %RELATORIO%
echo Caminho para pasta de log: %backupDir%\%dirName%\logs\ >> %RELATORIO%
pushd %backupDir%\%dirName%\logs

%zip% a %backupDir%\%dirName%\logs %backupDir%\%dirName%\logs
findstr /i /m "erro errno" *.*
if %errorlevel%==0 (
	echo[ >> %RELATORIO%	
	echo[ >> %LOG_DA_ROTINA% 
	
	echo ------Detalhes do erro lista de logs -------: >> %LOG_DA_ROTINA%
	findstr /i /m "erro errno" *.* >> %LOG_DA_ROTINA%
	echo ----------------------- -------:>> %LOG_DA_ROTINA%	
	
	echo ------Detalhes do erro lista de logs -------: >> %RELATORIO%
	findstr /i /m "erro errno" *.* >> %RELATORIO%
	echo ----------------------- -------:>> %RELATORIO%
	
	%sendEmailApp% -a %backupDir%\%dirName%\logs.7z -f %emailUser% -t %toEmail% -u "[Erro] pjg-script-serv (192.168.0.10) - Backup Diario com erros, verifique" -o message-file=%RELATORIO%  -s mail.jaboatao.pe.gov.br:587 -xu %emailUser% -xp %emailPW% -o tls=yes
echo 
) else (
	%sendEmailApp% -a %backupDir%\%dirName%\logs.7z -f %emailUser% -t %toEmail% -u "[Sucesso] pjg-script-serv (192.168.0.10) - Backup Diario com Sucesso, verifique" -o message-file=%RELATORIO% -s mail.jaboatao.pe.gov.br:587 -xu %emailUser% -xp %emailPW%  -o tls=yes
)

del %backupDir%\%dirName%\logs.7z

