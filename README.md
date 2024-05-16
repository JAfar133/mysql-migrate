# MySQL-migrate
MySQL 5.7 to MySQL 8 migration scripts

Before running scripts:
1. Create .env file from .env.sample
2. Add `[mysqld] sql_mode = "NO_ZERO_IN_DATE"` to `/etc/my.cnf/my.cnf` file.

For start:
1. cd into `./scripts `
2. run `start.sh`