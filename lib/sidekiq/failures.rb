begin
  require "sidekiq/web"
rescue LoadError
  # client-only usage
end

require "sidekiq/failures/version"
require "sidekiq/failures/middleware"
require "sidekiq/failures/web_extension"

module Sidekiq

  SIDEKIQ_FAILURES_MODES = [:all, :exhausted, :off].freeze

  # Sets the default failure tracking mode.
  #
  # The value provided here will be the default behavior but can be overwritten
  # per worker by using `sidekiq_options :failures => :mode`
  #
  # Defaults to :all
  def self.failures_default_mode=(mode)
    unless SIDEKIQ_FAILURES_MODES.include?(mode.to_sym)
      raise ArgumentError, "Sidekiq#failures_default_mode valid options: #{SIDEKIQ_FAILURES_MODES}"
    end

    @failures_default_mode = mode.to_sym
  end

  # Fetches the default failure tracking mode.
  def self.failures_default_mode
    @failures_default_mode || :all
  end

  def self.failures_store_max_count=(integer)
    @failures_default_mode = integer
  end

  def self.failures_store_max_count
    @failures_default_mode
  end

  def self.clean_failures
    Sidekiq.redis do |conn|
      conn.del("failed")
      conn.set("stat:failed", 0)
    end
  end

  def self.failures_count
    Sidekiq.redis { |conn| conn.llen("failed") } || 0
  end

  module Failures
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Failures::Middleware
  end
end

if defined?(Sidekiq::Web)
  Sidekiq::Web.register Sidekiq::Failures::WebExtension

  if Sidekiq::Web.tabs.is_a?(Array)
    # For sidekiq < 2.5
    Sidekiq::Web.tabs << "failures"
  else
    Sidekiq::Web.tabs["Failures"] = "failures"
  end
end