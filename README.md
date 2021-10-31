# CS2102Project
Repo for the CS2102 Project 2021/22 sem 1

Set up project db locally:
1. login to your psql> psql -d <existing_db_name> -U postgres
2. create new db in your account> create database <new_db_name>;
3. access new db> \c <new_db_name>
4. exit> \q
5. initialise tables> psql -d <new_db_name> -U postgres -f <path_to_schema.sql>
