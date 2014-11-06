require @ledger.imports, ->

  class Application

    _navigationControllerSelector: -> $('#controllers_container')

    constructor: ->
      @_navigationController = null
      @devicesManager = new DevicesManager()
      @router = new Router(@)
      ledger.dialogs.manager.initialize($('#dialogs_container'))

    start: ->
      chrome.commands.onCommand.addListener (command) =>
        switch command
          when 'reload-page' then do @reloadUi
          when 'reload-application' then chrome.runtime.reload()

      @devicesManager.on 'plug', (event, device) ->
        l 'Plug'
        l device
      @devicesManager.on 'unplug', (event, device) ->
        l 'Unplug'
        l device
      @devicesManager.start()
      @router.go('/')

      ledger.storage.openStores('merguez')

      account = Account.findOrCreate 1, {name: 'Toto', balance: 16}
      account.get ['name', 'balance'], (result) =>
        l result
        account.set 'name', result.name + '1'
        account.set 'balance', result.balance * 2
        account.save () =>
          account = Account.findOrCreate 1, {name: 'Toto', balance: 16}
          account.get ['name', 'balance'], (result) =>
            l result

      ###
      ledger.storage.local.set {__uid: '1', name: 'Test', second: 'Toto', test: {a: '1', plus: '+', b: '1'}, array: [1, 2, 3]}, ->
        ledger.storage.local.get '1', (result) =>
          l result
          ledger.storage.local.get result['1'].array.__uid, (result) ->
            l result
            chrome.storage.local.get null, (r) ->
              l r
      ###

    navigate: (layoutName, viewController) ->
      @router.once 'routed', (event, data) =>
        oldUrl = if @_lastUrl? then @_lastUrl.parseAsUrl() else {hash: '', pathname: '', params: -> ''}
        newUrl = data.url.parseAsUrl()
        @_lastUrl = data.url
        @currentUrl = data.url
        controller = null

        ## Create action name and action parameters
        [actionName, parameters] = ledger.url.parseAction(newUrl.hash)

        onControllerRendered = () ->
          # Callback when the controller has been rendered
          @handleAction(actionName, parameters) if newUrl.hash.length > 0

        if @_navigationController == null or @_navigationController.constructor.name != layoutName
          @_navigationController = new window[layoutName]()
          controller = new viewController(newUrl.params())
          controller.on 'afterRender', onControllerRendered.bind(@)
          @_navigationController.push new viewController()
          @_navigationController.render @_navigationControllerSelector()
        else
          if @_navigationController.topViewController().constructor.name == viewController.name and oldUrl.pathname == newUrl.pathname and _.isEqual(newUrl.params(), oldUrl.params()) # Check if only hash part of url change
           @handleAction(actionName, parameters)
          else
            controller = new viewController(newUrl.params())
            controller.on 'afterRender', onControllerRendered.bind(@)
            @_navigationController.push controller

    reloadUi: () ->
      $('link').each (_, link) ->
        if link.href? && link.href.length > 0
          cleanHref = link.href
          cleanHref = cleanHref.replace(/\?[0-9]*/i, '')
          link.href = cleanHref + '?' + (new Date).getTime()
      @_navigationController.render @_navigationControllerSelector() if @_navigationController?

    handleAction: (actionName, params) ->
      handled = no
      if ledger.dialogs.manager.displayedDialog()?
        handled = ledger.dialogs.manager.displayedDialog().handleAction actionName, params
      handled = @_navigationController.handleAction(actionName, params) unless handled
      handled


  @WALLET_LAYOUT = 'WalletNavigationController'
  @ONBOARDING_LAYOUT = 'OnboardingNavigationController'

  @ledger.application = new Application()
  @ledger.app = @ledger.application
  @ledger.application.start()
