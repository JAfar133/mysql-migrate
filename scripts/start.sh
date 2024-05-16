#!/bin/bash
set -o pipefail
ENV_FILE_PATH=../.env
echo "Loading env variables from $ENV_FILE_PATH"
export $(grep -v '^#' $ENV_FILE_PATH | xargs)

if [ "$DATABASES" == "ALL" ]; then
    DATABASES=$(mysql -u root --password=${MASTER_USER_PASSWORD} --port ${MASTER_PORT} -se "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)" | tr '\n' ',')
fi

IFS=',' read -ra database_array <<< "$DATABASES"

mkdir -p dumps
mkdir -p log

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

    echo "-- [RUN] Restoring database on slave..."
    gunzip -c dumps/${db}_dump.sql.gz | pv | mysql -u root -p${REPLICA_USER_PASSWORD} --port ${REPLICA_PORT} 2> >(tee -a log/error.log >&2)
    if [ $? -ne 0 ]; then
        echo "$0: [Error] Error restoring database on slave for database: $db. Check error.log for details."
        error_databases+=("$db")
        continue
    fi
    echo "-- [SUCCESS] Restoring database on slave was successful..."

    change_log_query=$(gunzip -c dumps/${db}_dump.sql.gz | grep 'CHANGE MASTER TO' | awk -F"-- " '{print $2}')

    ./start_replication.sh "$change_log_query"
    if [ $? -ne 0 ]; then
        error_databases+=("$db")
        continue
    fi

done

if [ ${#error_databases[@]} -ne 0 ]; then
    echo "$0: [Error] Errors occurred for the following databases:" | tee -a log/error.log
    for error_db in "${error_databases[@]}"; do
        echo " - $error_db" | tee -a log/error.log
    done
    exit 1
fi

echo "--- All databases processed successfully. ---"