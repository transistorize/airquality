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

app.configure () ->

    app.set 'title', 'Cypress Hills Air Quality Project'
    
    # enable gzip compression
    app.use express.compress()

    # enable static serving of data
    app.use express.directory('public')
    app.use express.static('public')

    # TODO install more robust error handler, for 404s
    app.use express.errorHandler()
    app.use express.favicon()

    # handle form file uploads, with data stored in configured location
    app.use express.bodyParser uploadDir: config.WebService.uploadsDir
    
    # non-static routes 
    app.set 'views', __dirname + '/views'
    new Routes(app)


#configurations specific to this config environment
app.configure 'development', ->
    console.log 'configure development'
    app.use express.logger('dev')
        

console.log 'listening via HTTP on', port
app.listen port



