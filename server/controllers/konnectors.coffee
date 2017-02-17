path = require 'path'
Konnector = require '../models/konnector'
konnectorHash = require '../lib/konnector_hash'
handleNotification = require '../lib/notification_handler'

log = require('printit')
    prefix: 'konnector controller'


module.exports =

    # Get konnector data (module parameters and user parameters)
    # Handle encrypted fields.
    getKonnector: (req, res, next) ->
        Konnector.find req.params.konnectorId, (err, konnector) ->
            if err
                next err
            else if not konnector?
                res.sendStatus 404
            else

                konnector.injectEncryptedFields()
                konnector.appendConfigData()
                konnector.checkProperties()

                if konnector.shallRaiseEncryptedFieldsError()
                    konnector.importErrorMessage = 'encrypted fields'
                else
                    konnector.injectEncryptedFields()

                # Add customView field
                konnectorModule = require(
                    path.join(
                        '..',
                        'konnectors',
                        konnector.slug
                    )
                )
                if konnectorModule.default?
                    konnectorModule = konnectorModule.default

                if konnectorModule.customView?
                    konnector.customView = konnectorModule.customView

                if konnectorModule.connectUrl?
                    konnector.connectUrl = konnectorModule.connectUrl

                req.konnector = konnector
                next()


    # Returns konnector data (module parameters and user parameters)
    # Handle encrypted fields.
    show: (req, res, next) ->
        res.send req.konnector


    # Reset konnector fields.
    remove: (req, res, next) ->

        data =
            lastAutoImport: null
            importErrorMessage: null
            lastImport: null
            lastSuccess: null
            accounts: []
            password: null
            importInterval: 'none'

        ## Remove the konnector from the poller
        poller = require "../lib/poller"
        log.info "Removing konnector #{req.konnector.slug} from the poller"
        poller.remove req.konnector

        req.konnector.updateAttributes data, (err, konnector) ->
            return next err if err

            res.status(204).send konnector


    # Start import for a given konnector. Change state of the konnector during
    # import (set importing to true until the import finished).
    # If a date is given, it adds a new poller or reset the existing one if
    # it exists.
    # No import is started when the konnector is already in the is importing
    # state.
    import: (req, res, next) ->
        # Don't run a new import if an import is already running.
        if req.konnector.isImporting
            res.status(400).send message: 'konnector is importing'
        else

            # Extract date information.
            if req.body.date?
                if req.body.date isnt ''
                    date = req.body.date
                delete req.body.date

            req.konnector.updateFieldValues req.body, (err) ->
                if err?
                    next err
                else
                    poller = require "../lib/poller"
                    poller.add date, req.konnector

                    # Don't import data if a start date is defined
                    unless date?
                        req.konnector.import (err, notifContent) ->
                            if err?
                                log.error err
                            else
                                handleNotification req.konnector, notifContent
                    res.status(200).send success: true


    redirect: (req, res, next) ->
        try
            accounts = req.konnector.accounts or []
            account = accounts[req.params.accountId] or {}
            for k, v of req.query
                account[k] = v

            # Add redirection path, used by some konnector to build back the
            # redirectUri
            account.redirectPath = req.originalUrl

            accounts[req.params.accountId] = account
        catch e then return next e

        req.konnector.updateFieldValues { accounts: accounts }, (err) ->
            return next err if err

            res.status(200).send """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
</head>
<body>
    <script type="text/javascript">
        window.onload = function() {
            //refreshParent;
            if(window.opener){
              window.opener.location.reload();
              setTimeout(function() {
                  window.close();
              }, 500);
            }
            else {
              window.location.href =
                  "../../../#/category/#{req.konnector.category}/" +
                        "#{req.konnector.slug}"
            }
        };
    </script>
</body>
</html>
"""
