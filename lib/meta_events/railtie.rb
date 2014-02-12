module MetaEvents
  class Railtie < Rails::Railtie
    def say(x)
      ::Rails.logger.info "MetaEvents: #{x}"
    end

    initializer "meta_events.configure_rails_initialization" do
      ::ActiveSupport.on_load(:action_view) do
        include ::MetaEvents::Helpers
      end

      ::ActiveSupport.on_load(:action_controller) do
        include ::MetaEvents::ControllerMethods
      end

      return if ::MetaEvents::Tracker.default_definitions

      config_meta_events = File.expand_path(File.join(::Rails.root, 'config', 'meta_events.rb'))
      if File.exist?(config_meta_events)
        ::MetaEvents::Tracker.default_definitions = config_meta_events
        say "Loaded event definitions from #{config_meta_events.inspect}"

        if defined?(::Spring)
          Spring.watch config_meta_events
        end
      end
    end
  end
end
