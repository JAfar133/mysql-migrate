#!/bin/bash
set -o pipefail
ENV_FILE_PATH=../.env
export $(grep -v '^#' $ENV_FILE_PATH | xargs)
if [ $# -eq 0 ]; then
    echo "$0: [ERROR] The database was not pass"
    exit 1
fi

database_name=$1
echo "-- [RUN] Starting to change character set for database: $database_name --"

query=$(mysql -u root -h ${MASTER_HOST} -p${MASTER_USER_PASSWORD} --port ${MASTER_PORT} -se \
  "SELECT CONCAT('ALTER TABLE \`${database_name}\`.', TABLE_NAME, ' CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci, LOCK=SHARED;')
   FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = '${database_name}' AND TABLE_TYPE != 'VIEW';")

if [ -z "$query" ]; then
    echo "$0: [ERROR] No tables found or query is empty"
    exit 1
fi
echo "SET FOREIGN_KEY_CHECKS=0;
        ALTER DATABASE \`${database_name}\`
        CHARACTER SET = utf8mb4
        COLLATE = utf8mb4_unicode_ci;
        $query
        SET FOREIGN_KEY_CHECKS=1;" \
| mysql -u root -h ${MASTER_HOST} -p${MASTER_USER_PASSWORD} --port ${MASTER_PORT} ${database_name} 2> >(tee -a log/error.log >&2)

if [ $? -ne 0 ]; then
    echo "$0: [Error] Failed to change character set for database: $database_name. Check error.log for details."
    exit 1
fi

echo "-- [Success] Character set changed successfully for database: $database_name"
echo ""