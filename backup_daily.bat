#!/bin/bash

# mysqlBackup.sh

#SCRIPT DE BACKUP DE BASES MYSQL

#ESTA VARIÁVEL SERVE PARA IDENTIFICAR OS BACKUPS REALIZADOS FUTURAMENTE
DATA=$(date +%F)
HORA=$(date +%T)

# AQUI VOCÊ VAI DEFINIR O LOCAL E O NOME DO BACKUP, ALTERE COMO PREFERIR
# MAS MANTENHA O $DATA

# VARIÁVEIS DE CONEXÃO DO BANCO
# ALTERE CONFORME SUAS NECESSIDADES
HOST="bahrein.pmjg.lan"
MYSQL_USER="root"
MYSQL_PASSWORD="password" #(será informado)
BACKUP_DIARIO_DIR="/bacula/bahrein/diario"
BAHREIN_DIR="/bacula/bahrein"

# Create backup directory and set permissions

BACKUP_DIARIO_DATA_DIR="${BACKUP_DIARIO_DIR}/${DATA}"
BACKUP_LOGS="${BACKUP_DIARIO_DIR}/${DATA}/logs"

BACKUP_CONF="/bacula/bahrein/conf/${DATA}"        # Diretório destino dos CONFs;
CONF="/etc/mysql"
#LOG_DA_ROTINA="ALTERAR_PARA_LOG" #"/var/log/bahrein/$DATA.log" #descomentar 
LOG_DA_ROTINA="/var/log/bahrein/${DATA}.log" #mudar /var/log/bahrein/
OLD_DIR="/bacula/bahrein/OLD"
RSYNC=/usr/bin/rsync
MYSQL=/usr/bin/mysql                    # Executável do MYSQL;
MYSQL_DUMP=/usr/bin/mysqldump            # Executável do MYSQL DUMP;
echo "Backup directory: ${BACKUP_DIARIO_DATA_DIR}"
mkdir -p "${BACKUP_DIARIO_DATA_DIR}"
mkdir -p "${BACKUP_LOGS}"
mkdir -p "${BACKUP_CONF}"

chmod 777 "${BACKUP_DIARIO_DATA_DIR}"
chmod 777 "${BACKUP_LOGS}"
chmod 777 "${BACKUP_CONF}"
# Get MySQL databases
# mysql_databases=(banco01 banco02 BBB)
# Get MySQL databases
CORPO_MSG_EMAIL=""
TEVE_ERRO="FALSE"





echo "----------INICIO ROTINA $DATA-------------------------" >> $LOG_DA_ROTINA    

if !  `mysqladmin ping > /dev/null 2>&1`;
	then
	echo "mysql is down!!!" >> $LOG_DA_ROTINA
	TEVE_ERRO="TRUE"
	sendemail -f gdados@jaboatao.pe.gov.br -t gdados@jaboatao.pe.gov.br -u "Backup Mensal Não Realizado" -m "Mysql não está rodando"  -s mail.jaboatao.pe.gov.br:587 -xu gdados@jaboatao.pe.gov.br -xp 123@jaboatao -o tls=yes


else
    echo "mysql is running" >> $LOG_DA_ROTINA
    # Get MySQL databases
	#`echo 'show databases' | mysql --user=sistemasdb --password=PfUv4tW638 -B | sed /^Database$/d`
    #mysql_databases=`echo 'show databases' | mysql --user=${MYSQL_USER} --host=${HOST} --password=${MYSQL_PASSWORD} -B | sed /^Database$/d`
	mysql_databases=$($MYSQL --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} --host=${HOST} -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)")
	#echo $mysql_databases
	CORPO_MSG_EMAIL="Verifique logs em anexo.\n"
	
    PASSWORDISOK=`mysqladmin --user=${MYSQL_USER} --host=${HOST} --password=${MYSQL_PASSWORD} ping | grep -c "mysqld is alive"`
    echo "PASSWORDISOK: ${PASSWORDISOK}"
    if  [ "$PASSWORDISOK" == "0" ]; then
		echo "MYSQL ERROR : Access Denied - Erro com Usuario ou Senha\n" >> $LOG_DA_ROTINA
		TEVE_ERRO="TRUE"
	fi
	
	
	
	# Remove os Dumps antigos
	echo " " >> $LOG_DA_ROTINA
	echo "\n---------------------REMOVE ARQUIVOS TAR.GZ NA PASTA OLD MAIS ANTIGOS-------------------\n" >> $LOG_DA_ROTINA
	echo " " >> $LOG_DA_ROTINA

	#remove os compactados de backup da pasta OLD deixando apenas o dos ultimos 3 dias.
	find $OLD_DIR/*.gz -mtime +3 -exec rm -fv {} \; >> $LOG_DA_ROTINA
	echo " " >> $LOG_DA_ROTINA
	echo "-----------------------------" >> $LOG_DA_ROTINA 

	echo " " >> $LOG_DA_ROTINA

	#echo "-----------------------------------" >> $LOG_DA_ROTINA
	#echo "Espaço em disco utilizado $(du -shc "$BACKUP_DIARIO_DATA_DIR/*") " >> $LOG_DA_ROTINA
	#echo "-----------------------------------" >> $LOG_DA_ROTINA	
		
	
	
	
	
	
	#BACKUP DOS AREQUIVOS DE CONF DO MYSQL
	echo "\n-------------BACKUP DOS AREQUIVOS DE CONF DO MYSQL--------------\n" >> $LOG_DA_ROTINA
	echo "----------------------------" >> $LOG_DA_ROTINA
	cp -Rv $CONF $BACKUP_CONF >> $LOG_DA_ROTINA
	echo "----------------------------" >> $LOG_DA_ROTINA	
	
	
	echo "\n------------CRIANDO DUMPS---------------" >>  $LOG_DA_ROTINA	
    #for database in acontece db_ouvidoria jaboatao_jaboa026_diarioficial jaboatao_jaboa026_portaldatransparencia jaboatao_jaboa026_procon jaboatao_jaboa026_selecao db_folha jaboatao_servidor
    for database in $mysql_databases
		do
			echo "Creating backup of \"${database}\" database"
			#if [ "${database}" == "information_schema" ] || [ "${database}" == "performance_schema" ]; then
			#		additional_mysqldump_params="--skip-lock-tables"
			#else
			#		additional_mysqldump_params=""
			#fi
		
			#mysqldump ${additional_mysqldump_params} --host=${HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} ${database} --verbose --single-transaction  --routines --triggers --force --opt --databases --log-error=${BACKUP_LOGS}/${database}.txt $database > "${BACKUP_DIARIO_DATA_DIR}/${database}.sql"
			${MYSQL_DUMP} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} --host=${HOST} --single-transaction --verbose --routines --triggers --force --opt --databases --log-error=${BACKUP_LOGS}/${database}.txt $database > "${BACKUP_DIARIO_DATA_DIR}/${database}.sql"
			echo "Dump Concluido da database   $database    em $(date +%F) as $(date +%T)" >> $LOG_DA_ROTINA 

		if grep -q -i "ERROR " "${BACKUP_LOGS}/${database}.txt" || grep -q -i "ERRNO " "${BACKUP_LOGS}/${database}.txt"; then
			echo "log ${BACKUP_LOGS}/${database}.txt contem erro" >> $LOG_DA_ROTINA 
			TEVE_ERRO="TRUE"
			CORPO_MSG_EMAIL+="\nDetalhes do erro no log: ${BACKUP_LOGS}/${database}.txt" 
		else
			echo "log ${BACKUP_LOGS}/${database}.txt nao contem erro"
		fi
    done


	du -shc $BACKUP_DIARIO_DATA_DIR/*.sql >> $LOG_DA_ROTINA
	echo "\n---------------COMPACTAR EM TAR.GZ DE TODOS OS DUMPS E ENVIAR PARA A PASTA OLD---------------\n" >> $LOG_DA_ROTINA
	#COMPACTAR EM TAR.GZ DE TODOS OS DUMPS E ENVIAR PARA A PASTA OLD 
	tar -czvf $BAHREIN_DIR/$DATA.tar.gz $BACKUP_DIARIO_DATA_DIR $CONF >> $LOG_DA_ROTINA 
	mkdir -p $OLD_DIR
	#copia para pasta old o tar gz.
	$RSYNC -av $BAHREIN_DIR/$DATA.tar.gz $OLD_DIR >> $LOG_DA_ROTINA
	#remover
	rm -rfv $BAHREIN_DIR/$DATA.tar.gz
	
	chmod -Rv 777 $OLD_DIR
	chown -Rv root:gg_drts_users_apache $OLD_DIR	
		
	
	
	
	
	
	
	#TESTAR TAR.GZ movido na pasta old
	tar -tzf $OLD_DIR/$DATA.tar.gz >/dev/null >> $LOG_DA_ROTINA 

	

	#compacta logs para enviar por email
	tar -czvf "${BAHREIN_DIR}/logs-${DATA}.tar.gz" $BACKUP_LOGS $LOG_DA_ROTINA 

	
	#tsta se tem erro no log da rotina true ou false
	if grep -q -i "ERROR " "${LOG_DA_ROTINA}" || grep -q -i "ERRNO " "${LOG_DA_ROTINA}"; then
		echo "log ${LOG_DA_ROTINA} contem erro" >> $LOG_DA_ROTINA 
		TEVE_ERRO="TRUE"
		CORPO_MSG_EMAIL+="\nDetalhes do erro no log: ${LOG_DA_ROTINA}" 
	else
		echo "log ${LOG_DA_ROTINA} nao contem erro"
	fi	
	
	
	

	

	
	
	
	
	#remover dumps e logs
	echo "Removendo dumps diarios" 
	rm -rfv ${BACKUP_DIARIO_DATA_DIR} >> $LOG_DA_ROTINA

	
	#remover backup confs mysql
	rm -rfv ${BACKUP_CONF} >> $LOG_DA_ROTINA
	#remover compactado dos logs
	
	#envio de email

    echo 'enviando email....'
	echo "$CORPO_MSG_EMAIL"	
    if [ "$TEVE_ERRO" = "TRUE" ]; then
		#echo "TEVE ERRO ${TEVE_ERRO}" >> ${LOG_DA_ROTINA}
		#sendemail -f luciano.leal@jaboatao.pe.gov.br -t fabio.lessa@jaboatao.pe.gov.br -cc luciano.leal@jaboatao.pe.gov.br -u "ATENÇÃO - Backup Diario ${HOST} Não Realizado, verifique." -m "${CORPO_MSG_EMAIL}"  -s mail.jaboatao.pe.gov.br:587  -a "${BAHREIN_DIR}/logs-${DATA}.tar.gz"  -xu luciano.leal@jaboatao.pe.gov.br -xp 289dabed -o tls=yes
		sendemail -f gdados@jaboatao.pe.gov.br -t gdados@jaboatao.pe.gov.br -u "ATENÇÃO - Backup Diario ${HOST} Não Realizado, verifique." -m "${CORPO_MSG_EMAIL}"  -s mail.jaboatao.pe.gov.br:587  -a "${BAHREIN_DIR}/logs-${DATA}.tar.gz"  -xu gdados@jaboatao.pe.gov.br -xp 123@jaboatao -o tls=yes
	else
		#sendemail -f luciano.leal@jaboatao.pe.gov.br -t fabio.lessa@jaboatao.pe.gov.br -cc luciano.leal@jaboatao.pe.gov.br -u "Backup Diario ${HOST} Realizado Com Sucesso, verifique." -m "${CORPO_MSG_EMAIL}"  -s mail.jaboatao.pe.gov.br:587 -a "${BAHREIN_DIR}/logs-${DATA}.tar.gz" -xu  luciano.leal@jaboatao.pe.gov.br -xp 289dabed -o tls=yes
		sendemail -f gdados@jaboatao.pe.gov.br -t gdados@jaboatao.pe.gov.br -u "Backup Diario ${HOST} Realizado Com Sucesso, verifique." -m "${CORPO_MSG_EMAIL}"  -s mail.jaboatao.pe.gov.br:587 -a "${BAHREIN_DIR}/logs-${DATA}.tar.gz" -xu  gdados@jaboatao.pe.gov.br -xp 123@jaboatao -o tls=yes

		#echo "TEVE ERRO ${TEVE_ERRO}" >> ${LOG_DA_ROTINA}
	fi

	rm -rfv ${BAHREIN_DIR}/logs-${DATA}.tar.gz
    
	
	
	
	
	echo "----------FIM ROTINA $DATA-------------------------" >> $LOG_DA_ROTINA 
	   
fi

