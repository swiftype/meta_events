require 'meta_events'

describe MetaEvents::ControllerMethods do
  before :each do
    @definition_set = MetaEvents::Definition::DefinitionSet.new(:global_events_prefix => "xy") do
      version 1, '2014-01-31' do
        category :foo do
          event :bar, '2014-01-31', 'this is bar'
          event :baz, '2014-01-31', 'this is baz'
          event :custom, '2014-01-31', 'this is quux', :external_name => 'super-amazing-custom'
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

      def link_to(*args, &block)
        @_link_to_calls ||= [ ]
        @_link_to_calls << args + [ block ]
        "link_to_call_#{@_link_to_calls.length}"
      end

      def link_to_calls
        @_link_to_calls
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
      [ :meta_events_define_frontend_event, :meta_events_defined_frontend_events, :meta_events_tracker ].map(&:to_s).sort)
  end

  describe "frontend-event registration" do
    def expect_defined_event(name, external_name, properties, options = { })
      expect_defined_event_with_event_name(name, external_name, external_name, properties, options)
    end

    def expect_defined_event_with_event_name(name, external_name, event_name, properties, options = { })
      expected_distinct_id = options[:distinct_id] || 'abc123'
      expect(@obj.meta_events_defined_frontend_events[name]).to eq({
        :distinct_id => expected_distinct_id,
        :event_name => event_name,
        :external_name => external_name,
        :properties => properties
      })

      js = @obj.meta_events_frontend_events_javascript
      expect(js).to match(/MetaEvents\.registerFrontendEvent\s*\(\s*["']#{name}["']/i)
      js =~ /["']#{name}["']\s*,\s*(.*?)\s*\)\s*\;/i
      matched = $1
      hash = JSON.parse($1)
      expect(hash).to eq('distinct_id' => expected_distinct_id, 'event_name' => event_name, 'external_name' => external_name, 'properties' => properties)
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

    it "should let you override the tracker if you want" do
      ds2 = MetaEvents::Definition::DefinitionSet.new(:global_events_prefix => "ab") do
        version 2, '2014-01-31' do
          category :aaa do
            event :bbb, '2014-01-31', 'this is bar'
          end
        end
      end
      t2 = ::MetaEvents::Tracker.new("def345", nil, :definitions => ds2, :version => 2)

      @obj.meta_events_define_frontend_event(:aaa, :bbb, { }, :tracker => t2)
      expect_defined_event('aaa_bbb', 'ab2_aaa_bbb', { }, { :distinct_id => 'def345' })
    end

    it "should let you overwrite implicit properties and do hash expansion" do
      @obj.meta_events_define_frontend_event(:foo, :bar, { :imp1 => 'imp1val2', :a => { :b => 'c', :d => 'e' } })
      expect_defined_event('foo_bar', 'xy1_foo_bar', { 'imp1' => 'imp1val2', 'a_b' => 'c', 'a_d' => 'e' })
    end

    it "should use an overridden external_name" do
      @obj.meta_events_define_frontend_event(:foo, :custom, { :imp1 => 'imp1val1' })
      expect_defined_event_with_event_name('foo_custom', 'super-amazing-custom', 'xy1_foo_custom', { 'imp1' => 'imp1val1' })
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

  describe "auto-tracking" do
    def meta4(h)
      @obj.meta_events_tracking_attributes_for(h, @tracker)
    end

    it "should return the input attributes unchanged if there is no :meta_event" do
      input = { :foo => 'bar', :bar => 'baz' }
      expect(meta4(input)).to be(input)
    end

    it "should fail if :meta_event is not a Hash" do
      expect { meta4(:meta_event => 'bonk') }.to raise_error(ArgumentError)
    end

    it "should fail if :meta_event contains unknown keys" do
      me = { :category => 'foo', :event => 'bar', :properties => { }, :extra => 'whatever' }
      expect { meta4(:meta_event => me) }.to raise_error(ArgumentError)
    end

    it "should fail if there is no :category" do
      me = { :event => 'bar', :properties => { } }
      expect { meta4(:meta_event => me) }.to raise_error(ArgumentError)
    end

    it "should fail if there is no :event" do
      me = { :category => 'foo', :properties => { } }
      expect { meta4(:meta_event => me) }.to raise_error(ArgumentError)
    end

    def expect_meta4(input, classes, event_name, properties, options = { })
      attrs = meta4(input)

      expected_prefix = options[:prefix] || "mejtp"
      expect(attrs['class']).to eq(classes)

      expect(attrs["data-#{expected_prefix}_evt"]).to eq(event_name)
      prps = JSON.parse(attrs["data-#{expected_prefix}_prp"])
      expect(prps).to eq(properties)

      remaining = attrs.dup
      remaining.delete("data-#{expected_prefix}_evt")
      remaining.delete("data-#{expected_prefix}_prp")

      remaining
    end

    it "should add class, evt, and prp correctly, and remove :meta_event" do
      me = { :category => 'foo', :event => 'bar', :properties => { :something => 'awesome' } }
      remaining = expect_meta4({ :meta_event => me }, %w{mejtp_trk}, 'xy1_foo_bar', { 'something' => 'awesome', 'imp1' => 'imp1val1' })
      expect(remaining['data']).to be_nil
    end

    it "should combine the class with an existing class string" do
      me = { :category => 'foo', :event => 'bar', :properties => { :something => 'awesome' } }
      remaining = expect_meta4({ :meta_event => me, :class => 'bonko baz' }, [ 'bonko baz', 'mejtp_trk' ], 'xy1_foo_bar', { 'something' => 'awesome', 'imp1' => 'imp1val1' })
      expect(remaining['data']).to be_nil
    end

    it "should combine the class with an existing class array" do
      me = { :category => 'foo', :event => 'bar', :properties => { :something => 'awesome' } }
      remaining = expect_meta4({ :meta_event => me, :class => %w{bonko baz} }, %w{bonko baz mejtp_trk}, 'xy1_foo_bar', { 'something' => 'awesome', 'imp1' => 'imp1val1' })
      expect(remaining['data']).to be_nil
    end

    it "should preserve existing attributes" do
      me = { :category => 'foo', :event => 'bar', :properties => { :something => 'awesome' } }
      remaining = expect_meta4({ :meta_event => me, :yo => 'there' }, %w{mejtp_trk}, 'xy1_foo_bar', { 'something' => 'awesome', 'imp1' => 'imp1val1' })
      expect(remaining['data']).to be_nil
      expect(remaining[:yo]).to eq('there')
    end

    it "should preserve existing data attributes" do
      me = { :category => 'foo', :event => 'bar', :properties => { :something => 'awesome' } }
      remaining = expect_meta4({ :meta_event => me, :data => { :foo => 'bar', :bar => 'baz' } }, %w{mejtp_trk}, 'xy1_foo_bar', { 'something' => 'awesome', 'imp1' => 'imp1val1' })
      expect(remaining['data']).to eq({ 'foo' => 'bar', 'bar' => 'baz' })
    end

    it "should preserve existing data attributes that aren't a Hash" do
      me = { :category => 'foo', :event => 'bar', :properties => { :something => 'awesome' } }
      remaining = expect_meta4({ :meta_event => me, :data => "whatever", :'data-foo' => 'bar' }, %w{mejtp_trk}, 'xy1_foo_bar', { 'something' => 'awesome', 'imp1' => 'imp1val1' })
      expect(remaining['data']).to eq('whatever')
      expect(remaining['data-foo']).to eq('bar')
    end

    it "should let you change the tracking prefix" do
      MetaEvents::Helpers.meta_events_javascript_tracking_prefix 'foo'
      begin
        me = { :category => 'foo', :event => 'bar', :properties => { :something => 'awesome' } }
        remaining = expect_meta4({ :meta_event => me }, %w{foo_trk}, 'xy1_foo_bar', { 'something' => 'awesome', 'imp1' => 'imp1val1' }, { :prefix => 'foo' })
        expect(remaining['data']).to be_nil
      ensure
        MetaEvents::Helpers.meta_events_javascript_tracking_prefix 'mejtp'
      end
    end

    describe "#meta_events_tracked_link_to" do
      it "should raise if there is no :meta_event" do
        expect { @obj.meta_events_tracked_link_to("foobar", "barfoo") }.to raise_error(ArgumentError)
      end

      it "should call through to #link_to properly for a simple case" do
        retval = @obj.meta_events_tracked_link_to("foobar", "barfoo", { :meta_event => { :category => :foo, :event => :bar, :properties => { :a => :b }} })
        expect(retval).to eq("link_to_call_1")

        calls = @obj.link_to_calls
        expect(calls.length).to eq(1)

        call = calls[0]
        expect(call.length).to eq(4)
        expect(call[0]).to eq("foobar")
        expect(call[1]).to eq("barfoo")
        expect(call[2].keys.sort).to eq(%w{class data-mejtp_evt data-mejtp_prp}.sort)
        expect(call[2]['class']).to eq([ 'mejtp_trk' ])
        expect(call[2]['data-mejtp_evt']).to eq('xy1_foo_bar')
        prp = JSON.parse(call[2]['data-mejtp_prp'])
        expect(prp).to eq({ 'imp1' => 'imp1val1', 'a' => 'b' })
      end
    end
  end
end
