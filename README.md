# bitnami-postgresql-extensions

Based on latest bitnami postgresql docker and added postgres-contrib extensions, postgis, plpython3u (python version 3.9.7), and plv8.

All the usages are the same with [bitnami postgresql docker](https://github.com/bitnami/bitnami-docker-postgresql), please refer to the bitnami repo for further instructions.

# TL;DR

```console
docker run --name pgsqlxts \
  -p 15435:5432 \
  -e POSTGRESQL_USERNAME=my_user \
  -e POSTGRESQL_PASSWORD=password123 \
  -e POSTGRESQL_DATABASE=my_database \
  -e POSTGRESQL_POSTGRES_PASSWORD=rootp255 \
  tlcoding/bitnami-postgresql-extensions:13.4.0
```
