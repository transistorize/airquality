#!/bin/sh -x
# assumptions: postgres is installed, postgres user credentials required
# postgres initial setup - creates databases for air quality project
# does not install schemas or tables
# these instructions were tested on ubuntu 12
SUPERUSER=$1
APP=$2

# create the 'superuser' role -- will prompt you for passwords
sudo -u postgres createuser --superuser --pwprompt --createdb ${SUPERUSER}

# create the 'application' role -- will prompt you for passwords
sudo -u postgres createuser --pwprompt --no-createdb --no-superuser --no-createrole ${APP}

# create the default database
createdb -U ${SUPERUSER} platform

# create the testing database if necessary
#createdb -U ${SUPERUSER} platformtest

