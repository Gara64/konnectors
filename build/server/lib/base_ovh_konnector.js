// Generated by CoffeeScript 1.11.1
var Bill, baseKonnector, filterExisting, linkBankOperation, ovhFetcher, saveDataAndFile;

ovhFetcher = require('../lib/ovh_fetcher');

filterExisting = require('../lib/filter_existing');

saveDataAndFile = require('../lib/save_data_and_file');

linkBankOperation = require('../lib/link_bank_operation');

baseKonnector = require('../lib/base_konnector');

Bill = require('../models/bill');

module.exports = {
  createNew: function(ovhApi, name, slug, vendorLink, category, color) {
    var connector, fetchBills, fileOptions, logger, ovhFetcherInstance;
    fileOptions = {
      vendor: slug,
      dateFormat: 'YYYYMMDD'
    };
    logger = require('printit')({
      prefix: name,
      date: true
    });
    ovhFetcherInstance = ovhFetcher["new"](ovhApi, slug, logger);
    fetchBills = function(requiredFields, entries, body, next) {
      return ovhFetcherInstance.fetchBills(requiredFields, entries, body, next);
    };
    return connector = baseKonnector.createNew({
      name: name,
      vendorLink: vendorLink,
      category: category,
      color: color,
      fields: {
        loginUrl: {
          type: "text"
        },
        token: {
          type: "hidden"
        },
        folderPath: {
          type: "folder",
          advanced: true
        }
      },
      dataType: ['bill'],
      models: [Bill],
      fetchOperations: [
        fetchBills, filterExisting(logger, Bill), saveDataAndFile(logger, Bill, fileOptions, ['bill']), linkBankOperation({
          log: logger,
          model: Bill,
          identifier: slug,
          dateDelta: 4,
          amountDelta: 0.1
        })
      ]
    });
  }
};
