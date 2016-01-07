require 'service_flow/action'
require 'service_flow/metrics'
require 'service_flow/helper'

require 'active_support/core_ext/benchmark'
require 'active_support/core_ext/enumerable'
require 'json'

module ServiceFlow
  class WebAction < Action
    include Metrics
    include Helper

    attr_accessor :actor, :method, :params
    attr_reader :input, :output

    # alias_method :invoke_t, :pure_invoke_t

    def initialize(actor_or_options, method = nil, input = nil, output = nil, metrics = nil)
      @actor, @method, @input, @output = case actor_or_options
      when Hash
        actor_or_options.values_at('actor', 'method', 'input', 'output')
      else
        [actor_or_options, method, input, output]
      end

      if String === @actor
        @actor = Object.const_get("::WebAPI::#{@actor}").new
      end

      @log = []
    end

    def start(msg_or_params, which = 0)
      res = nil
      lapse = Benchmark.ms do
        params = which == 0 ? _bind(msg_or_params, @input) : msg_or_params.dup # TODO
        @actor.send @method, params
        puts @actor.uri
        resp = JSON.parse(@actor.get)
        # unless resp['status'] == 0
          # raise <<-ERROR_MSG
          # Error_code: #{resp['status']}
          # URL: #{@actor.uri}
          # Response: #{resp}
          # ERROR_MSG
        # end
        # puts resp['results'][0];
        puts 'resp', resp
        res = _bind(resp, @output)
      end
      @log << lapse
      res
    end

    def log(scope = nil)
      case scope
      when :raw, nil
        @log
      else
        Helper.cnt_sum_avg(@log)
      end
    end

    BASIC_METRIC_NAMES.each do |m|
      define_method m do
        METRICS[actor.class.to_s.split('::').last][method][m]
      end
    end

    def valid_rate
      1 - refresh_freq.to_f / invoking_freq
    end

    def invalid_rate
      refresh_freq.to_f / invoking_freq
    end

  end
end

