#!/bin/bash
set -o pipefail
ENV_FILE_PATH=../.env
export $(grep -v '^#' $ENV_FILE_PATH | xargs)

if [ $# -eq 0 ]; then
    echo "$0: [Error] Usage: $0 <change_log_query>"
    exit 1
fi

DATABASES=$(mysql -u root -h ${REPLICA_HOST} --password=${REPLICA_USER_PASSWORD} --port ${REPLICA_PORT} -se "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)" | tr '\n' ',' | sed 's/,$//')
change_log_query=$1
SQL_QUERY="CHANGE REPLICATION SOURCE TO
           SOURCE_HOST='${MASTER_HOST}',
           SOURCE_USER='${MASTER_USER_NAME}',
           SOURCE_PASSWORD='${MASTER_USER_PASSWORD}';"

mysql -u root -h ${REPLICA_HOST} -p${REPLICA_USER_PASSWORD} --port ${REPLICA_PORT} -e \
  "STOP REPLICA;
  RESET REPLICA;
  CHANGE REPLICATION FILTER REPLICATE_DO_DB=(${DATABASES});
  ${SQL_QUERY}
  ${change_log_query}
  START REPLICA;" 2> >(tee -a log/error.log >&2)

if [ $? -ne 0 ]; then
    echo "$0: [Error] Failed to start replication. Check error.log for details."
    exit 1
fi

replica_status_output=$(mysql -u root -h ${REPLICA_HOST} -p${REPLICA_USER_PASSWORD} --port ${REPLICA_PORT} -e "SHOW REPLICA STATUS\G")

last_io_error=$(echo "$replica_status_output" | grep "Last_IO_Error:" | awk -F'Last_IO_Error: ' '{print $2}')
last_sql_error=$(echo "$replica_status_output" | grep "Last_SQL_Error:" | awk -F'Last_SQL_Error: ' '{print $2}')

if [ -n "$last_io_error" ] || [ -n "$last_sql_error" ]; then
    echo "$0: [Error] Replication errors found:" | tee -a log/error.log
    if [ -n "$last_io_error" ]; then
        echo "Last_IO_Error: $last_io_error" | tee -a log/error.log
    fi
    if [ -n "$last_sql_error" ]; then
        echo "Last_SQL_Error: $last_sql_error" | tee -a log/error.log
    fi
    exit 1
fi
