require "meta_events"

describe ::MetaEvents::Definition::Category do
  let(:version) do
    out = double("version")
    allow(out).to receive(:kind_of?).with(::MetaEvents::Definition::Version).and_return(true)
    allow(out).to receive(:prefix).with().and_return("vp_")
    out
  end
  let(:klass) { ::MetaEvents::Definition::Category }

  it "should normalize any name passed in" do
    expect(klass.normalize_name(:foo)).to eq(:foo)
    expect(klass.normalize_name('  foo ')).to eq(:foo)
    expect(klass.normalize_name(:FoO)).to eq(:foo)
    expect(klass.normalize_name('  FoO ')).to eq(:foo)

    expect { klass.normalize_name(nil) }.to raise_error(ArgumentError)
    expect { klass.normalize_name("") }.to raise_error(ArgumentError)
  end

  it "should validate its arguments on construction" do
    expect { klass.new(double("whatever"), :foo) }.to raise_error(ArgumentError)
    expect { klass.new(version, nil) }.to raise_error(ArgumentError)
    expect { klass.new(version, :foo, :bar => :baz) }.to raise_error(ArgumentError, /bar/i)
    expect { klass.new(version, :foo, :retired_at => "foo") }.to raise_error(ArgumentError)
  end

  it "should run its block in its own context" do
    expect_any_instance_of(klass).to receive(:foobar).once.with(:bonk)
    klass.new(version, :foo) { foobar(:bonk) }
  end

  context "with an instance" do
    let(:instance) { klass.new(version, :foo) }
    let(:event) do
      out = double("event")
      allow(out).to receive(:name).with().and_return(:baz)
      out
    end

    it "should allow creating an Event" do
      blk = lambda { :whatever }
      expect(::MetaEvents::Definition::Event).to receive(:new).once.with(instance, :quux, :a, :b, :c => :d).and_return(event)
      instance.event(:quux, :a, :b, :c => :d)
    end

    it "should return the prefix correctly" do
      expect(instance.prefix).to eq("vp_foo_")
    end

    context "with an event" do
      before :each do
        expect(::MetaEvents::Definition::Event).to receive(:new).once.with(instance, :quux, :a, :b, :c => :d).and_return(event)
        instance.event(:quux, :a, :b, :c => :d)
      end

      it "should not allow creating two Events with the same name" do
        event_2 = double("event-2")
        allow(event_2).to receive(:name).with().and_return(:baz)
        expect(::MetaEvents::Definition::Event).to receive(:new).once.with(instance, :marph, :www).and_return(event_2)

        expect { instance.event(:marph, :www) }.to raise_error(ArgumentError, /baz/)
      end

      it "should allow retrieving the event, and normalize names" do
        expect(instance.event_named(:baz)).to be(event)
        expect(instance.event_named(:BaZ)).to be(event)
        expect(instance.event_named(' BaZ ')).to be(event)
      end

      it "should raise if you ask for an event that doesn't exist" do
        expect { instance.event_named(:doesnotexist) }.to raise_error(ArgumentError)
      end
    end

    it "should return the correct value for #retired_at" do
      allow(version).to receive(:retired_at).with().and_return(nil)
      expect(instance.retired_at).to be_nil

      expect(klass.new(version, :foo, :retired_at => "2014-06-21").retired_at).to eq(Time.parse("2014-06-21"))

      allow(version).to receive(:retired_at).with().and_return(Time.parse("2014-02-01"))
      expect(klass.new(version, :foo).retired_at).to eq(Time.parse("2014-02-01"))
      expect(klass.new(version, :foo, :retired_at => "2014-06-21").retired_at).to eq(Time.parse("2014-02-01"))
      expect(klass.new(version, :foo, :retired_at => "2013-06-21").retired_at).to eq(Time.parse("2013-06-21"))
    end

    it "should turn itself into a string reasonably" do
      allow(version).to receive(:to_s).with().and_return("boogabooga")

      expect(instance.to_s).to match(/category/i)
      expect(instance.to_s).to match(/foo/i)
      expect(instance.to_s).to match(/boogabooga/i)
    end
  end
end
