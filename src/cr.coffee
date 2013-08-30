#
# Clients describe @changes throught this mapping
# The storage set of classes actually executes the change
#

"use strict"

class ChangeRequest
        
    constructor: (@uuid)  ->
        @changes = {}

    changeAttr: (attribute, value) ->
        throw new Error 'empty value' if !value
        checkNameOf attribute
        @changes[attribute] = value

    deleteAttr: (attribute) ->
        stdCheck attribute
        delete @changes[attribute] if @changes[attribute]
        @changes['__deletes'][attribute] = '__del__'
    
    createSeq: (attribute, schema) ->
        throw new Error 'empty schema' if !schema
        checkNameOf attribute
        @changes['__seq_schema'][attribute] = schema

    addToSeq: (attribute, value) ->
        checkNameOf attribute
        @changes['__seq'] = @changes['__seq'] || {}
        @changes['__seq'][attribute] = @changes['__seq'][attribute] || []
        @changes['__seq'][attribute].push(value)

    deleteSeq: (attribute) ->
        checkNameOf attribute
        @changes['__deletes'][attribute] = '__deleted__'

    checkNameOf = (attribute) ->
        throw new Error 'empty change or deletion attribute' if !attribute
        throw new Error 'illegal attribute name' if attribute == '__deletes' or attribute == '__seq'


module.exports = ChangeRequest

