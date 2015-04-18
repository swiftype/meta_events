require "meta_events"
require "active_support"
require 'active_support/core_ext/numeric/time'
require 'ipaddr'

describe MetaEvents::Tracker do
  subject(:klass) { MetaEvents::Tracker }
  let(:definition_set) do
    MetaEvents::Definition::DefinitionSet.new(:global_events_prefix => "xy") do
      version 1, '2014-01-31' do
        category :foo do
          event :bar, '2014-01-31', 'this is bar'
          event :baz, '2014-01-31', 'this is baz', :external_name => 'foo bazzeroo'
          event :nolonger, '2014-01-31', 'should be retired', :retired_at => '2020-01-01'
        end
      end

      version 2, '2014-06-01' do
        category :foo do
          event :quux, '2014-01-31', 'this is quux'
        end
      end

      version 3, '2014-07-01', :property_separator => '~' do
        category :bar do
          event :baz, '2014-07-01', 'this is baz'
        end
      end
    end
  end

  let(:receiver_1) do
    out = double("receiver_1")
    @receiver_1_calls = [ ]
    rc1c = @receiver_1_calls
    allow(out).to receive(:track) { |*args| rc1c << args }
    out
  end

  let(:receiver_2) do
    out = double("receiver_2")
    @receiver_2_calls = [ ]
    rc2c = @receiver_2_calls
    allow(out).to receive(:track) { |*args| rc2c << args }
    out
  end

  def new_instance(*args)
    out = klass.new(*args)
    out.event_receivers << receiver_1
    out
  end

  before :each do
    ::MetaEvents::Tracker.default_event_receivers = [ ]
    @user = tep_object(:name => 'wilfred', :hometown => 'Fridley')
    @distinct_id = rand(1_000_000_000)
    @remote_ip = "128.12.34.56"
    @instance = new_instance(@distinct_id, nil, :definitions => definition_set, :version => 1, :implicit_properties => { :user => @user } )
  end

  after :each do
    expect(@receiver_1_calls).to eq([ ])
    expect((@receiver_2_calls || [ ])).to eq([ ])
  end

  def expect_event(event_name, event_properties, options = { })
    receiver_name = options[:receiver_name] || "receiver_1"
    expected_distinct_id = if options.has_key?(:distinct_id) then options[:distinct_id] else @distinct_id end

    calls = instance_variable_get("@#{receiver_name}_calls")

    expect(calls.length).to be > 0
    next_event = calls.shift
    expect(next_event[0]).to eq(expected_distinct_id)
    expect(next_event[1]).to eq(event_name)
    actual_properties = next_event[2]

    filtered_actual_properties = actual_properties.dup

    # handle automatic properties that we may not want to care about every time
    %w{ip time}.each do |automatic_property_name|
      if ! event_properties.has_key?(automatic_property_name)
        filtered_actual_properties.delete(automatic_property_name)
      end
    end

    expect(filtered_actual_properties).to eq(event_properties)

    actual_properties
  end

  def tep_object(props)
    out = double("tep_object")
    allow(out).to receive(:to_event_properties).with().and_return(props)
    out
  end

  describe "#initialize" do
    it "should validate its arguments" do
      expect { new_instance(@distinct_id, nil, :version => 1, :definitions => definition_set, :foo => :bar) }.to raise_error(ArgumentError, /foo/i)
      expect { new_instance(@distinct_id, "whatever", :version => 1, :definitions => definition_set) }.to raise_error(ArgumentError)
      expect { new_instance(@distinct_id, /foobar/, :version => 1, :definitions => definition_set) }.to raise_error(ArgumentError, /foobar/i)
    end

    it "should allow a nil distinct_id" do
      expect { new_instance(nil, nil, :definitions => definition_set, :version => 1) }.not_to raise_error
    end

    it "should not allow an invalid distinct_id" do
      expect { new_instance(/foobar/, nil, :definitions => definition_set, :version => 1) }.to raise_error(ArgumentError)
    end

    it "should be able to read definitions from a file" do
      require 'tempfile'

      f = Tempfile.new('tracker_events')
      begin
        f.puts <<-EOS
global_events_prefix :fb

version 1, '2014-02-19' do
  category :baz do
    event :quux, '2014-01-31', 'this is quux'
  end
end
EOS
        f.close

        the_instance = new_instance(@distinct_id, nil, :definitions => f.path, :version => 1)
        expect { the_instance.event!(:baz, :quux, :foo => :bar) }.not_to raise_error
        expect_event("fb1_baz_quux", { 'foo' => 'bar' })
        expect { the_instance.event!(:baz, :foo, :foo => :bar) }.to raise_error
      ensure
        f.close
        f.unlink
      end
    end
  end

  describe "#distinct_id" do
    it "should allow reading the distinct ID" do
      expect(@instance.distinct_id).to eq(@distinct_id)
    end

    it "should allow changing the distinct ID at runtime" do
      i = new_instance(@distinct_id, nil, :definitions => definition_set, :version => 1)
      i.event!(:foo, :bar, { })
      expect_event('xy1_foo_bar', { }, :distinct_id => @distinct_id)
      i.distinct_id = '12345yoyoyo'
      expect(i.distinct_id).to eq('12345yoyoyo')
      i.event!(:foo, :bar, { })
      expect_event('xy1_foo_bar', { }, :distinct_id => '12345yoyoyo')
    end

    it "should allow changing the distinct ID to nil at runtime" do
      i = new_instance(@distinct_id, nil, :definitions => definition_set, :version => 1)
      expect(i.distinct_id).to eq(@distinct_id)
      i.distinct_id = nil
      expect(i.distinct_id).to eq(nil)
      i.event!(:foo, :bar, { })
      expect_event('xy1_foo_bar', { }, :distinct_id => nil)
    end

    it "should not allow setting the distinct ID to an unsupported object" do
      i = new_instance(@distinct_id, nil, :definitions => definition_set, :version => 1)
      expect { i.distinct_id = /foobar/ }.to raise_error(ArgumentError)
      expect(i.distinct_id).to eq(@distinct_id)
    end
  end

  describe "#event!" do
    it "should allow firing a valid event" do
      i = new_instance(@distinct_id, nil, :definitions => definition_set, :version => 1)
      i.event!(:foo, :bar, { })
      expect_event('xy1_foo_bar', { })
    end

    describe "time support" do
      it "should add the time to the event" do
        start_time = Time.now.to_i
        i = new_instance(@distinct_id, nil, :definitions => definition_set, :version => 1)
        i.event!(:foo, :bar, { })
        end_time = Time.now.to_i
        actual_properties = expect_event('xy1_foo_bar', { })
        time = actual_properties['time']
        expect(time).to be >= start_time
        expect(time).to be >= end_time
      end

      it "should allow overriding the time" do
        actual_time = Time.now.to_i - 500
        i = new_instance(@distinct_id, nil, :definitions => definition_set, :version => 1)
        i.event!(:foo, :bar, { :time => actual_time })
        expect_event('xy1_foo_bar', { 'time' => actual_time })
      end

      it "should allow omitting the time" do
        actual_time = Time.now.to_i - 500
        i = new_instance(@distinct_id, nil, :definitions => definition_set, :version => 1)
        i.event!(:foo, :bar, { :time => nil })
        expect_event('xy1_foo_bar', { 'time' => nil })
      end
    end

    describe "ip-address passing" do
      it "should pass through an IPv4 String IP" do
        i = new_instance(@distinct_id, "138.93.206.193", :definitions => definition_set, :version => 1)
        i.event!(:foo, :bar, { })
        expect_event('xy1_foo_bar', { 'ip' => "138.93.206.193" })
      end

      it "should pass through an IPv6 String IP" do
        i = new_instance(@distinct_id, "2607:f0d0:1002:0051:0000:0000:0000:0004", :definitions => definition_set, :version => 1)
        i.event!(:foo, :bar, { })
        expect_event('xy1_foo_bar', { 'ip' => "2607:f0d0:1002:51::4" })
      end

      it "should pass through an Integer IP" do
        i = new_instance(@distinct_id, 2321403585, :definitions => definition_set, :version => 1)
        i.event!(:foo, :bar, { })
        expect_event('xy1_foo_bar', { 'ip' => "138.93.206.193" })
      end

      it "should pass through an IPv4 IPAddr" do
        i = new_instance(@distinct_id, IPAddr.new("138.93.206.193"), :definitions => definition_set, :version => 1)
        i.event!(:foo, :bar, { })
        expect_event('xy1_foo_bar', { 'ip' => "138.93.206.193" })
      end

      it "should pass through an IPv6 IPAddr" do
        i = new_instance(@distinct_id, IPAddr.new("2607:f0d0:1002:0051:0000:0000:0000:0004"), :definitions => definition_set, :version => 1)
        i.event!(:foo, :bar, { })
        expect_event('xy1_foo_bar', { 'ip' => "2607:f0d0:1002:51::4" })
      end
    end

    it "should include the distinct_id set in the constructor" do
      i = new_instance(@distinct_id, nil, :definitions => definition_set, :version => 1)
      i.event!(:foo, :bar, { })
      expect_event('xy1_foo_bar', { }, :distinct_id => @distinct_id)
    end

    it "should let you override the IP address on a per-event basis" do
      i = new_instance(@distinct_id, "138.93.206.193", :definitions => definition_set, :version => 1)
      i.event!(:foo, :bar, { 'ip' => '203.196.4.32' })
      expect_event('xy1_foo_bar', { 'ip' => '203.196.4.32' }, :distinct_id => @distinct_id)
    end

    it "should allow overriding the distinct_id set in the constructor" do
      i = new_instance(@distinct_id, nil, :definitions => definition_set, :version => 1)
      i.event!(:foo, :bar, { :distinct_id => 12345 })
      expect_event('xy1_foo_bar', { }, :distinct_id => 12345)
    end

    it "should allow a nil distinct_id" do
      i = new_instance(nil, nil, :definitions => definition_set, :version => 1)
      i.event!(:foo, :bar, { })
      expect_event('xy1_foo_bar', { }, :distinct_id => nil)
    end

    it "should allow a String distinct_id" do
      i = new_instance("foobarfoobar", nil, :definitions => definition_set, :version => 1)
      i.event!(:foo, :bar, { })
      expect_event('xy1_foo_bar', { }, :distinct_id => 'foobarfoobar')
    end

    it "should send the event to both receivers if asked" do
      @instance.event_receivers = [ receiver_1, receiver_2 ]
      @instance.event!(:foo, :bar, { })

      expect_event("xy1_foo_bar", { 'user_name' => 'wilfred', 'user_hometown' => 'Fridley' }, :receiver_name => :receiver_1)
      expect_event("xy1_foo_bar", { 'user_name' => 'wilfred', 'user_hometown' => 'Fridley' }, :receiver_name => :receiver_2)
    end

    it "should clone the class's default-receiver list on creation" do
      expect(klass.default_event_receivers).to eq([ ])

      begin
        klass.default_event_receivers = [ receiver_2 ]
        i = klass.new(@distinct_id, nil, :definitions => definition_set, :version => 1)
        i.event!(:foo, :bar, { })
        expect_event('xy1_foo_bar', { }, :receiver_name => :receiver_2)
      ensure
        klass.default_event_receivers = [ ]
      end
    end

    it "should allow overriding the list of receivers in the constructor" do
      i = klass.new(@distinct_id, nil, :definitions => definition_set, :version => 1, :event_receivers => [ receiver_2 ])
      i.event!(:foo, :bar, { })
      expect_event('xy1_foo_bar', { }, :receiver_name => :receiver_2)
    end

    it "should use the class's list of default definitions by default" do
      klass.default_definitions = MetaEvents::Definition::DefinitionSet.new(:global_events_prefix => "zz") do
        version 1, '2014-01-31' do
          category :marph do
            event :bonk, '2014-01-31', 'this is bar'
          end
        end
      end

      i = klass.new(@distinct_id, nil, :version => 1, :event_receivers => receiver_1)
      i.event!(:marph, :bonk)
      expect_event('zz1_marph_bonk', { })
    end

    it "should pick up the default version from the class" do
      original_default_version = klass.default_version

      begin
        klass.default_version = 2

        i = klass.new(@distinct_id, nil, :event_receivers => receiver_1, :definitions => definition_set)
        i.event!(:foo, :quux)
        expect_event("xy2_foo_quux", { })
      ensure
        klass.default_version = original_default_version
      end
    end

    it "should use the default external name from the class" do
      begin
        klass.default_external_name = lambda { |event| "#{event.category_name}-super-custom-#{event.name}" }

        i = klass.new(@distinct_id, nil, :event_receivers => receiver_1, :definitions => definition_set)
        i.event!(:foo, :bar, { })
        expect_event('foo-super-custom-bar', { })
      ensure
        klass.default_external_name = nil
      end
    end

    it "should allow resetting the default external name from the class back to the built-in default" do
      begin
        klass.default_external_name = lambda { |event| "#{event.category_name}-super-custom-#{event.name}" }

        i = klass.new(@distinct_id, nil, :event_receivers => receiver_1, :definitions => definition_set)
        i.event!(:foo, :bar, { })
        expect_event('foo-super-custom-bar', { })

        klass.default_external_name = nil

        i = klass.new(@distinct_id, nil, :event_receivers => receiver_1, :definitions => definition_set)
        i.event!(:foo, :bar, { })
        expect_event('xy1_foo_bar', { })
      ensure
        klass.default_external_name = nil
      end
    end

    it "should allow overriding the external name in the constructor" do
      i = new_instance(@distinct_id, nil, :definitions => definition_set, :external_name => lambda { |event| "#{event.category_name}-super-custom-#{event.name}" })
      i.event!(:foo, :bar, { })
      expect_event('foo-super-custom-bar', { })
    end

    it "should require the result of the external name to be a string" do
      expect {
        i = new_instance(@distinct_id, nil, :definitions => definition_set, :external_name => lambda { |event| 1234 })
        i.event!(:foo, :bar, { })
      }.to raise_error(TypeError, /external name/i)
    end

    context "with default_external_name set" do
      before :each do
        klass.default_external_name = lambda { |event| "default-#{event.category_name}-#{event.name}-custom" }
      end

      after :each do
        klass.default_external_name = nil
      end

      it "should return event external_name if set" do
        i = new_instance(@distinct_id, nil, :definitions => definition_set, :external_name => lambda { |event| "#{event.category_name}-#{event.name}-custom" })
        i.event!(:foo, :baz, { })
        expect_event('foo bazzeroo', { })
      end

      context "no event external_name is set" do
        it "should return instance external_name" do
          i = new_instance(@distinct_id, nil, :definitions => definition_set, :external_name => lambda { |event| "#{event.category_name}-#{event.name}-custom" })
          i.event!(:foo, :bar, { })
          expect_event('foo-bar-custom', { })
        end

        context "no instance external_name is set" do
          it "should return default_external_name" do
            i = new_instance(@distinct_id, nil, :definitions => definition_set)
            i.event!(:foo, :bar, { })
            expect_event('default-foo-bar-custom', { })
          end
        end
      end
    end

    it "should allow firing a valid event, and include implicit properties" do
      @instance.event!(:foo, :bar, { })
      expect_event('xy1_foo_bar', { 'user_name' => 'wilfred', 'user_hometown' => 'Fridley' })
    end

    it "should not allow firing an event that doesn't exist" do
      expect { @instance.event!(:foo, :quux, { }) }.to raise_error(ArgumentError, /quux/i)
    end

    it "should not allow firing a category that doesn't exist" do
      expect { @instance.event!(:bogus, :signed_up, { }) }.to raise_error(ArgumentError, /bogus/i)
    end

    it "should include defined properties with the event" do
      @instance.event!(:foo, :bar, { :awesomeness => 123, :foo => 'bar' })
      expect_event('xy1_foo_bar', { 'user_name' => 'wilfred', 'user_hometown' => 'Fridley', 'awesomeness' => 123, 'foo' => 'bar' })
    end

    it "should fail if there's a circular reference" do
      circular = { :foo => :bar }
      circular[:baz] = circular

      expect { @instance.event!(:foo, :bar, circular) }.to raise_error(/circular/i)
    end

    it "should pass through lots of different kinds of properties" do
      the_time = Time.parse("2008-09-04 3:46:12 PM -08:00")
      @instance.event!(:foo, :bar, {
        :num1 => 42,
        :num2 => 6.0221413e+23,
        :true => true,
        :false => false,
        :string => 'foobar',
        :symbol => :bazbar,
        :time_interval => 3.months,
        :pos_infinity => (+1.0/0.0),
        :nan => (0.0/0.0),
        :neg_infinity => (-1.0/0.0),
        :time => the_time,
        :stuff => [ "foo", :bar, 123, -9.45e+17, the_time, false, nil, true, "  BoNk " ]
        })
      expect_event('xy1_foo_bar', {
        'user_name' => 'wilfred',
        'user_hometown' => 'Fridley',
        'num1' => 42,
        'num2' => 6.0221413e+23,
        'true' => true,
        'false' => false,
        'string' => 'foobar',
        'symbol' => 'bazbar',
        'time_interval' => 7776000,
        'pos_infinity' => "+infinity",
        'nan' => 'NaN',
        'neg_infinity' => "-infinity",
        'time' => "2008-09-04T23:46:12",
        'stuff' => [ "foo", "bar", 123, -9.45e+17, "2008-09-04T23:46:12", false, nil, true, "BoNk" ],
        })
    end

    it "should let me override implicit properties with user-defined ones" do
      @instance.event!(:foo, :bar, { :user_name => 'bongo' })
      expect_event('xy1_foo_bar', { 'user_name' => 'bongo', 'user_hometown' => 'Fridley' })
    end

    it "should allow nested properties in the event, and expand them out" do
      @instance.event!(:foo, :bar, { :location => { :city => 'Edina', :zip => 55343 } })
      expect_event('xy1_foo_bar', { 'user_name' => 'wilfred', 'user_hometown' => 'Fridley', 'location_city' => 'Edina', 'location_zip' => 55343 })
    end

    it "should accept nested properties from #to_event_properties, and expand them out" do
      @instance.event!(:foo, :bar, { :location => tep_object(:city => 'Edina', :zip => 55343 )})
      expect_event('xy1_foo_bar', { 'user_name' => 'wilfred', 'user_hometown' => 'Fridley', 'location_city' => 'Edina', 'location_zip' => 55343 })
    end

    it "should expand out nested properties using the #property_separator set on the version" do
      i2 = new_instance(@distinct_id, nil, :definitions => definition_set, :version => 3, :implicit_properties => { :user => @user } )
      i2.event!(:bar, :baz, { :location => { :city => 'Edina', :zip => 55343 } })
      expect_event('xy3_bar_baz', { 'user~name' => 'wilfred', 'user~hometown' => 'Fridley', 'location~city' => 'Edina', 'location~zip' => 55343 })
    end

    it "should expand out nested properties from #to_event_properties using the #property_separator set on the version" do
      i2 = new_instance(@distinct_id, nil, :definitions => definition_set, :version => 3, :implicit_properties => { :user => @user } )
      i2.event!(:bar, :baz, { :location => tep_object(:city => 'Edina', :zip => 55343 ) })
      expect_event('xy3_bar_baz', { 'user~name' => 'wilfred', 'user~hometown' => 'Fridley', 'location~city' => 'Edina', 'location~zip' => 55343 })
    end

    it "should not allow firing a retired event" do
      expect { @instance.event!(:foo, :nolonger, { }) }.to raise_error(::MetaEvents::Definition::DefinitionSet::RetiredEventError)
    end
  end

  describe "#effective_properties" do
    it "should validate the event" do
      expect { @instance.effective_properties(:foo, :whatever) }.to raise_error(ArgumentError)
      expect { @instance.effective_properties(:foo, :nolonger) }.to raise_error(::MetaEvents::Definition::DefinitionSet::RetiredEventError)
    end

    it "should include the fully-qualified event name" do
      expect(@instance.effective_properties(:foo, :bar)[:event_name]).to eq('xy1_foo_bar')
    end

    it "should include the distinct ID" do
      expect(@instance.effective_properties(:foo, :bar)[:distinct_id]).to eq(@distinct_id)
    end

    it "should include a distinct ID of nil if there is none" do
      i = new_instance(nil, nil, :definitions => definition_set, :version => 1)
      h = i.effective_properties(:foo, :bar)
      expect(h.has_key?(:distinct_id)).to be_truthy
      expect(h[:distinct_id]).to be_nil
    end

    it "should include the set of implicit and explicit properties" do
      expect(@instance.effective_properties(:foo, :bar)[:properties]).to eq('user_name' => 'wilfred', 'user_hometown' => 'Fridley')
      props = @instance.effective_properties(:foo, :bar, :baz => { :a => 1, :b => 'hoo' }, :user_name => 'bongo')[:properties]
      expect(props).to eq('user_name' => 'bongo', 'user_hometown' => 'Fridley', 'baz_a' => 1, 'baz_b' => 'hoo')
    end

    it "should respect the property_separator" do
      i2 = new_instance(@distinct_id, nil, :definitions => definition_set, :version => 3, :implicit_properties => { :user => @user } )
      expect(i2.effective_properties(:bar, :baz)[:properties]).to eq('user~name' => 'wilfred', 'user~hometown' => 'Fridley')
      props = i2.effective_properties(:bar, :baz, :baz => { :a => 1, :b => 'hoo' }, :'user~name' => 'bongo')[:properties]
      expect(props).to eq('user~name' => 'bongo', 'user~hometown' => 'Fridley', 'baz~a' => 1, 'baz~b' => 'hoo')
    end

    it "should include no additional keys" do
      expect(@instance.effective_properties(:foo, :bar).keys.sort_by(&:to_s)).to eq(%w{distinct_id event_name external_name properties}.map(&:to_sym).sort_by(&:to_s))
    end
  end

  describe "#merge_properties" do
    def expand(hash)
      out = { }
      klass.merge_properties(out, hash, "Z", "", 0)
      out
    end

    def expand_scalar(value)
      expand({ 'foo' => value })['foo']
    end

    it "should return proper values for scalars" do
      expect(expand_scalar('foo')).to eq('foo')
      expect(expand_scalar('  FoO  ')).to eq('FoO')

      expect(expand_scalar(:foo)).to eq('foo')
      expect(expand_scalar(:' FoOO ')).to eq('FoOO')

      expect(expand_scalar(123)).to eq(123)
      expect(expand_scalar(4.2867)).to eq(4.2867)
      expect(expand_scalar(1234567890123456789012345678901234567890123456789012345678901234567890)).to eq(1234567890123456789012345678901234567890123456789012345678901234567890)
      expect(expand_scalar(true)).to eq(true)
      expect(expand_scalar(false)).to eq(false)
      expect(expand_scalar(nil)).to eq(nil)
    end

    it "should raise an error for unknown data, including Hashes" do
      expect { expand_scalar(/foobar/) }.to raise_error(ArgumentError)
      expect { expand_scalar([ "a", "b", /foo/ ]) }.to raise_error(ArgumentError)
    end

    it "should stringify symbols on both keys and values" do
      expect(expand({ :foo => :bar })).to eq({ 'foo' => 'bar' })
    end

    it "should correctly expand simple hashes" do
      expect(expand({ :foo => 'bar' })).to eq({ 'foo' => 'bar' })
      expect(expand({ :zzz => ' bonkO ', 'bar' => :' baZZ ' })).to eq({ 'zzz' => 'bonkO', 'bar' => 'baZZ' })
    end

    it "should recursively expand hashes" do
      expect(expand({ :foo => { :bar => ' whatEVs '} })).to eq({ 'fooZbar' => 'whatEVs' })
      expect { expand({ :foo => { :bar => [ 1, 2, /foo/ ] } }) }.to raise_error(ArgumentError)
    end

    it "should call #to_event_properties for any object, and recursively expand that" do
      expect(expand(:baz => tep_object({ :foo => ' BaR '}))).to eq({ 'bazZfoo' => 'BaR' })
      expect(expand(:baz => tep_object({ :foo => { :bar => ' yo yo yo '} }))).to eq({ 'bazZfooZbar' => 'yo yo yo' })

      subsidiary = tep_object({ :bar => :baz })
      expect(expand(:baz => tep_object({ :foo => subsidiary }))).to eq({ 'bazZfooZbar' => 'baz' })
    end

    it "should raise if it detects a property-name conflict" do
      expect { expand(:fooZbar => :quux1, :foo => { :bar => :quux }) }.to raise_error(MetaEvents::Tracker::PropertyCollisionError)
    end
  end

  describe "#normalize_scalar_property_value" do
    it "should return the correct results for scalars" do
      infinity = (1.0 / 0.0)
      nan = (0.0 / 0.0)

      t = Time.parse("2008-09-04 3:46:12 PM -08:00")
      {
        nil => nil,
        true => true,
        false => false,
        3 => 3,
        42.5e+17 => 42.5e+17,
        3.months => 7776000,
        infinity => "+infinity",
        nan => "NaN",
        -infinity => "-infinity",
        :foobar => 'foobar',
        :' FooBar  ' => 'FooBar',
        ' FooBar  ' => 'FooBar',
        t => "2008-09-04T23:46:12",
        [ "foo", :bar, 123, -9.45e+17, t, false, nil, true, "  BoNk " ] => [ "foo", "bar", 123, -9.45e+17, "2008-09-04T23:46:12", false, nil, true, "BoNk" ],
        /foobar/ => :invalid_property_value,
        Object.new => :invalid_property_value
      }.each do |input, output|
        expect(klass.normalize_scalar_property_value(input)).to eq(output)
      end
    end

    it "should not modify passed values" do
      t = Time.parse("2008-09-04 3:46:12 PM -08:00")
      [
        nil,
        true,
        false,
        3,
        42.5e+17,
        3.months,
        :foobar,
        :' FooBar  ',
        ' FooBar  ',
        t,
        [ "foo", :bar, 123, -9.45e+17, t, false, nil, true, "  BoNk " ],
        /foobar/,
        Object.new
      ].each do |input|
        expect { klass.normalize_scalar_property_value(input) }.to_not change { input }
      end

      nan = (0.0 / 0.0)
      expect { klass.normalize_scalar_property_value(nan) }.to_not change { nan.nan? }

      infinity = (1.0 / 0.0)
      expect { klass.normalize_scalar_property_value(infinity) }.to_not change { infinity.infinite? }

      neg_infinity = -(1.0 / 0.0)
      expect { klass.normalize_scalar_property_value(neg_infinity) }.to_not change { neg_infinity.infinite? }

      expect { klass.normalize_scalar_property_value(t) }.to_not change { t.zone }
    end
  end
end
