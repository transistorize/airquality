#
# Handles data routes
#

"use strict"

config = require 'config'
_ = require 'underscore'

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
                    response.status(500).send status: 'rejected', error: err
        else
            reponse.status(400).send status: 'rejected', error: 'body had insufficient content, bad request'
                   
    # POST '/upload/:type', processor.postForm
    postForm:  (request, response) =>
        console.log 'file type =', request.params.type, ', platform type =', request.body.platform_type, 
            ', uid =', request.body.platform_uid, ', name=', request.body.name,  '\ndata_present=', (request.files != null)
   
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
                    request.body.platform_uid = platform.uid
                    request.body.platform_id = platform.id
                    @postDataByUid request, response
                else 
                    response.status(500).send status: 'rejected', error: 'could not create record for egg'
        else
            @postDataByUid request, response
    
    postDataByUid: (request, response) =>   
        # TODO better arg checking    
        # TODO create new platform if it does not exist 
        if request.files?.datafiles and request.body?.platform_uid
            
            if _.isObject(request.files?.datafiles) and _.has(request.files?.datafiles, 'name') 
                meta = [ request.files.datafiles ] 
            else
                meta = request.files.datafiles
                        
            @storage.bulkCSVImport request.body.platform_uid, meta, (err, result) => 
                console.log 'return from import', err, result
                if !err
                    response.redirect('p/' + request.body.platform_uid)
                else
                    console.error err
                    response.status(500).send status: 'rejected', error: 'transformation failed'
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

