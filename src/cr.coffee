#
# Clients describe @changes throught this mapping
# The storage set of classes actually executes the change
#

"use strict"

_ = require "underscore"

class ChangeRequest
        
    constructor: (@uuid)  ->
        @changes = { __attr: {}, __del: {}, __seq:{} }
    
    hasAttr: (attribute) ->
        return _.has(@changes['__attr'], attribute)

    changeAttr: (attribute, value) ->
        throw new Error 'empty value' if !value
        checkNameOf attribute
        @changes['__attr'][attribute] = value
    
    #not all backends may respect this
    deleteAttr: (attribute) ->
        checkNameOf attribute
        delete @changes['__attr'][attribute]
        delete @changes['__seq'][attribute]
        @changes['__del'][attribute] = '__del__'
    
    hasSeq: (attribute) ->
        return _.has(@changes['__seq'], attribute)

    addToSeq: (attribute, value) ->
        checkNameOf attribute
        @changes['__seq'] = @changes['__seq'] || {}
        @changes['__seq'][attribute] = @changes['__seq'][attribute] || []
        @changes['__seq'][attribute].push(value)

    deleteSeq: (attribute) ->
        checkNameOf attribute
        @changes['__del'][attribute] = '__deleted__'

    getChanges: () ->
        #shallow copy only
        return _.clone(@changes['__attr'])

    getDeletes: () ->
        #shallow copy only
        return _.clone(@changes['__del'])

    getSequences: () ->
        #shallow copy only
        return _.clone(@changes['__seq'])

    checkNameOf = (attribute) ->
        throw new Error 'undefined attribute name not allowed' if !attribute

module.exports = ChangeRequest

