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