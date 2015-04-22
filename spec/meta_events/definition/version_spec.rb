require 'meta_events/definition/version'

describe ::MetaEvents::Definition::Version do
  let(:definition_set) do
    out = double("definition_set")
    allow(out).to receive(:kind_of?).with(::MetaEvents::Definition::DefinitionSet).and_return(true)
    allow(out).to receive(:global_events_prefix).with().and_return("gep")
    out
  end

  let(:klass) { ::MetaEvents::Definition::Version }
  let(:instance) { klass.new(definition_set, 3, "2014-02-03") }

  it "should require valid parameters for construction" do
    expect { klass.new(double("not-a-definition-set"), 1, "2014-01-01") }.to raise_error(ArgumentError)
    expect { klass.new(definition_set, "foo", "2014-01-01") }.to raise_error(ArgumentError)
    expect { klass.new(definition_set, 1, nil) }.to raise_error
    expect { klass.new(definition_set, 1, "2014-01-01", :foo => :bar) }.to raise_error(ArgumentError, /foo/i)
  end

  it "should return the definition set, number, and introduction time" do
    expect(instance.definition_set).to be(definition_set)
    expect(instance.number).to eq(3)
    expect(instance.introduced).to eq(Time.parse("2014-02-03"))
  end

  it "should evaluate its block in its own context" do
    expect_any_instance_of(klass).to receive(:foobar).once.with(:bonk)
    klass.new(definition_set, 3, "2014-02-03") { foobar(:bonk) }
  end

  it "should return the prefix correctly" do
    instance.prefix.should == "gep3_"
  end

  it "should set the property_separator to underscore by default" do
    instance.property_separator.should == "_"
  end

  it "should allow setting the property separator to something else in the constructor" do
    i2 = klass.new(definition_set, 3, "2014-02-03", :property_separator => 'Z')
    i2.property_separator.should == "Z"
  end

  context "with one category" do
    let(:category) do
      out = double("category")
      allow(out).to receive(:name).with().and_return(:quux)
      out
    end

    it "should be able to create a new category, and retrieve it" do
      blk = lambda { :whatever }
      expect(::MetaEvents::Definition::Category).to receive(:new).once.with(instance, ' FooBar ', :bar => :baz) do |*args, &block|
        expect(block).to eq(blk)
      end.and_return(category)
      instance.category(' FooBar ', :bar => :baz, &blk)

      expect(instance.category_named(:quux)).to be(category)
    end

    it "should not allow creating duplicate categories" do
      expect(::MetaEvents::Definition::Category).to receive(:new).once.with(instance, :quux, { }).and_return(category)
      instance.category(:quux)

      category_2 = double("category-2")
      allow(category_2).to receive(:name).with().and_return(:quux)
      expect(::MetaEvents::Definition::Category).to receive(:new).once.with(instance, :baz, { }).and_return(category_2)
      expect { instance.category(:baz) }.to raise_error(ArgumentError, /baz/i)
    end

    it "should allow retrieving the category, and normalize the name" do
      expect(::MetaEvents::Definition::Category).to receive(:new).once.with(instance, :quux, { }).and_return(category)
      instance.category(:quux)

      instance.category_named(' QuuX ').should be(category)
    end

    it "should delegate to the category on #fetch_event" do
      expect(::MetaEvents::Definition::Category).to receive(:new).once.with(instance, :quux, { }).and_return(category)
      instance.category(:quux)

      expect(category).to receive(:event_named).once.with(:foobar).and_return(:bonk)
      instance.fetch_event(:quux, :foobar).should == :bonk
    end
  end

  it "should return the #retired_at properly" do
    expect(instance.retired_at).to be_nil

    new_instance = klass.new(definition_set, 4, "2014-01-01", :retired_at => "2015-01-01")
    expect(new_instance.retired_at).to eq(Time.parse("2015-01-01"))
  end

  it "should turn itself into a string reasonably" do
    expect(instance.to_s).to match(/Version/)
    expect(instance.to_s).to match(/3/)
  end
end
