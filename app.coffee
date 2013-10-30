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


process.on 'exit', () ->
    console.log 'Goodbye!'

app = express()
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

    # non-static routes
    storage = new Storage()
    process.on 'uncaughtException', (err) ->
        console.log 'Caught exception:', err
        storage.exit()
    process.on 'exit', () ->
        storage.exit()


    new Routes(app, storage)
    new Views(app, storage)


#configurations specific to this config environment
app.configure 'development', () ->
    console.log 'configure development'
    app.use express.logger('dev')
        

console.log 'listening via HTTP on', port
app.listen port

