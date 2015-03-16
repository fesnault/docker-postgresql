DBUSER=${DBUSER:-super}
DBPASS=${DBPASS:-password}

pre_start_action() {
  # Echo out info to later obtain by running `docker logs container_name`
  echo "POSTGRES_USER=$DBUSER"
  echo "POSTGRES_PASS=$DBPASS"
  echo "POSTGRES_DATA_DIR=$DATA_DIR"
  if [ ! -z $DB ];then echo "POSTGRES_DB=$DB";fi

  # test if DATA_DIR has content
  if [[ ! "$(ls -A $DATA_DIR)" ]]; then
      echo "Initializing PostgreSQL at $DATA_DIR"

      # Copy the data that we generated within the container to the empty DATA_DIR.
      cp -R /var/lib/postgresql/9.3/main/* $DATA_DIR
  fi

  # Ensure postgres owns the DATA_DIR
  chown -R postgres $DATA_DIR
  # Ensure we have the right permissions set on the DATA_DIR
  chmod -R 700 $DATA_DIR
}

post_start_action() {
  echo "Creating the superuser: $DBUSER"
  setuser postgres psql -q <<-EOF
    DROP ROLE IF EXISTS $DBUSER;
    CREATE ROLE $DBUSER WITH ENCRYPTED PASSWORD '$DBPASS';
    ALTER USER $DBUSER WITH ENCRYPTED PASSWORD '$DBPASS';
    ALTER ROLE $DBUSER WITH SUPERUSER;
    ALTER ROLE $DBUSER WITH LOGIN;
EOF

  # create database if requested
  if [ ! -z "$DB" ]; then
    for db in $DB; do
      echo "Creating database: $DB"
      setuser postgres psql -q <<-EOF
      CREATE DATABASE $DB WITH OWNER=$DBUSER ENCODING='UTF8';
      GRANT ALL ON DATABASE $DB TO $DBUSER
EOF
    done
  fi

  if [[ ! -z "$EXTENSIONS" && ! -z "$DB" ]]; then
    for extension in $EXTENSIONS; do
      for db in $DB; do
        echo "Installing extension for $DB: $extension"
        # enable the extension for the user's database
        setuser postgres psql $DB <<-EOF
        CREATE EXTENSION "$extension";
EOF
      done
    done
  fi

  rm /firstrun
}
