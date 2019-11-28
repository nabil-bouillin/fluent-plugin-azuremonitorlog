require 'fluent/test/helpers'
require 'helper'
require "fluent/test/driver/input"
require "fluent/plugin/in_azuremonitorlog"

class AzureMonitorLogInputTest < Test::Unit::TestCase
    include Fluent::Test::Helpers
  
    ### for monitor log
    CONFIG_MONITOR_LOG = %[
        tag azuremonitorlog
        tenant_id test_tenant_id
        subscription_id test_subscription_id
        client_id test_client_id
        client_secret test_client_secret
        select eventName,id,resourceGroupName,resourceProviderName,operationName,status,eventTimestamp,correlationId
        filter eventChannels eq 'Admin, Operation'
        interval 300
        api_version 2015-04-01
    ]

    def create_driver_azure_monitor_log(conf = CONFIG_MONITOR_LOG)
        Fluent::Test::Driver::Input.new(Fluent::Plugin::AzureMonitorLogInput).configure(conf)
    end

    def setup
        Fluent::Test.setup
    end

    sub_test_case 'configuration' do
        
        test 'configuration parameters for monitor log' do
            d = create_driver_azure_monitor_log
            assert_equal 'azuremonitorlog', d.instance.tag
            assert_equal 'test_tenant_id', d.instance.tenant_id
            assert_equal 'test_subscription_id', d.instance.subscription_id
            assert_equal 'test_client_id', d.instance.client_id
            assert_equal 'test_client_secret', d.instance.client_secret
            assert_equal 'eventName,id,resourceGroupName,resourceProviderName,operationName,status,eventTimestamp,correlationId', d.instance.select
            assert_equal 'eventChannels eq \'Admin, Operation\'', d.instance.filter
            assert_equal 300, d.instance.interval
            assert_equal '2015-04-01', d.instance.api_version
        end

        #test 'configuration query options for monitor log' do
        #    d = create_driver_azure_monitor_log
        #    monitor_log_async = d.instance.get_monitor_log_async(d.instance.filter, {})
        #    assert_equal '2015-04-01', monitor_log_async[:query_params]['api-version']
        #    assert_equal 'eventChannels eq \'Admin, Operation\'', monitor_log_async[:query_params]['$filter']
        #    assert_equal 'eventName,id,resourceGroupName,resourceProviderName,operationName,status,eventTimestamp,correlationId', monitor_log_async[:query_params]['$select']
        #end
    end 
end
