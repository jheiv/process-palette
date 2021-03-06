_ = require 'underscore-plus'
ProcessConfig = require '../process-config'
SaveController = require './save-controller'
ProcessController = require './process-controller'
{Directory, File, BufferedProcess, CompositeDisposable} = require 'atom'

module.exports =
class ConfigController

  constructor: (@projectController, @config) ->
    @processControllers = [];
    @listeners = [];
    cssSelector = 'atom-workspace';

    if (@config.outputTarget == 'editor')
      cssSelector = 'atom-text-editor';

    @disposable = atom.commands.add(cssSelector, @config.getCommandName(), @runProcess);

    if @config.keystroke
      binding = {};
      bindings = {};
      binding[@config.keystroke] = @config.getCommandName();
      bindings[cssSelector] = binding;

      # params = {};
      # params.keystrokes = @config.keystroke;
      # params.command = @config.getCommandName();
      # params.target = cssSelector;
      #
      # try
      #   console.log(atom.keymaps.findKeyBindings(params));
      # catch error
      #   console.log(error);

      atom.keymaps.add('process-palette', bindings);

  getMain: ->
    return @projectController.getMain();

  getFirstProcessController: ->
    if @processControllers.length == 0
      return null;

    return @processControllers[0];

  addListener: (listener) ->
    @listeners.push(listener);

  removeListener: (listener) ->
    index = @listeners.indexOf(listener);

    if (index != -1)
      @listeners.splice(index, 1);

  dispose: ->
    @clearControllers();
    @disposable.dispose();

  clearControllers: ->
    for processController in @processControllers
      processController.dispose();

    @processControllers = [];

  runProcess: =>
    filePath = null;
    editor = atom.workspace.getActiveTextEditor();

    if editor?
      filePath = editor.getPath();

    @runProcessWithFile(filePath);

  runProcessWithFile: (filePath) ->
    processController = new ProcessController(@, @config);
    @processControllers.push(processController);
    processController.runProcessWithFile(filePath);

  removeProcessController: (processController) ->
    processController.dispose();
    index = @processControllers.indexOf(processController);

    if (index != -1)
      @processControllers.splice(index, 1);
      @notifyProcessControllerRemoved(processController);

  removeOldest: ->
    if !@config.maxCompleted?
      return;

    oldest = null;
    count = 0;

    for i in [(@processControllers.length-1)..0]
      if @processControllers[i].endTime != null
        count++;
        if (oldest == null) or (@processControllers[i].endTime < oldest.endTime)
          oldest = @processControllers[i];

    if count <= @config.maxCompleted
      return;

    if oldest != null
      @removeProcessController(oldest);

  notifyProcessStarted: (processController) ->
    _.invoke(_.clone(@listeners), "processStarted", processController);

  notifyProcessStopped: (processController) ->
    @removeOldest();
    _.invoke(_.clone(@listeners), "processStopped", processController);

    if @config.outputTarget != "panel" and @config.outputTarget != "file"
      @removeProcessController(processController);

  notifyProcessControllerRemoved: (processController) ->
    _.invoke(_.clone(@listeners), "processControllerRemoved", processController);
