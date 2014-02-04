describe ::MetaEvents::Definition::DefinitionSet do
  let(:klass) { ::MetaEvents::Definition::DefinitionSet }
  let(:instance) { klass.new(:global_events_prefix => "foo") }

  describe "construction" do
    it "should require a global prefix for construction" do
      expect { klass.new }.to raise_error(ArgumentError)
    end

    it "should allow creation with a Symbol for the prefix" do
      klass.new(:global_events_prefix => :bar).global_events_prefix.should == 'bar'
    end

    it "should allow creation without a block" do
      expect { klass.new(:global_events_prefix => 'foo') }.not_to raise_error
    end

    it "should evaluate its block in the context of the object" do
      x = nil
      klass.new(:global_events_prefix => 'abc') { x = global_events_prefix }
      expect(x).to eq('abc')
    end

    it "should validate its options" do
      expect { klass.new(:foo => 'bar') }.to raise_error(ArgumentError, /foo/i)
    end

    it "should allow declaring the global_events_prefix in the block" do
      x = klass.new { global_events_prefix "baz" }
      expect(x.global_events_prefix).to eq("baz")
    end

    it "should be able to create itself from an IO" do
      require 'stringio'
      io = StringIO.new(<<-EOS)
global_events_prefix :abq

version 1, '2014-02-15' do
  category :foo do
    event :bar, '2014-02-16', 'something great'
  end
end
EOS
      set = klass.new(:definition_text => io)
      expect(set.global_events_prefix).to eq('abq')
      expect(set.fetch_event(1, :foo, :bar)).to be_kind_of(::MetaEvents::Definition::Event)
      expect { set.fetch_event(1, :foo, :baz) }.to raise_error
    end

    it "should be able to create itself from a file" do
      require 'tempfile'

      f = Tempfile.new('definition_set_spec')
      begin
        f.puts <<-EOS
global_events_prefix :abq

version 1, '2014-02-15' do
  category :foo do
    event :bar, '2014-02-16', 'something great'
  end
end
EOS
        f.close

        set = klass.new(:definition_text => f.path)
        expect(set.global_events_prefix).to eq('abq')
        expect(set.fetch_event(1, :foo, :bar)).to be_kind_of(::MetaEvents::Definition::Event)
        expect { set.fetch_event(1, :foo, :baz) }.to raise_error
      ensure
        f.close
        f.unlink
      end
    end
 end

 it "should create a new version and pass options properly" do
    version = double("version")
    allow(version).to receive(:number).with().and_return(234)

    passed_block = nil
    expect(::MetaEvents::Definition::Version).to receive(:new).once.with(instance, 123, 'foobar', { :a => :b }) { |&block| passed_block = block; version }

    instance.version(123, 'foobar', { :a => :b }) { :the_right_block }
    expect(passed_block.call).to eq(:the_right_block)

    expect { instance.fetch_version(123) }.to raise_error(ArgumentError)
    expect(instance.fetch_version(234)).to be(version)
  end

  it "should return its prefix" do
    instance.global_events_prefix.should == 'foo'
  end

  it "should raise if there is a version conflict" do
    version_1 = double("version-1")
    allow(version_1).to receive(:number).with().and_return(234)
    expect(::MetaEvents::Definition::Version).to receive(:new).once.with(instance, 123, 'foobar', { }).and_return(version_1)

    instance.version(123, 'foobar')

    version_2 = double("version-2")
    allow(version_2).to receive(:number).with().and_return(234)
    expect(::MetaEvents::Definition::Version).to receive(:new).once.with(instance, 345, 'barfoo', { }).and_return(version_2)

    expect { instance.version(345, 'barfoo') }.to raise_error(/already.*234/)
  end

  context "with two versions" do
    before :each do
      @version_1 = double("version-1")
      allow(@version_1).to receive(:number).with().and_return(1)
      expect(::MetaEvents::Definition::Version).to receive(:new).once.with(instance, 1, 'foo', { }).and_return(@version_1)

      instance.version(1, 'foo')

      @version_2 = double("version-2")
      allow(@version_2).to receive(:number).with().and_return(2)
      expect(::MetaEvents::Definition::Version).to receive(:new).once.with(instance, 2, 'bar', { }).and_return(@version_2)

      instance.version(2, 'bar')
    end

    it "should return the version on #fetch_version" do
      instance.fetch_version(1).should be(@version_1)
      instance.fetch_version(2).should be(@version_2)
    end

    it "should raise if asked for a version it doesn't have" do
      expect { instance.fetch_version(3) }.to raise_error(ArgumentError)
    end

    it "should delegate to the version on #fetch_event" do
      expect(@version_1).to receive(:fetch_event).once.with(:bar, :baz).and_return(:quux)
      expect(instance.fetch_event(1, :bar, :baz)).to eq(:quux)
    end

    it "should raise if asked for an event in a version it doesn't have" do
      expect { instance.fetch_event(3, :foo, :bar) }.to raise_error(ArgumentError)
    end
  end
end
