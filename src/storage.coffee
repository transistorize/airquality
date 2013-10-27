#
# abstract away the data management
#

"use strict"

config = require 'config'
getmac = require 'getmac'
pg     = require 'pg'
fs     = require 'fs'
_      = require 'underscore'
ChangeRequest = require './cr'


class Storage

    constructor: ->
        @systemuuid = null
              
    # get array of uids for a given name.
    # names are not guaranteed unique, so several uids may match
    getUidsForName: (name, cb) ->
        throw new Error 'invalid arguments' if !cb or !name
        query 'select uid from dim.platform where name = $1::varchar', [name], (err, result) ->
            if !err
                uids = result.rows?.map( (x) -> x.uid )
                cb null, uids
            else
                cb 'error querying for identifiers by name=' + name
    
    # get system identifier - caches this value
    getSystemUuid: (cb) =>
        throw new Error 'invalid arguments' if !cb
        return cb null, @systemuuid if @systemuuid
        #note: wide arrow for function callback
        query 'select systemkey from kinisi.local;', (err, result) =>
            if !err
                @systemuuid = result.rows?[0].systemkey
                cb null, @systemuuid
            else
                cb 'error querying for system key - db is likely corrupt'
    
    # atomic call to create a new platform, returns its initial state
    createPlatform: (name, cb) ->
        "use strinct"
        throw new Error 'invalid arguments' if !cb or !name
        # pass in the mac address for the stored procedure
        getmac.getMac (err, macAddress) =>
            return cb err if err or !macAddress
            params = [name, macAddress + process.pid]
            query 'select * from create_platform($1::varchar, $2::varchar)', params, (err, result) ->
                if !err
                    platform = result.rows?[0]
                    cb null, platform
                else
                    cb 'error creating platform with name ' + name
    
    # should not consider this an atomic call
    # count will be max 100
    getPlatforms: (page, count, cb) ->
        throw new Error 'invalid arguments' if !cb or count <= 0 or page < 0
        count = 100 if count > 100
        query 'select * from dim.platform limit $1::int offset $2::int', [count, page * count], (err, result) ->
            if !err
                cb null, result.rows || []
            else
                cb 'error getting platforms for page=' + page + ', count=' + count
    
    # returns an array of length one, one platform, assuming it exists,
    # otherwise returns the empty array
    getPlatformByUid: (uid, cb) ->
        throw new Error 'invalid arguments' if !cb or !uid
        query 'select * from dim.platform where uid = $1::uuid limit 1', [uid], (err, result) ->
            if !err
                cb null, result.rows || []
            else
                cb 'error querying for platform by uid=' + uid
    
    # returns an array of length one, one platform, assuming it exists,
    # otherwise returns the empty array
    getPlatformById: (id, cb) ->
        throw new Error 'invalid arguments' if !cb or !id
        query 'select * from dim.platform where id = $1::int limit 1', [id], (err, result) ->
            if !err
                cb null, result.rows || []
            else
                cb 'error querying for platform by id=' + id

    ## TODO cache uid -> data table mapping
    ## TODO data tables should reflect schema set by needs of specific platform, 
    ## which will vary platform to platform
    getDataByUidAndPage: (uid, page, cb) ->
        throw new Error 'invalid arguments' if !cb or !uid
        page = page || 0
        count = 5000
        query 'select id from dim.platform where uid = $1::uuid limit 1', [uid], (err, result) =>
            if err || !result || !result.rows[0]?.id
                return  cb 'error finding platform data table for uid=' + uid
            query 'select * from fact.sensor_data where platform_id = $1::int limit $2::int offset $3::int',
                [result.rows[0]?.id, count, count * page], (err, result) ->
                    if !err
                        cb null, result.rows || []
                    else
                        cb 'error querying for platform data by uid=' + uid
   
    # one-off table wide query - this is dangerous, but expedient
    getDataByColumn: (cols, cb) ->
        throw new Error 'invalid arguments' if !cb or !cols
        
        keys = cols.split(',')
        return cb 'illegal column name=' + cols.slice(1,25) unless _.every(keys, isLegalName)

        # have to split up the postgres regex to work around strict mode
        regex = '([\\' + 'd-]*)\\' + 's([\\' + 'd:]*)'
        replacement = '\\' + '1T\\' + '2Z'
        query """
            select p.uid, p.name, regexp_replace((f.ts at time zone 'gmt')::text, $1, $2) as ts, #{cols} 
            from fact.sensor_data f
            join dim.platform p on p.id = f.platform_id
            order by p.uid, f.ts; """, [regex, replacement], (err, result) =>
                if !err
                    cb null, aggregateByPlatform(result.rows || [])
                else
                    cb 'error querying for platform by data column=' + cols
                

    # create a change request for modifications
    createChange: (uuid) ->
        return new ChangeRequest(uuid)
    
    # submit the change to the data layer
    update: (change, cb) ->
        throw new Error 'invalid arguments' if !cb or !change
        cb 'unsupported error!'

    # shuts down all storage related resources
    # calling this should only be done by the main script
    exit: ->
        pg.end()
    
    # bulk CSV import
    # metainfo must have the name, path, and import_schema attributes specified
    bulkCSVImport: (uid, metainfo, cb) ->
        throw new Error 'invalid arguments' if !cb or !uid or !metainfo or !metainfo.path or !metainfo.name or !metainfo.import_schema

        copyCSVFile = (client, cb) ->
            # some flags to ensure callbacks aren't called multiple times
            isCallbackCalled = false
            errorRecv = null

            wstream = client.copyFrom 'copy extraction (' metainfo.import_schema.join(',') + ') from STDIN with csv;'
            
            wstream.on 'finish', () -> 
                console.log 'Imported:', metainfo
                if !errorRecv && !isCallbackCalled
                    callbackCalled = true
                    cb null, metainfo.path

            wstream.on 'error', (error) -> 
                errorRecv = error
                console.error 'error from write stream:', error, ' on behalf of uid=', uid
                rstream.end()
                if !callbackCalled
                    callbackCalled = true
                    cb error
           
            rstream = fs.createReadStream metainfo.path, {autoClose: true}
            
            rstream.on 'data', (chunk) ->
                console.log 'reading chunk from', metainfo.name
                stream.write chunk
            
            rstream.on 'error', (error) -> 
                errorRecv = error
                console.error 'error from read stream:', error, ' on behalf of uid=', uid
                wstream.end()
                if !callbackCalled
                    callbackCalled = true
                    cb error
            
            rstream.on 'close', () -> 
                wstream.end()

        copyToTempExtraction = (client, cb) ->
            client.query "create temp table extraction (like extract.egg_data);", (err, result) ->
                return cb 'cannot create temporary space for copying data' if err
                copyCSVFile client, cb

        @withinTransaction copyToTempExtraction, (err, result) -> 
            # call the transformation method
            cb err, result       
           
    #
    # private
    #
    
    #reaggregate each row into a list of platforms and their respective values
    aggregateByPlatform = (rows) ->
        return rows if rows.length is 0       
        result = {}
        # helper
        aggByUidAndName = (row) ->
            result[row.uid] = result[row.uid] || {uid: row.uid, name: row.name, values:[]}
            result[row.uid].values.push(_.omit(row, ['uid', 'name'])) 
        # transform each row
        _.each(rows, aggByUidAndName)
        return _.values(result)

    # handles checking column names, returns true or false
    isLegalName = (col) ->
        return /^co($|_raw$)|^no2($|_raw)$|^voc($|_raw$)|^humidity$|^temp_degc$/.test(col)
    
    # private method: handle pg-client pooling
    query = (statement, parameters, cb) ->
        if typeof parameters is 'function'
            cb = parameters
            parameters = undefined
        
        throw new Error 'callback required' if !cb
        console.log 'query:', statement, ', ', parameters?.length, ' parameter(s)'
        pg.connect config.Postgres.connection, (err, client, done) =>
            if !err
                client.query statement, parameters, (err, result) ->
                    done()
                    try
                        if err then console.error err
                        cb err, result
                    catch exp
                        console.error exp
            else
                console.error 'error with query', err
                cb err

    # private method: wrapper method for begining and ending a transaction
    withTransaction = (innerExecution, postHook) ->
        pg.connect config.Postgres.connection, (err, client, done) =>
            if err
                done()
                return cb err
            
            # healper method: cleans up the transaction and pg client
            commitOrRollback = (err, result) ->
                if !err
                    client.query 'commit;', (err, result) -> 
                        done()
                        postHook err, true
                else
                    client.query 'rollback;', (err, result) -> 
                        done()
                        postHook err, false

            # start the transaction, execute the body, call commit
            client.query 'begin;', (err, result) ->
                if err
                    done()
                    return cb err
                
                commitCallback = commitOrRollback(cb) 
                
                try
                    innerExecution client, commitCallback
                catch exp
                    commitCallback exp  #call with error,
                

module.exports = Storage

