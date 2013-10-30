# Assumes:
# - postgres 8+ is installed
# - user roles created
# - extensions can be created
#
# Checks:
# - proper environment variable set

pg     = require 'pg'
config = require 'config'

if process.env.NODE_ENV != 'superuser' and process.env.NODE_ENV != 'test'
    throw new Error 'NODE_ENV not set properly'

superuser = require('./../config/secrets').PG.superuser.user
appuser = require('./../config/secrets').PG.app.user


extensionScript = """
    create extension if not exists hstore;
    create extension if not exists "uuid-ossp";
"""

schemaScript = """
    drop schema if exists kinisi cascade;
    create schema kinisi authorization #{superuser};
    create sequence kinisi.local_salt_seq;
    grant usage on schema kinisi to #{appuser};
    grant all on kinisi.local_salt_seq to #{appuser};
    --
    drop schema if exists dim cascade;
    create schema dim authorization #{superuser};
    grant usage on schema dim to #{appuser};
    --
    drop schema if exists fact cascade;
    create schema fact authorization #{superuser};
    grant all on schema fact to #{appuser};
    grant select, insert on all tables in schema fact to #{appuser};
    --
    drop schema if exists staging cascade;
    create schema staging authorization #{appuser};
    grant all on schema staging to #{appuser};
    grant update, select, insert on all tables in schema staging to #{appuser};
    --
    drop schema if exists extract cascade;
    create schema extract authorization #{appuser};
    grant all on schema extract to #{appuser};
    grant update, select, insert on all tables in schema extract to #{appuser};
"""

tableScript = """
    -- kinisi.local - the system schema
    drop table if exists kinisi.local cascade;
    create table if not exists kinisi.local(
        systemkey uuid primary key, 
        name varchar(160) not null, 
        installed timestamp default now());
    
    -- create system UUID
    insert into kinisi.local (systemkey, name, installed) values (
        uuid_generate_v1(), 
        'kinisi_prototype', 
        now());
    
    grant select on kinisi.local to #{appuser};

    -- dim.document
    drop table if exists dim.document cascade;
    create table dim.document (
        uid uuid primary key,
        id serial unique,
        name varchar(160) not null, 
        created timestamp not null,
        current bit(2) not null, 
        description varchar(1000),
        meta hstore);
    create index on dim.document (current);

    drop table if exists dim.platform cascade;
    create table dim.platform ( like dim.document including all,
        lat numeric,
        lng numeric,
        lastupdate timestamp default now() );
    grant all on dim.platform to #{appuser};
    grant all on dim.document_id_seq to #{appuser};

    drop table if exists dim.user cascade;
    create table dim.user ( like dim.document including all );

    drop table if exists dim.group cascade;
    create table dim.group ( like dim.document including all );

    -- temporary table to support project
    drop table if exists fact.sensor_data cascade;
    create table fact.sensor_data (
        platform_id integer references dim.platform(id),
        ts timestamp with time zone not null,
        temp_degc numeric,
        humidity numeric,
        no2_raw numeric,
        no2 numeric,
        co_raw numeric,
        co numeric,
        voc_raw numeric,
        voc numeric);
    grant select, update, insert on fact.sensor_data to #{appuser};

    drop table if exists staging.sensor_data cascade;
    create table staging.sensor_data (like fact.sensor_data);
 
    drop table if exists extract.sensor_data cascade;
    create table extract.sensor_data (
        ts text,
        temp_degc text,
        humidity text,
        no2_raw text,
        no2 text,
        co_raw text,
        co text,
        voc_raw text,
        voc text);
    grant select on table extract.sensor_data to #{appuser};

"""

# cb takes two arguments (err, result)
installExtensionDefinitions = (cb) ->
    withClient 'installing postgres extensions', cb, (client, done) ->
        client.query extensionScript, (err, result) ->
            done()
            cb err, result

installSchemaDefinitions = (cb) ->
    withClient 'installing postgres schema elements', cb, (client, done) ->
        client.query schemaScript, (err, result) ->
            done()
            cb err, result
    
installTableDefinitions = (cb) ->
    withClient 'installing postgres table definitions', cb, (client, done) ->
        client.query tableScript, (err, result) ->
            #call `done()` to release the client back to the pool
            done()
            cb err, result

# SQL function in a separate file
installFunctions = (tablename, cb) =>
    spawn  = require('child_process').spawn
    spawn('psql', ['-U', superuser, '-f', 'resources/platformFunctions.sql', tablename])
        .on 'close', (code) ->
            error = 'exit error ' + code if code != 0
            code = 'child process returned with code 0' if code == 0
            cb error, code

# errorHandler and next should be functions
withClient = (message, errorHandler, next) ->
    console.log message
    pg.connect config.Postgres.connection, (err, client, done) ->
        if err
            done()
            errorHandler err
        else
            next client, done
    
logger = (err, result) ->
    console.error err if err
    console.log 'success: ', result if result and not err
    pg.end()

# MAIN 
console.log process.argv
console.log()


if process.argv[2] == '--schema'
    installSchemaDefinitions logger
else if process.argv[2] == '--table'
    installTableDefinitions logger
else if process.argv[2] == '--extension'
    installExtensionDefinitions logger
else if process.argv[2] == '--function'
    return console.error 'insufficient arguments: sql table name required' if !process.argv[3]
    installFunctions process.argv[3], logger

