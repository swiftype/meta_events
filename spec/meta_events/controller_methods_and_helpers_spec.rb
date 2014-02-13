require 'meta_events'

describe MetaEvents::ControllerMethods do
  before :each do
    @definition_set = MetaEvents::Definition::DefinitionSet.new(:global_events_prefix => "xy") do
      version 1, '2014-01-31' do
        category :foo do
          event :bar, '2014-01-31', 'this is bar'
          event :baz, '2014-01-31', 'this is baz'
        end
      end
    end
    @tracker = ::MetaEvents::Tracker.new("abc123", nil, :definitions => @definition_set)

    @klass = Class.new do
      class << self
        def helper_method(*args)
          @_helper_methods ||= [ ]
          @_helper_methods += args
        end

        def helper_methods_registered
          @_helper_methods
        end
      end

      attr_accessor :meta_events_tracker

      include MetaEvents::ControllerMethods
      include MetaEvents::Helpers
    end

    @obj = @klass.new
    @obj.meta_events_tracker = @tracker
  end

  it "should register the proper helper methods" do
    expect(@klass.helper_methods_registered.map(&:to_s).sort).to eq(
      [ :meta_events_define_frontend_event, :meta_events_defined_frontend_events ].map(&:to_s).sort)
  end

  describe "frontend-event registration" do
    it "should work fine if there are no registered events" do
      expect(@obj.meta_events_defined_frontend_events).to eq({ })
      expect(@obj.meta_events_frontend_events_javascript).to eq("")
    end

    it "should not let you register a nonexistent event" do
      expect { @obj.meta_events_define_frontend_event(:foo, :quux) }.to raise_error(ArgumentError, /quux/i)
    end

    context "with one simple defined event" do
      before :each do
        @obj.meta_events_define_frontend_event(:foo, :bar, { :quux => 123 })
      end

      it "should output that event in the JavaScript" do
        js = @obj.meta_events_frontend_events_javascript
        expect(js).to match(/MetaEvents\.registerFrontendEvent\s*\(\s*["']foo_bar["']/i)
        js =~ /foo_bar["']\s*,\s*(.*?)\s*\)\s*\;/i
        hash = JSON.parse($1)
        expect(hash).to eq('distinct_id' => 'abc123', 'event_name' => 'xy1_foo_bar', 'properties' => { 'quux' => 123 })
      end
    end
  end
end
