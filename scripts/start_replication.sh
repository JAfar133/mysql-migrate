#!/bin/bash
ENV_FILE_PATH=../.env
export $(grep -v '^#' $ENV_FILE_PATH | xargs)

if [ $# -eq 0 ]; then
    echo "[Error] Usage: $0 <change_log_query>"
    exit 1
fi

change_log_query=$1
SQL_QUERY="CHANGE REPLICATION SOURCE TO
           SOURCE_HOST='${MASTER_HOST}',
           SOURCE_USER='${MASTER_USER_NAME}',
           SOURCE_PASSWORD='${MASTER_USER_PASSWORD}';"

mysql -u root -p${REPLICA_USER_PASSWORD} --port ${REPLICA_PORT} -e \
  "STOP REPLICA;
  RESET REPLICA;
  ${SQL_QUERY}
  ${change_log_query}
  START REPLICA;" 2> log/error.log

if [ $? -ne 0 ]; then
    echo "[Error] Failed to start replication. Check error.log for details."
    exit 1
fi

replica_status_output=$(mysql -u root -p${REPLICA_USER_PASSWORD} --port ${REPLICA_PORT} -e "SHOW REPLICA STATUS\G")

last_io_error=$(echo "$replica_status_output" | grep "Last_IO_Error:" | awk -F': ' '{print $2}')
last_sql_error=$(echo "$replica_status_output" | grep "Last_SQL_Error:" | awk -F': ' '{print $2}')

if [ -n "$last_io_error" ] || [ -n "$last_sql_error" ]; then
    echo "[Error] Replication errors found:" | tee -a log/error.log
    if [ -n "$last_io_error" ]; then
        echo "Last_IO_Error: $last_io_error" | tee -a log/error.log
    fi
    if [ -n "$last_sql_error" ]; then
        echo "Last_SQL_Error: $last_sql_error" | tee -a log/error.log
    fi
    exit 1
fi

echo "[Success] Replication started successfully"