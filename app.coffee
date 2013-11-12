#
# The main webserving application
# call with something like:
#    coffee app.coffee
#

"use strict"

config  = require 'config'
express = require 'express'
Storage = require './src/storage'
Routes  = require './src/routes'
Views   = require './src/viewroutes'


app = express()
# data layer
storage = new Storage()
port = process.argv[2] || config.WebService.port

#CORS middleware
allowCrossDomain = (req, res, next) ->
    res.header 'Access-Control-Allow-Origin', config.WebService.allowedDomains
    res.header 'Access-Control-Allow-Methods', 'GET,OPTIONS'
    res.header 'Access-Control-Allow-Headers', 'Content-Type'
    next()


app.configure () ->

    app.set 'title', 'Cypress Hills Air Quality Project'
    app.engine 'html', require('ejs').renderFile
    
    # TODO install more robust error handler, for 404s
    # app.use allowCrossDomain

    app.use express.compress()  # enable gzip compression
    app.use express.errorHandler()
    app.use express.favicon()
    app.use express.methodOverride()
    
    # handle form file uploads, with data stored in configured location
    app.use express.bodyParser uploadDir: config.WebService.uploadsDir
    
    # enable static serving of data
    # app.use express.directory('public')
    app.use express.static('public')

    # Attach routes and views
    new Routes(app, storage)
    new Views(app, storage)


#configurations specific to this config environment
app.configure 'development', () ->
    console.log 'configure development'
    app.use express.logger('dev')

closeApp = () ->
    try
        console.log 'App shutting down ...'
        storage.exit();
        console.log 'Goodbye!'
    catch e
        console.error e


console.log 'listening via HTTP on', port
server = app.listen port

closeServer = () ->
    try
        server.close()
    catch e
        console.error 'server close called again'
        return

server.on 'close', closeApp

process.on 'SIGTERM', () ->
    console.log '\ncaught SIGTERM - shutting down'
    closeServer()

process.on 'uncaughtException', (err) ->
    console.log '\ncaught exception:', err
    closeServer()

console.log 'all handlers attached - startup complete'

