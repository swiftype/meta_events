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
    @tracker = ::MetaEvents::Tracker.new("abc123", nil, :definitions => @definition_set, :implicit_properties => { :imp1 => 'imp1val1' })

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
    def expect_defined_event(name, event_name, properties)
        expect(@obj.meta_events_defined_frontend_events[name]).to eq({
          :distinct_id => "abc123",
          :event_name => event_name,
          :properties => properties
        })

        js = @obj.meta_events_frontend_events_javascript
        expect(js).to match(/MetaEvents\.registerFrontendEvent\s*\(\s*["']#{name}["']/i)
        js =~ /#{name}["']\s*,\s*(.*?)\s*\)\s*\;/i
        hash = JSON.parse($1)
        expect(hash).to eq('distinct_id' => 'abc123', 'event_name' => event_name, 'properties' => properties)
    end

    it "should work fine if there are no registered events" do
      expect(@obj.meta_events_defined_frontend_events).to eq({ })
      expect(@obj.meta_events_frontend_events_javascript).to eq("")
    end

    it "should not let you register a nonexistent event" do
      expect { @obj.meta_events_define_frontend_event(:foo, :quux) }.to raise_error(ArgumentError, /quux/i)
    end

    it "should let you alias the event to anything you want" do
      @obj.meta_events_define_frontend_event(:foo, :bar, { :aaa => 'bbb' }, :name => 'zyxwvu')
      expect_defined_event('zyxwvu', 'xy1_foo_bar', { 'imp1' => 'imp1val1', 'aaa' => 'bbb' })
    end

    it "should let you overwrite implicit properties and do hash expansion" do
      @obj.meta_events_define_frontend_event(:foo, :bar, { :imp1 => 'imp1val2', :a => { :b => 'c', :d => 'e' } })
      expect_defined_event('foo_bar', 'xy1_foo_bar', { 'imp1' => 'imp1val2', 'a_b' => 'c', 'a_d' => 'e' })
    end

    context "with one simple defined event" do
      before :each do
        @obj.meta_events_define_frontend_event(:foo, :bar, { :quux => 123 })
      end

      it "should output that event (only) in the JavaScript and via meta_events_define_frontend_event" do
        expect(@obj.meta_events_defined_frontend_events.keys).to eq(%w{foo_bar})
        expect_defined_event('foo_bar', 'xy1_foo_bar', { 'quux' => 123, 'imp1' => 'imp1val1' })
      end

      it "should overwrite the event if a new one is registered" do
        @obj.meta_events_define_frontend_event(:foo, :baz, { :marph => 345 }, :name => 'foo_bar')
        expect_defined_event('foo_bar', 'xy1_foo_baz', { 'marph' => 345, 'imp1' => 'imp1val1' })
      end
    end

    context "with three defined events" do
      before :each do
        @obj.meta_events_define_frontend_event(:foo, :bar, { :quux => 123 })
        @obj.meta_events_define_frontend_event(:foo, :bar, { :quux => 345 }, { :name => :voodoo })
        @obj.meta_events_define_frontend_event(:foo, :baz, { :marph => 'whatever' })
      end

      it "should output all the events in the JavaScript and via meta_events_define_frontend_event" do
        expect(@obj.meta_events_defined_frontend_events.keys.sort).to eq(%w{foo_bar foo_baz voodoo}.sort)
        expect_defined_event('foo_bar', 'xy1_foo_bar', { 'quux' => 123, 'imp1' => 'imp1val1' })
        expect_defined_event('voodoo', 'xy1_foo_bar', { 'quux' => 345, 'imp1' => 'imp1val1' })
        expect_defined_event('foo_baz', 'xy1_foo_baz', { 'marph' => 'whatever', 'imp1' => 'imp1val1' })
      end
    end
  end
end
