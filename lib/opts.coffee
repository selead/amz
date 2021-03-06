###
Options parser
###

fs = require "fs"

###
Options, stored in config file
###
class Opts

  ###
  Create options object
  ###
  constructor: (opts={}) ->
    if opts.vc                  # virtual config
      @virtualConfig = yes
      @config = {}
      @extendConfig opts
    else
      @configFile = opts.configFile or "#{process.env.HOME}/.amz"
      @load()

  ###
  Set default options.
  ###
  _setDefaults: ->
    @config                    ||= {}
    @config.awsAccessKey       ||= process.env.AWS_ACCESS_KEY
    @config.awsSecretKey       ||= process.env.AWS_SECRET_KEY
    @config.awsKeypairName     ||= process.env.AWS_KEYPAIR_NAME
    @config.awsSecurityGroup   ||= process.env.AWS_SECURITY_GROUP || "default"
    @config.awsInstanceType    ||= process.env.AWS_INSTANCE_TYPE || "m1.small"
    @config.awsImageId         ||= process.env.AWS_IMAGE_ID
    @config._amzScriptSettings ||= "#{process.env.HOME}/.amzscripts"
    @config._history           ||= []
    @config._mashineNames      ||= {}

  ###
  Add named instance
  ###
  addNamedInstance: (name, instanceId) ->
    unless @config._mashineNames[name]
      @config._mashineNames[name] = [instanceId]
    else
      @config._mashineNames[name].push instanceId
    @save()

  # removeNamedInstance: (name, instanceId) ->
  #   #foobar
  #   @save()


  # removeAllInstansesForName: (name) ->
  #   delete @config._mashineNames[name]
  #   @save()

  removeAllInstanses: ->
    @config._mashineNames = {}
    @save()

  ###
  Get instance name by in (or null)
  ###
  getInstanceName: (instanceId) ->
    for name, instList of @config._mashineNames
      if instanceId in instList
        return name
    return null

  ###
  Extend config dictionary
  ###
  extendConfig: (cfg={}) ->
    @config[k] = v for k, v of cfg


  ###
  Check nessesary options and return array of keys, that must be set.
  ###
  checkOpts: ->
    missed = []
    unless @config.awsAccessKey
      missed.push "awsAccessKey"
    unless @config.awsSecretKey
      missed.push "awsSecretKey"
    # unless @config.awsSecurityGroup
    #   missed.push "awsSecurityGroup"
    # unless @config.awsInstanceType
    #   missed.push "awsInstanceType"
    return missed

  ###
  Load scripts settings
  ###
  _loadScriptsSettings: ->
    try
      @scripts = JSON.parse fs.readFileSync @config._amzScriptSettings
      # data is an object, consists of key and value
    catch e
      if e.code in ["EBADF", "ENOENT"]
        # create new
        @scripts = {}
        @storeScriptSettings()
      else
        throw e

  storeScriptSettings: ->
    fs.writeFileSync @config._amzScriptSettings, JSON.stringify @scripts

  _getScriptType: (script) ->
    stype       = "unknown"
    firstLine   = script.split("\n")[0].trim()
    if 0 is firstLine.indexOf "#!/"
      # get last word
      splitter  = 0 < firstLine.indexOf(" ") and " " or "/"
      stype     = firstLine.split(splitter)[-1..][0]
    stype

  addScript: (name, path) ->
    unless name
      return console.log "name option missed"
    unless path
      return console.log "path option missed"
    stat = fs.statSync path
    unless stat.isFile()
      return console.log "path not exist"

    content = fs.readFileSync path, "utf-8"

    what = "added"
    if @scripts[name]           # rewrite
      what                    = "updated"
      @scripts[name].data     = content
      @scripts[name].updated  = Date.now()
      @scripts[name].type     = @_getScriptType content
    else                        # create new
      @scripts[name] =
        data    : content
        created : Date.now()
        updated : Date.now()
        type    : @_getScriptType content
    @storeScriptSettings()
    console.log "#{@scripts[name].type} script #{name} (#{(content.length/1024).toFixed 2}) #{what} successfull"

  ###
  Load config file and scripts file
  ###
  load: ->
    try
      @config = JSON.parse fs.readFileSync @configFile
      @_setDefaults()
    catch e
      if e.code in ["EBADF", "ENOENT"]
        # create new config
        @_setDefaults()
        @save()
      else
        throw e
    @_loadScriptsSettings()

  ###
  Update config params
  ###
  update: (params={}, value=null) ->
    if "string" is typeof params
      @set params, value
    else
      for k,v of params
        @set k, v
    @save()

  ###
  Add new history entry
  ###
  addToHistory: (str) ->
    prevStr = @config._history[-1..][0]
    unless prevStr is str
      @config._history.push str
    @save()

  ###
  Remove all history items
  ###
  resetHistory: ->
    @config._history = []
    @save()

  ###
  Get copy of history list
  ###
  getHistory: ->
    @config._history[0..-1]

  ###
  Set config key

  @param {String} key Config key
  @param {String} value Value for key
  ###
  set: (key, value) ->
    @config[key] = value

  remove: (keysList=[]) ->
    if "string" in typeof keysList
      delete @config[keysList]
    else
      for k in keysList
        delete @config[k]
    @save()

  ###
  Save config state
  ###
  save: ->
    unless @virtualConfig
      fs.writeFileSync @configFile, JSON.stringify @config

  ###
  Dump all config to console
  ###
  dump: ->
    console.log "Config parameters:"
    for k,v of @config
      if 0 == k.indexOf "_" # hidden params
        continue
      else
        console.log "#{k} = #{v}"

  get: (key, defaultVal=null) ->
    @config[key] || defaultVal

  ###
  Get list of keys, matching pattern

  ###
  keys: (pattern) ->
    result = []
    for k,v of @config
      if -1 < k.indexOf pattern
        result.push k
    result

exports.config = (confFile) ->  new Opts confFile
