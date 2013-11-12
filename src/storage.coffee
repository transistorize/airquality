#
# abstract away the data management
#

"use strict"

config = require 'config'
getmac = require 'getmac'
pg     = require 'pg'
fs     = require 'fs'
_      = require 'underscore'

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
    createPlatform: (body, cb) ->
        throw new Error 'invalid arguments' if !cb or !body or !body.name
        # pass in the mac address for the stored procedure
        getmac.getMac (err, macAddress) =>
            return cb err if err or !macAddress
            params = [body.name, macAddress + process.pid]
            query 'select * from create_platform($1::varchar, $2::varchar)', params, (err, result) ->
                if !err
                    platform = result.rows?[0]
                    cb null, platform
                else
                    cb 'error creating platform with name ' + body.name
    
    # should not consider this an atomic call
    # count will be max 100
    getPlatforms: (page, count, cb) ->
        throw new Error 'invalid arguments' if !cb or count <= 0 or page < 0
        count = 100 if count > 100
        query 'select * from dim.platform where current = 1::bit(2) limit $1::int offset $2::int', [count, page * count], (err, result) ->
            if !err
                cb null, result.rows || []
            else
                cb 'error getting platforms for page=' + page + ', count=' + count
    
    # returns an array of length one, one platform, assuming it exists,
    # otherwise returns the empty array
    getPlatformByUid: (uid, cb) ->
        throw new Error 'invalid arguments' if !cb or !uid
        query 'select * from dim.platform where uid = $1::uuid and current = 01::bit(2) limit 1', [uid], (err, result) ->
            if !err
                cb null, result.rows || []
            else
                cb 'error querying for platform by uid=' + uid
    
    # returns an array of length one, one platform, assuming it exists,
    # otherwise returns the empty array
    getPlatformById: (id, cb) ->
        throw new Error 'invalid arguments' if !cb or !id
        query 'select * from dim.platform where id = $1::int and current = 1::bit(2) limit 1', [id], (err, result) ->
            if !err
                cb null, result.rows or []
            else
                cb 'error querying for platform by id=' + id
    
    # modifies the platform data
    updatePlatform: (cr, cb) ->
        throw new Error 'invalid arguments' if !cb or !cr
        
        #temp
        return cb null, 'not supported'

        changeitems = cr.getChanges()
        return cb null, 'empty changes' if _.isEmpty(changeItems)

        # translate major columns 
        #changeitems
        # translate metal columns
        # translate deletions
        #query 'update dim.platform set where uid = $1'


    ## TODO cache uid -> data table mapping
    ## TODO data tables should reflect schema set by needs of specific platform, 
    ## which will vary platform to platform
    getDataByUidAndPage: (uid, page, cb) ->
        throw new Error 'invalid arguments' if !cb or !uid
        page = page or 0
        count = 5000
        query 'select id from dim.platform where uid = $1::uuid limit 1', [uid], (err, result) =>
            if err or !result or !result.rows[0]?.id
                return  cb 'error finding platform data table for uid=' + uid
            query 'select * from fact.sensor_data where platform_id = $1::int limit $2::int offset $3::int',
                [result.rows[0]?.id, count, count * page], (err, result) ->
                    if !err
                        cb null, result.rows or []
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
                

    # shuts down all storage related resources
    # calling this should only be done by the main script
    exit: ->
        pg.end()
    
    # Bulk Extract, Transform, Load Methods

    # bulk CSV import
    # metainfo must have the name and path attributes specified
    bulkCSVImport: (uid, fileList, cb) ->
        throw new Error 'invalid arguments' if !cb or !uid or !fileList
        schema = ['ts','temp_degc','humidity','no2_raw','no2','co_raw','co','voc_raw','voc']        
        
        return cb(null, 'nothing to import') if _.isEmpty(fileList)
                   
        # imports the data into the temp extraction table, based on the template table
        copyFrom uid, fileList, 'extract.sensor_data', schema, cb                    
 
    #
    # private
    #
    
    #reaggregate each row into a list of platforms and their respective values
    aggregateByPlatform = (rows) ->
        return rows if rows.length is 0       
        result = {}
        # helper
        aggByUidAndName = (row) ->
            result[row.uid] = result[row.uid] or {uid: row.uid, name: row.name, values:[]}
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
            try 
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
                    done()
                    cb err
            catch connExp
                done()
            

    # private method: wrapper method for beginning and ending a transaction
    withTransaction = (innerExecution, postHook) ->
        pg.connect config.Postgres.connection, (err, client, done) =>
            if err
                done(err)
                return postHook err
            
            # functor: cleans up the transaction and pg client
            commitOrRollback = (pgDone, finalCb) ->

                # called by the inner execution
                (err, result) ->
                    if !err
                        # tell the db to commit the transaction
                        client.query 'commit;', (err, result) -> 
                            pgDone()
                            finalCb err, result
                    else
                        #roll back the current transaction
                        client.query 'rollback;', (err, result) -> 
                            pgDone(err)
                            finalCb err

            # start the transaction, execute the body, call commit
            client.query 'begin;', (err, result) ->
                if err
                    done()
                    return postHook err
                
                commitCallback = commitOrRollback(done, postHook) 
                
                try
                    innerExecution client, commitCallback
                catch exp
                    commitCallback exp  #call with error
                    
    # private method: copy a csv text file from the local filesystem into a temporary table of the db
    copyFrom = (uid, fileList, template, copySchema, topLevelCb) ->
        
        # copy a single file into the db
        copyCSVFile = (client, table, file, cb) ->
            # some flags to ensure callbacks aren't called multiple times
            callbackCalled = false
            errorRecv = null
            
            # open the sink stream
            wstream = client.copyFrom 'copy ' + table + ' (' + copySchema.join(',') + ') from stdin with csv;'
                        
            wstream.on 'pipe', (src) ->
                console.log 'piping into the writer'
            
            wstream.on 'error', (error) -> 
                errorRecv = error
                console.error 'error from write stream:', errorRecv, 'uid=' + uid
                if !callbackCalled
                    callbackCalled = true
                    console.error 'calling wstream error callback', 'uid=' + uid
                    cb error
           
            # open the source stream
            rstream = fs.createReadStream file.path, {autoClose: true}
                        
            rstream.on 'error', (error) -> 
                errorRecv = error
                console.error 'error from read stream:', error, 'uid=' + uid
                if !callbackCalled
                    callbackCalled = true
                    wstream.end()
                    console.error 'calling rstream error callback', 'uid=' + uid
                    cb error
            
            rstream.on 'close', () -> 
                console.log 'read stream closed for', file.path, 'uid=' + uid
                wstream.end()
                if !errorRecv && !callbackCalled
                    callbackCalled = true
                    cb null, file

            #rstream.on 'data', (chunk) -> console.log 'rstream chunk length=', chunk.length
            rstream.pipe wstream, {end: false} # end write stream when read stream ends
        

        # copy several files, one by one, into the db
        seriesCopy = (client, table, fileList, finalCb) ->
            return finalCb null, 'success' if _.isEmpty(fileList)
            
            head = _.first(fileList)
            console.log 'Processing file:', head.name
            
            copyCSVFile client, table, head, (err, response) =>
                # fail fast
                return finalCb err if err
                # move on to the next item in the list
                seriesCopy client, table, _.rest(fileList), finalCb
         

        # TODO cleanup
        copyToTempTable = (client, cb) ->
            client.query 'select id from dim.platform where uid = $1::uuid limit 1;', [uid], (err, result1) ->
                return cb 'bad UUID: ' + err if err or !result1 or result1?.rows.length is 0
                console.log 'found UUID: rowcount =', result1.rowCount
                
                # create the temporary extraction table for the CSV import
                platformId = result1.rows[0].id
                tempTable = 'platform_' + platformId
                client.query 'create temp table ' + tempTable + ' (like ' + template + ');', [], (err, result2) ->
                    return cb 'cannot create temporary space for copying data: ' + err if err
                    console.log 'table creation result: ', result2 isnt undefined

                    # multiple file copy from CSV
                    seriesCopy client, tempTable, fileList.slice(), (err, result3) ->
                        return cb 'copy failed with ' + err if err
                        console.log 'completed copy, ready for transformation: ', result3 is 'success'
                        
                        # drop the staging table
                        client.query 'drop table staging.sensor_data;', [], (err, result4) ->
                            return cb 'drop table failed with ' + err if err
                            console.log 'drop table successful: ', result4 isnt undefined
                            
                            # transform extracted data to staging format, assign platform id
                            client.query """with transformed as (
                                select
                                ts::timestamp with time zone,
                                -- change the platform_id to match it up with 
                                -- the correct platform
                                $1::int as platform_id,
                                temp_degc::numeric, 
                                humidity::numeric, 
                                no2_raw::numeric, 
                                no2::numeric, 
                                co_raw::numeric,
                                co::numeric,
                                voc_raw::numeric,
                                voc::numeric
                                from """ + tempTable + """ where ts is not null)
                                select *
                                into staging.sensor_data
                                from transformed ;""", [platformId], (err, result5) -> 
                                    return cb err if err
                                    console.log 'post-transform: rowcount =', result5.rowCount
                        
                                    # insert final data into the fact table
                                    client.query """insert into fact.sensor_data (
                                        ts, platform_id, temp_degc, humidity, no2_raw, no2, co_raw, co, voc_raw, voc) 
                                        select * from staging.sensor_data;""", [], (err, result6) ->

                                            #call end of transaction, handle rollback or commit there
                                            cb err, result6


        # kick off the whole chain
        withTransaction copyToTempTable, topLevelCb
        

module.exports = Storage

