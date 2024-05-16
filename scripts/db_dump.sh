#!/bin/bash
set -o pipefail
ENV_FILE_PATH=../.env
export $(grep -v '^#' $ENV_FILE_PATH | xargs)

if [ $# -eq 0 ]; then
    echo "$0: [Error] The database was not pass"
    exit 1
fi

database_name=$1
echo "-- [RUN] Starting mysqldump for database: $database_name..."

mysqldump --databases "${database_name}" --add-drop-database \
  --single-transaction --column-statistics=0 --source-data=2 \
  -u root -p"${MASTER_USER_PASSWORD}" --port "${MASTER_PORT}" 2> >(tee -a log/error.log >&2) \
 | pv | gzip > "dumps/${database_name}_dump.sql.gz" 2> >(tee -a log/error.log >&2)

if [ $? -ne 0 ]; then
    echo "$0: [Error] mysqldump failed. Check error.log for details."
    exit 1
fi

echo "-- [Success] Dump completed successfully to file: dumps/${database_name}_dump.sql.gz"
echo ""