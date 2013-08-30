#
# Handles routes
#

"use strict"

config = require 'config'
Storage = require './storage'

class Routes

    constructor: (app) ->
        @storage = new Storage()
        app.get '/', @welcome
        app.get '/eggs', @listByPage
        app.get '/eggs/p/:page?*', @listByPage
        app.get '/eggs/uid/:uid', @getByUid
        app.get '/eggs/id/:pid', @getById
        app.get '/eggs/uid/:uid/data/:page?*', @getDataByUidAndPage
        app.get '/query/col/:columns', @getDataByColumn
        app.post '/upload', @postForm
    
        ###
        app.post '/eggs', routes.addNew
        app.del '/eggs/id/:pid', routes.removeById
        app.post '/eggs/id/:pid/data', routes.addDataById
        ###

    # '/', processor.welcomeJson
    welcome: (request, response) ->
        response.json msg: 'Welcome to the Cypress Hills Air Quality Project'

    # '/upload', processor.postForm
    postForm:  (request, response) ->
        console.log 'data_present=', request.files.datafile?
        if request.files.datafile
            meta = request.files.datafile
            console.log meta.filename
    
            response.json
                status: 'upload successful'
                name: meta.filename
                size: meta.size
                type: meta.type
        else
            response.status(500).send
                error: 'uploaded data not parsed correctly, please contact your administrator'

    # '/eggs/p/:page', processor.listByPage
    listByPage: (request, response) =>
        page = +request.params.page || 0
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
        page = +request.params.page || 0
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

    # '/eggs/id/:pid/data', processor.addDataById
module.exports = Routes

