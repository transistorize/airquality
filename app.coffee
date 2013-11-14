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
port = process.argv[2] || config.WebService.port

# data layer
storage = new Storage()


# custom middleware
allowCrossDomain = (req, res, next) ->
    res.header 'Access-Control-Allow-Origin', config.WebService.allowedDomains
    res.header 'Access-Control-Allow-Methods', 'GET,OPTIONS'
    res.header 'Access-Control-Allow-Headers', 'Content-Type'
    next()


# used by process handlers
closeApp = () ->
    try
        console.log 'App shutting down ...'
        storage.exit();
        console.log 'Goodbye!'
    catch e
        console.error e

# production middleware, 404, 500 error handlers
clientErrorHandler = (err, req, res, next) ->
    if req.xhr 
        res.status(500).send error: 'client error'
    else
        next err

errorHandler = (err, req, res, next) ->
    res.status(500).render('error', { error: err });


# configure standard options
app.configure () ->

    app.set 'title', 'Cypress Hills Air Quality Project'
    app.engine 'html', require('ejs').renderFile
    
    # app.use allowCrossDomain
    app.use express.compress()  # enable gzip compression
    app.use express.favicon()
    app.use express.methodOverride()
    
    # handle form file uploads, with data stored in configured location
    app.use express.json()
    app.use express.urlencoded()
    app.use express.bodyParser uploadDir: config.WebService.uploadsDir, encoding: 'utf8'
    
    # enable static serving of data
    app.use express.static('public')

    # Attach routes and views
    new Routes(app, storage)
    new Views(app, storage)


# development middleware
app.configure 'development', () ->
    console.log 'configure development'
    app.use express.logger('dev')
    app.use express.errorHandler()
    

app.configure 'production', () ->
    console.log 'configure production'
    app.use express.logger()
    app.use clientErrorHandler
    app.use errorHandler


# connect listener
console.log 'listening via HTTP on', port
server = app.listen port


# process clean up handlers
closeServer = () ->
    try
        server.close()
    catch e
        console.error 'server close called again'

server.on 'close', closeApp

process.on 'exit', () ->
    console.log 'process exit'
    closeServer()

process.on 'uncaughtException', (err) ->
    console.error '\ncaught exception:', err
    closeServer()

console.log 'all handlers attached - startup complete'

