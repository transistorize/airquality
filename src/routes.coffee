#
# Handles data routes
#

"use strict"

config = require 'config'
_ = require 'underscore'
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
        #app.post '/eggs', @update
        
        ###
        app.del '/eggs/id/:pid', routes.removeById
        app.post '/eggs/id/:pid/data', routes.addDataById
        ###

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
        if request.params.type is 'test'
            return response.json [request.body, request.files]
        
        if request.params.type is 'redirect'
            return response.redirect('p/' + request.body.platform_uid)
        
        if request.params.type isnt 'csv'
            return response.status(400).send status: 'rejected', error: 'file type not supported'

        if !request.body.name and !request.body.platform_uid
            return response.status(400).send status: 'rejected', error: 'name not provided'
        
        if !request.body.platform_uid and request.body.name
            body = {name: request.body.name}
            @storage.createPlatform body, (err, platform) =>
                if !err 
                    console.log 'create returned', platform
                    request.body.platform_uid = platform.uid
                    request.body.platform_id = platform.id
                    @updatePlatformByUid request, response
                else 
                    console.error err
                    response.status(500).send status: 'rejected', error: 'could not create record for egg'
        else
            @updatePlatformByUid request, response
    
    updatePlatformByUid: (request, response) =>   
        console.log 'entered updatePlatformByUid'

        if request.body?.platform_uid
            b = request.body
            cr = new ChangeRequest(b.platform_uid)
            
            cr.changeAttr('meta.group', b.group) if b.group
            cr.changeAttr('name', b.name) if b.name
            cr.changeAttr('description', b.description) if b.description
            
            console.log 'parsing=', b.platform_loc
            try 
                if b.platform_loc 
                    coords = JSON.parse(b.platform_loc)
                    if not _.isNaN(coords[0]) and not _.isNaN(coords[1])
                        cr.changeAttr('lat', coords[0])
                        cr.changeAttr('lng', coords[1])
            catch e
                console.error e

            console.log 'changes: ', JSON.stringify(cr.getChanges())

            @storage.updatePlatform cr, (err, result) =>
                if !err
                    @importData request, response
                else
                    console.error err
                    response.status(500).send status: 'rejected', error: 'data could not be updated'
        else
            response.status(400).send status: 'reject', error: 'no uid, bad request'

    importData: (request, response) =>
        if request.files?.datafiles and request.body?.platform_uid
            if _.isObject(request.files?.datafiles) and _.has(request.files?.datafiles, 'name') 
                meta = [ request.files.datafiles ] 
            else
                meta = request.files.datafiles
            
            meta = meta.filter (f) -> f.size > 0

            @storage.bulkCSVImport request.body.platform_uid, meta, (err, result) => 
                console.log 'return from import', err, result
                if !err
                    response.redirect('eggsitting/p/' + request.body.platform_uid)
                else
                    console.error err
                    response.status(500).send status: 'rejected', error: 'transformation failed'
        else if request.body?.platform_uid
            response.redirect('eggsitting/p/' + request.body.platform_uid)
        else
            response.status(400).send status: 'rejected', error: 'no uid, bad request'
       
    # '/eggs/p/:page', processor.listByPage
    listByPage: (request, response) =>
        page = +request.params.page or 0
        @storage.getPlatforms page, 20, (err, platforms) ->
            if !err
                response.send 'platforms': platforms, 'page': page
            else
                response.status(500).send error: 'internal server error: ' + err

    #'/eggs/id/:pid', processor.getById
    getById: (request, response) =>
        return response.status(404).send 'resource not found' if !request.params.pid
        @storage.getPlatformById +request.params.pid, (err, platform) ->
            if !err
                response.send 'platforms': platform
            else
                response.status(500).send error: 'internal server error: ' + err

    #'/eggs/uid/:uid', processor.getByUid
    getByUid: (request, response) =>
        return response.status(404).send 'resource not found' if !request.params.uid
        @storage.getPlatformByUid request.params.uid, (err, platform) ->
            if !err
                response.send 'platforms': platform
            else
                response.status(500).send error: 'internal server error: ' + err
    
    # '/eggs/uid/:uid/data/:page', processor.getDataByIdAndPage
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


module.exports = Routes

