#
# Handles data routes
#

"use strict"

config = require 'config'
_ = require 'underscore'
fs = require 'fs'
ChangeRequest = require './cr'

class Routes

    constructor: (app, @storage) ->
        app.get '/', @welcome
        app.get '/eggs', @listByPage
        app.get '/eggs/p/:page?*', @listByPage
        app.get '/eggs/uid/:uid', @getByUid
        app.get '/eggs/id/:pid', @getById
        app.get '/eggs/uid/:uid/data/:page?*', @getDataByUidAndPage
        app.get '/query/col/:columns', @getDataByColumn
        app.post '/upload/:type', @postForm
        #app.post '/eggs/uid/:uid/comment', @addComment
        #app.post '/eggs/uid/:uid/pic', @addPicture
        app.del '/eggs/uid/:uid', @deleteByUid

    # '/'
    welcome: (request, response) ->
        response.json msg: 'Welcome to the Cypress Hills Air Quality Project'

    # POST '/eggs'
    addNewOrModify: (request, response) =>
        console.log request.body
        if request.body && _.has(request.body, 'name')
            @storage.createNewPlatform request.body, (err, platform) ->
                if !err
                    response.send status: 'ok', platforms: [ platform ]
                else
                    console.err err
                    response.status(500).send status: 'rejected', error: err
        else
            reponse.status(400).send status: 'rejected', error: 'body had insufficient content, bad request'
                   
    # POST '/upload/:type', processor.postForm
    postForm:  (request, response) =>
        #clean up temp files
        
        console.log 'entered post'

        if _.isObject(request.files?.datafiles) and _.has(request.files?.datafiles, 'name') 
            request.meta = [ request.files.datafiles ] 
        else
            request.meta = request.files.datafiles

        done = () ->
            console.log 'clean up temp files'
            request.meta.forEach((f) -> fs.unlinkSync(f.path))

        if request.params.type is 'test'
            return response.json([request.body, request.files]) && done()
        
        if request.params.type is 'redirect'
            return response.redirect('p/' + request.body.platform_uid) && done()
        
        if request.params.type isnt 'csv'
            return response.status(400).send({status: 'rejected', error: 'file type not supported'}) && done()

        if !request.body.name and !request.body.platform_uid
            return response.status(400).send({status: 'rejected', error: 'name not provided'}) && done()
        

        tryUpdate = () =>
            try
                @updatePlatformByUid request, response, done
            catch e
                console.error 'updatePlatformByUid threw exception - calling cleanup: ', e
                done()

        if !request.body.platform_uid and request.body.name
            body = {name: request.body.name}

            console.log 'create platform'
            @storage.createPlatform body, (err, platform) =>
                if !err 
                    console.log 'create returned', platform
                    request.body.platform_uid = platform.uid
                    request.body.platform_id = platform.id
                    console.log 'about to call try update'
                    tryUpdate()
                else 
                    response.status(500).send status: 'rejected', error: 'could not create record for egg'
                    console.error err
                    done()
        else
            console.log 'not new platform'
            tryUpdate()


    updatePlatformByUid: (request, response, done) =>   
        console.log 'entered updatePlatformByUid'

        if request.body?.platform_uid
            b = request.body
            cr = new ChangeRequest(b.platform_uid)           
            cr.changeAttr('meta.group', b.group) if b.group
            cr.changeAttr('name', b.name) if b.name
            cr.changeAttr('description', b.description) if b.description
            cr.addToSeq('images', b.picture) if b.picture
            
            console.log 'parsing location=', b.platform_loc
            try 
                if b.platform_loc 
                    coords = JSON.parse(b.platform_loc)
                    console.log 'we parsed:', coords
                    if not _.isNaN(coords.lat) and not _.isNaN(coords.lng)
                        cr.changeAttr('lat', coords.lat)
                        cr.changeAttr('lng', coords.lng)
            catch e
                console.error 'Error parsing JSON coordindates:', e, ' ', b.platform_loc

            @storage.updatePlatform cr, (err, result) =>
                if !err
                    try
                        @importData request, response, done
                    catch e
                        console.error 'importData threw exception - calling done', e
                        done()
                else
                    response.status(500).send status: 'rejected', error: 'data could not be updated'
                    console.error 'updatePlatform returned an error:', err
                    done()
        else
            response.status(400).send status: 'reject', error: 'no uid, bad request'
            done()

    importData: (request, response, done) =>
        console.log 'entered importData', _.size(request.meta)

        if request.meta and request.body?.platform_uid
            
            files = request.meta.filter (f) -> f.size > 0

            @storage.bulkCSVImport request.body.platform_uid, files, (err, result) -> 
                console.log 'return from import: ', result
                if !err
                    response.redirect('eggsitting/p/' + request.body.platform_uid)
                else
                    response.status(500).send status: 'rejected', error: 'transformation failed'
                    console.error err
                done()
        else if request.body?.platform_uid
            response.redirect('eggsitting/p/' + request.body.platform_uid)
            done()
        else
            response.status(400).send status: 'rejected', error: 'no uid, bad request'
            done()
       
    # '/eggs/p/:page'
    listByPage: (request, response) =>
        page = +request.params.page or 0
        @storage.getPlatforms page, 20, (err, platforms) ->
            if !err
                response.send 'platforms': platforms, 'page': page
            else
                response.status(500).send error: 'internal server error: ' + err

    #'/eggs/id/:pid'
    getById: (request, response) =>
        return response.status(404).send 'resource not found' if !request.params.pid
        @storage.getPlatformById +request.params.pid, (err, platform) ->
            if !err
                response.send 'platforms': platform
            else
                response.status(500).send error: 'internal server error: ' + err

    #'/eggs/uid/:uid'
    getByUid: (request, response) =>
        return response.status(404).send 'resource not found' if !request.params.uid
        @storage.getPlatformByUid request.params.uid, (err, platform) ->
            if !err
                response.send 'platforms': platform
            else
                response.status(500).send error: 'internal server error: ' + err
    
    # '/eggs/uid/:uid/data/:page'
    getDataByUidAndPage: (request, response) =>
        return response.status(404).send 'resource not found' if !request.params.uid
        page = +request.params.page or 0
        uid = request.params.uid
        @storage.getDataByUidAndPage uid, page, (err, data) ->
            if !err
                response.send 'uid': uid, 'data': data
            else
                response.status(500).send error: 'internal server error: ' + err
    
    # '/query/col/:column'
    getDataByColumn: (request, response) =>
        return response.status(404).send 'resource not found' if !request.params.columns
        columns = request.params.columns
        @storage.getDataByColumn columns, (err, data) ->
            if !err
                response.send 'query': columns, 'data': data
            else
                response.status(500).send error: 'internal server error: ' + err

    #'/eggs/uid/:uid'
    deleteByUid: (request, response) =>
        return response.status(404).send 'resource not found' if !request.params.uid
        uid = request.params.uid
        @storage.deleteByUid uid, (err, platform) ->
            if !err
                response.send 'platforms': platform, 'status': 'deleted'
            else
                response.status(500).send error: 'internal server error: ' + err
    
    #'/eggs/uid/:uid/comment'
    addComment: (request, response) =>
        return response.status(403).send 'bad request' if !request.body?.comment or !request.params.uid
        
        uid = request.params.uid
        cr = new ChangeRequest(uid)
        cr.addToSeq('comments', b.comment) if b.comment
        
        @storage.updatePlatform cr, (err, platform) ->
            if !err
                response.send 'platforms': platform, 'status': 'ok'
            else
                response.status(500).send error: 'internal server error: ' + err

    #'/eggs/uid/:uid/pic'
    addPicture: (request, response) =>
        if request.files?.datafiles and request.body?.platform_uid
            if _.isObject(request.files?.datafiles) and _.has(request.files?.datafiles, 'name') 
                uid = request.params.uid
                cr = new ChangeRequest(uid)
                picture_url = 'foo' # todo
                cr.addToSeq('comments', picture_url)
                # move picture to public serving folder
                @storage.updatePlatform cr, (err, platform) ->
                    if !err
                        response.send 'platforms': platform, 'status': 'deleted'
                    else
                        response.status(500).send error: 'internal server error: ' + err

        else
            response.status(403).send 'bad request' if !request.body?.picture_url or !request.params.uid
        


module.exports = Routes

