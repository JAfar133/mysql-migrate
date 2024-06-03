# MySQL-migrate
MySQL 5.7 to MySQL 8 migration scripts

Before running scripts create .env file from .env.sample

For start:
1. cd into `./scripts `
2. run `start.sh`

Possible errors when change database encoding:
1. ERROR 1067 (42000): Invalid default value for 'timestamp':
- Add `[mysqld] sql_mode = "NO_ZERO_IN_DATE"` to `/etc/my.cnf/my.cnf` file.
2. ERROR 3886 (HY000): Could not change column '{column_name}' of table '{table_name}'. The resulting size of index '{column_name}' would exceed the max key length of 1000 bytes.
- Run this: `ALTER TABLE {schema}.{table_name} ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=4;`
# Preparation for Migration

## Relocation of Docker (If Necessary)
1. Add the following configuration in `/etc/docker/daemon.json`:
```
  { 
     "data-root": "/path/to/your/new/docker/root"
  }
```
2. `sudo systemctl stop docker`
3. `sudo rsync -aP /var/lib/docker/ "/path/to/your/new/docker/root"`
4. `sudo service docker start`

## Конфигурация MySQL (Master)
- Ensure binary logging is enabled. There should not be the option `[mysqld]  skip-log-bin`
- Add the following to the `[mysqld]` section:
```
[mysqld]
server-id = {id} # different from the replica
log_bin = /var/lib/mysql/databases/mysql-bin.log
```

## Running MySQL 8 (Replica) in Docker
The replica container needs access to the master.

One way: add to the configuration `[mysqld] port = {replica_port}`
and set docker-compose.yml to communicate directly with the host system's network: `network_mode: host`

After startup, you need to make sure that the MySQL replica server has a server_id different from the master.
`show variables like 'server_id';`

#### Possible MySQL 8 (Replica) Configuration
```
[mysqld]
server-id = 1024
relay-log = /var/lib/mysql/mysql-relay-bin.log

bind-address                    = 0.0.0.0
port                            = 3307

innodb_redo_log_capacity        = 2G
lower_case_table_names          = 1
max_allowed_packet              = 999M
innodb_log_file_size            = 1G
innodb_flush_log_at_trx_commit  = 1
innodb_file_per_table
tmpdir                          = /var/tmp
log_error_verbosity             = 2
log_timestamps                  = SYSTEM
sql_mode="STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
explicit_defaults_for_timestamp

[mysqldump]
max_allowed_packet              = 200M
single-transaction
quick
```
### Possible docker-compose.yml File
```
version: '3'

services:
  mysql8:
    container_name: mysql8-replica
    build: ../docker-replica
    environment:
      - "MYSQL_ROOT_PASSWORD=${REPLICA_USER_PASSWORD:?err}"
    volumes:
      - db_data:/var/lib/mysql
    network_mode: host
volumes:
  db_data:
    name: "replica-db-data"
    driver: local
```

### Conclusion
After you have made sure that the container with the replica has access to the master and they have different server_ids. You can start running the migration script