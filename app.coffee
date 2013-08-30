#
# The main webserving application
# call with something like:
#    coffee app.coffee
#

"use strict"

config  = require('config')
express = require('express')
Routes  = require('./src/routes')

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
    
    app.use express.compress()  # enable gzip compression
    
    # TODO install more robust error handler, for 404s
    # app.use allowCrossDomain
    app.use express.errorHandler()
    app.use express.favicon()
    app.use express.methodOverride()
    
    # handle form file uploads, with data stored in configured location
    app.use express.bodyParser uploadDir: config.WebService.uploadsDir
    
    # enable static serving of data
    # app.use express.directory('public')
    app.use express.static('public')

    # non-static routes 
    new Routes(app)


#configurations specific to this config environment
app.configure 'development', () ->
    console.log 'configure development'
    app.use express.logger('dev')
        

console.log 'listening via HTTP on', port
app.listen port



