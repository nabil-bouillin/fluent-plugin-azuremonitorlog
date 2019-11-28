require 'fluent/plugin/input'
require 'azure_mgmt_monitor'

module Fluent::Plugin
class AzureMonitorLogInput < Input
    Fluent::Plugin.register_input("azuremonitorlog", self)

    helpers :compat_parameters
    
    # Define parameters for API Monitor
    config_param :tag, :string, :default => "azuremonitorlog"
    config_param :tenant_id, :string, :default => nil
    config_param :subscription_id, :string, :default => nil
    config_param :client_id, :string, :default => nil
    config_param :client_secret, :string, :default => nil, :secret => true

    config_param :select, :string, :default => nil
    config_param :filter, :string, :default => "eventChannels eq 'Admin, Operation'"
    config_param :interval, :integer,:default => 300
    config_param :api_version, :string, :default => '2015-04-01'

    def configure(conf)
        super
        log.error(@tenant_id)
        log.error(@client_id)
        log.error(@client_secret)
        log.error(@subscription_id)
        provider = MsRestAzure::ApplicationTokenProvider.new(@tenant_id, @client_id, @client_secret)
        credentials = MsRest::TokenCredentials.new(provider)
        @client = Azure::Monitor::Mgmt::V2015_04_01::MonitorManagementClient.new(credentials);
        @client.subscription_id = @subscription_id
        @client.api_version = @api_version
    end

    def start
        super
        @finished = false
        @watcher = Thread.new(&method(:watch))
    end

    def shutdown
        super
        @finished = true
        @watcher.terminate
        @watcher.join
    end

    private 

      def watch
        log.debug "azure monitorlog: watch thread starting"
    
        @next_fetch_time = Time.now
    
        until @finished
          start_time = @next_fetch_time - @interval
          end_time = @next_fetch_time
          log.debug "start time: #{start_time}, end time: #{end_time}"
          filter = "eventTimestamp ge '#{start_time}' and eventTimestamp le '#{end_time}'"
          #filter = "eventTimestamp ge '2019-11-20T20:00:00Z' and eventTimestamp le '2019-11-27T20:00:00Z'"
  
          if !@filter.empty?
            filter += " and #{@filter}"
          end
    
          monitor_logs_promise = get_monitor_log_async(filter)
          monitor_logs = monitor_logs_promise.value!
    
          if !monitor_logs.body['value'].nil? and  monitor_logs.body['value'].any?
            monitor_logs.body['value'].each {|val|
              router.emit(@tag, Fluent::Engine.now, val)
            }
          else
            log.debug "empty"
          end
          @next_fetch_time += @interval
          sleep @interval
        end
      end
      
      

    def get_monitor_log_async(filter, custom_headers=nil)
      fail ArgumentError, '@client.api_version is nil' if @client.api_version.nil?
      fail ArgumentError, '@client.subscription_id is nil' if @client.subscription_id.nil?

      request_headers = {}
      request_headers['Content-Type'] = 'application/json; charset=utf-8'

      # Set Headers
      request_headers['x-ms-client-request-id'] = SecureRandom.uuid
      request_headers['accept-language'] = @client.accept_language unless @client.accept_language.nil?
      path_template = 'subscriptions/{subscriptionId}/providers/microsoft.insights/eventtypes/management/values'

      request_url = @client.base_url
      log.error(filter)
      options = {
          middlewares: [[MsRest::RetryPolicyMiddleware, times: 3, retry: 0.02], [:cookie_jar]],
          path_params: {'subscriptionId' => @client.subscription_id},
          query_params: {'api-version' => @client.api_version,'$filter' => filter,'$select' => @select},
          headers: request_headers.merge(custom_headers || {}),
          base_url: request_url
      }
      promise = @client.make_request_async(:get, path_template, options)
      promise = promise.then do |result|
        http_response = result.response
        status_code = http_response.status
        response_content = http_response.body
        unless status_code == 200
          error_model = JSON.load(response_content)
          fail MsRest::HttpOperationError.new(result.request, http_response, error_model)
        end

        result.request_id = http_response['x-ms-request-id'] unless http_response['x-ms-request-id'].nil?
        result.correlation_request_id = http_response['x-ms-correlation-request-id'] unless http_response['x-ms-correlation-request-id'].nil?
        result.client_request_id = http_response['x-ms-client-request-id'] unless http_response['x-ms-client-request-id'].nil?
        # Deserialize Response
        if status_code == 200
          begin
            #parsed_response = response_content.to_s.empty? ? nil : JSON.load(response_content)
            #result_mapper = Azure::Monitor::Mgmt::V2015_04_01::Models::EventDataCollection.mapper() 
            #result.body = @client.deserialize(result_mapper,parsed_response)
            result.body =  response_content.to_s.empty? ? nil : JSON.load(response_content)
          rescue Exception => e
            fail MsRest::DeserializationError.new('Error occurred in deserializing the response', e.message, e.backtrace, result)
          end
        end
        result
      end
      promise.execute
    end
  end
end