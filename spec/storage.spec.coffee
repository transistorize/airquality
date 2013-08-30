#
# spec file
#

"use strict"

config   = require 'config'
pg       = require 'pg'
Storage  = require '../dist/src/storage'

# gloabal test holder
test = {}

# test setup
jasmine.getEnv().defaultTimeoutInterval = 3000

beforeEach ->
    test.storage = new Storage()

describe 'storage class', ->
    it 'reset the db', (done) ->
        client = new pg.Client(config.Postgres.connection)
        client.connect (err) ->
            expect(err).toBeNull()
            if (err) then client.end()
            else client.query 'truncate dim.platform cascade', (err, result) ->
                expect(err).toBeNull()
                client.end()
                done()

    it 'should be able to get the system uuid', (done) ->
        test.storage.getSystemUuid (err, uuid) ->
            expect(err).toBeNull()
            expect(uuid).toBeDefined()
            done()

    it 'should throw an error when get with null uuid called', ->
        expect(test.storage.getUidsForName).toThrow()

    it 'should not find any platforms that match based on name', (done) ->
        test.storage.getUidsForName 'platform1', (err, uids) ->
            expect(err).toBeNull()
            expect(uids).toBeDefined()
            expect(uids?.length).toEqual 0
            done()
   
    it 'should throw an error when create called with no name', ->
        expect(test.storage.getUidsForName).toThrow()

    it 'should be able to create a new platform', (done) ->
        test.storage.createPlatform 'platform1', (err, platform) ->
            expect(err).toBeNull()
            expect(platform).toBeDefined()
            expect(platform.uid).not.toBeNull()
            done()
    
    it 'should NOW find a platform that matches based on name', (done) ->
        test.storage.getUidsForName 'platform1', (err, uids) ->
            expect(err).toBeNull()
            expect(uids).toBeDefined()
            expect(uids?.length).toEqual 1
            expect(uids?[0]).toBeDefined()
            done()

    it 'should get the first the first platform created', (done) ->
        test.storage.getPlatforms 0, 300, (err, platforms) ->
            expect(err).toBeNull()
            expect(platforms).toBeDefined()
            expect(platforms?.length).toEqual 1
            expect(platforms?[0]).toBeDefined()
            done()

    it 'should throw an error when searching with a null uuid', ->
        expect(test.storage.getPlatform).toThrow()

    it 'should return the empty array when getting a non-existent platform', (done) ->
        test.storage.getPlatform '4a9768be-ff09-11e2-bb0a-001b639514a9', (err, platform) ->
            expect(err).toBeNull()
            expect(platform).toBeDefined()
            expect(platform.length).toEqual 0
            done()
    
    it 'should throw an error when updating with no arguments', ->
        expect(test.storage.update).toThrow()

    it 'should reject updates to non-existent platforms', (done) ->
        cr = test.storage.createChange '4a9768be-ff09-11e2-bb0a-001b639514a9'
        cr.changeAttr 'foo', 'a'
        cr.changeAttr 'foo', 'b'
        test.storage.update cr, (err, result) ->
            expect(err).toBeNull()
            expect(result).toEqual 1
            done()

    #it 'should accept updates to known platforms' -> (done) ->
    #    test.storage.update

    # this spec always has to be last - stop the pg background pool
    it 'should be able to release all resources permanently', ->
        expect(test.storage.exit).not.toThrow()

