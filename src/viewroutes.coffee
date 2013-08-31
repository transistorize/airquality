#
#  Handles custom, dynamically rendered views
#

"use strict"

config = require 'config'


class ViewRoutes

    constructor: (app, @storage) ->
        app.get '/p/:uid', @getPageByUid

    
    # '/p/:uid'
    getPageByUid: (request, response) =>
        @storage.getPlatformByUid request.params.uid, (err, platform) ->
            if !err
                if platform[0]?.uid
                    response.render 'egg.ejs', { platformUid: platform[0].uid, platformName: platform[0].name }
                else
                    response.status(404).send "sorry, can't find a platform by that name"
            else
                response.status(500).send error: 'internal server error: ' + err

        

module.exports = ViewRoutes
