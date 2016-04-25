module.exports = (env) ->

  Promise = env.require 'bluebird'

  class MqttDimmer extends env.devices.DimmerActuator
  
    constructor: (@config, @plugin, lastState) ->
      @name = @config.name
      @id = @config.id
      @_state = lastState?.state?.value or off
      @_dimlevel = lastState?.dimlevel?.value or 0
      @resolution = (@config.resolution - 1) or 255

      if @plugin.connected
        @onConnect()

      @plugin.mqttclient.on('connect', =>
        @onConnect()
      )

      # For reflecting external condition
      @plugin.mqttclient.on 'message', (topic, message) =>
        if @config.topic == topic
          payload = message.toString()
          @getPerCentlevel(payload)
          if @perCentlevel != @_dimlevel
            @_setDimlevel(@perCentlevel)
            @emit @dimlevel, @perCentlevel

      super()

    onConnect: () ->
      @plugin.mqttclient.subscribe(@config.topic)
      if @stateTopic
        @plugin.mqttclient.subscribe(@config.stateTopic)


    # Convert the PWM resolution by config value
    # Suppport for CIE correction will be added latter
    getDevLevel: (perCentlevel) ->
      @devLevel = (perCentlevel * (@resolution / 100)).toFixed(0)
      return @devLevel

    # Convert device resolution value back to percent value
    getPerCentlevel: (devlevel) ->
      perCentlevel = ((devlevel + 0.5 * 100) / @resolution).toFixed(0)
      @perCentlevel = parseInt(perCentlevel, 10)
      return @perCentlevel

    turnOn: ->
      @getDevLevel(100)
      @plugin.mqttclient.publish(@config.topic, @devLevel)
      return Promise.resolve()
      
    turnOff: ->
      @plugin.mqttclient.publish(@config.topic, 0)
      return Promise.resolve()

    changeDimlevelTo: (dimlevel) ->
      @getDevLevel(dimlevel)
      @plugin.mqttclient.publish(@config.topic, @devLevel)
      @_setDimlevel(dimlevel)
      return Promise.resolve()

    getDimlevel: -> Promise.resolve(@_dimlevel)

    destroy: () ->
     @plugin.mqttclient.unsubscribe(@config.topic)
     if @stateTopic
       @plugin.mqttclient.unsubscribe(@config.stateTopic)
     super()