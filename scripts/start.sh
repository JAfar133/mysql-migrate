#!/bin/bash
ENV_FILE_PATH=../.env
echo "Loading env variables from $ENV_FILE_PATH"
export $(grep -v '^#' $ENV_FILE_PATH | xargs)

if [ "$DATABASES" == "ALL" ]; then
    DATABASES=$(mysql -u root -p${MYSQL_ROOT_PASS} --port ${MYSQL57_PORT} -se "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)" | tr '\n' ',')
fi

IFS=',' read -ra database_array <<< "$DATABASES"

if [ ! -d "dumps" ]; then
    echo "Creating dumps directory"
    mkdir dumps
fi

if [ ! -d "log" ]; then
    echo "Creating log directory"
    mkdir log
fi

error_databases=()

for db in "${database_array[@]}"; do
    if [[ "$db" == "information_schema" ]] || [[ "$db" == "performance_schema" ]] || [[ "$db" == "mysql" ]] || [[ "$db" == "sys" ]]; then
        continue
    fi

    echo " == $db == "

    ./change_db_encoding.sh $db
    if [ $? -ne 0 ]; then
        error_databases+=("$db")
        continue
    fi

    ./db_dump.sh $db
    if [ $? -ne 0 ]; then
        error_databases+=("$db")
        continue
    fi

    echo "Restoring database on slave."
    gunzip -c dumps/${db}_dump.sql.gz | mysql -u root -p${REPLICA_USER_PASSWORD} --port ${REPLICA_PORT} 2> log/error.log
    if [ $? -ne 0 ]; then
        echo "[Error] Error restoring database on slave for database: $db. Check error.log for details."
        error_databases+=("$db")
        continue
    fi

    change_log_query=$(gunzip -c dumps/${db}_dump.sql.gz | grep 'CHANGE MASTER TO' | awk -F"-- " '{print $2}')

    ./start_replication.sh "$change_log_query"
    if [ $? -ne 0 ]; then
        error_databases+=("$db")
        continue
    fi

done

if [ ${#error_databases[@]} -ne 0 ]; then
    echo "[Error] Errors occurred for the following databases:" | tee -a log/error.log
    for error_db in "${error_databases[@]}"; do
        echo " - $error_db" | tee -a log/error.log
    done
    exit 1
fi

echo "[Success] All databases processed successfully."