Connection = require '../connection'

describe 'Generate and Store Token', ->
  beforeEach (done) ->
    @connection = new Connection
    @connection.connect (error, {@server, @client, @jobManager}) =>
      return done error if error?
      done()

  afterEach (done) ->
    @connection.stopAll done

  describe 'when generateAndStoreToken is called', ->
    beforeEach (done) ->
      message = JSON.stringify callbackId: 'callback-eye-D'
      @client.publish 'generateAndStoreToken', message, done

    it 'should create a generateAndStoreToken job', (done) ->
      @jobManager.do (request, callback) =>
        expect(request.metadata.responseId).to.exist
        delete request.metadata.responseId # We don't know what its gonna be

        expect(request).to.containSubset
          metadata:
            jobType: 'CreateSessionToken'
            auth: {uuid: 'u', token: 'p'}
            toUuid: 'u'
          rawData: 'null'

        done()

    describe 'when the generateAndStoreToken fails', ->
      beforeEach (done) ->
        @client.on 'error', (@error) => done()

        @jobManager.do (request, callback) =>
          response =
            metadata:
              responseId: request.metadata.responseId
              code: 403
              status: 'Forbidden'

          callback null, response

      it 'should send an error message to the client', ->
        expect(=> throw @error).to.throw 'generateAndStoreToken failed: Forbidden'

    describe 'when the generateAndStoreToken succeeds', ->
      beforeEach (done) ->
        @client.on 'message', (@fakeTopic, @buffer) => done()

        @jobManager.do (request, callback) =>
          response =
            metadata:
              responseId: request.metadata.responseId
              code: 200
              status: 'No Content'
            rawData: '{"uuid":"u","token":"t"}'

          callback null, response

      it 'should send a success message to the client', ->
        message = JSON.parse @buffer.toString()
        expect(message).to.containSubset
          topic: 'generateAndStoreToken'
          data:
            uuid: 'u'
            token: 't'
          _request:
            callbackId: 'callback-eye-D'

    describe 'when the generateAndStoreToken times out', ->
      beforeEach (done) ->
        @timeout 3000
        @client.on 'error', (@error) => done()
        @jobManager.do (request, callback) =>
          return done error if error?

      it 'should send an error message to the client', ->
        expect(=> throw @error).to.throw 'Response timeout exceeded'
