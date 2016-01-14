describe ::MetaEvents::Definition::Event do
  let(:klass) { ::MetaEvents::Definition::Event }

  it "should normalize the name properly" do
    expect { klass.normalize_name(nil) }.to raise_error(ArgumentError)
    expect { klass.normalize_name("") }.to raise_error(ArgumentError)
    expect(klass.normalize_name(:foo)).to eq(:foo)
    expect(klass.normalize_name(:' FoO')).to eq(:foo)
    expect(klass.normalize_name(" FOo ")).to eq(:foo)
    expect(klass.normalize_name("foo")).to eq(:foo)
  end

  let(:category) do
    out = double("category")
    allow(out).to receive(:kind_of?).with(::MetaEvents::Definition::Category).and_return(true)
    allow(out).to receive(:name).with().and_return(:catname)
    allow(out).to receive(:retired_at).with().and_return(nil)
    allow(out).to receive(:prefix).with().and_return("cp_")
    allow(out).to receive(:to_s).with().and_return("cat_to_s")
    out
  end

  it "should validate its basic arguments properly" do
    expect { klass.new(double("not-a-category"), :foo, "2014-01-01", "something") }.to raise_error(ArgumentError)
    expect { klass.new(category, nil, "2014-01-01", "something") }.to raise_error(ArgumentError)
    expect { klass.new(category, :foo, "2014-01-01", "something", :bonk => :baz) }.to raise_error(ArgumentError, /bonk/i)
  end

  it "should fail if you don't set introduced or desc" do
    expect { klass.new(category, :foo, :introduced => '2014-01-01' ) }.to raise_error(ArgumentError)
    expect { klass.new(category, :foo, :desc => 'something' ) }.to raise_error(ArgumentError)
    expect { klass.new(category, :foo, :desc => '' ) }.to raise_error(ArgumentError)
  end

  it "should let you set introduced via all three mechanisms" do
    expect(klass.new(category, :foo, "2014-01-01", "foobar").introduced).to eq(Time.parse('2014-01-01'))
    expect(klass.new(category, :foo, nil, "foobar", :introduced => '2014-01-01').introduced).to eq(Time.parse('2014-01-01'))
    expect(klass.new(category, :foo, nil, "foobar") { introduced '2014-01-01' }.introduced).to eq(Time.parse('2014-01-01'))
  end

  it "should let you set desc via all three mechanisms" do
    expect(klass.new(category, :foo, "2014-01-01", "foobar").desc).to eq("foobar")
    expect(klass.new(category, :foo, "2014-01-01", :desc => 'foobar').desc).to eq("foobar")
    expect(klass.new(category, :foo, "2014-01-01", :description => 'foobar').desc).to eq("foobar")
    expect(klass.new(category, :foo, "2014-01-01") { desc 'foobar' }.desc).to eq("foobar")
  end

  it "should let you set external_name via both mechanisms" do
    expect(klass.new(category, :foo, "2014-01-01", "foobar", :external_name => "custom external name").external_name).to eq("custom external name")
    expect(klass.new(category, :foo, "2014-01-01", "foobar") { external_name "custom external name" }.external_name).to eq("custom external name")
  end

  context "with an instance" do
    let(:instance) { klass.new(category, :foo, "2014-01-01", "foobar") }

    describe "validation" do
      it "should not fail by default" do
        expect { instance.validate!(:foo => :bar) }.not_to raise_error
      end

      it "should fail if it's been retired" do
        expect { klass.new(category, :foo, "2014-01-01", "foobar", :retired_at => "2013-06-01").validate!(:foo => :bar) }.to raise_error(::MetaEvents::Definition::DefinitionSet::RetiredEventError, /2013/)
      end

      it "should fail if its category has been retired" do
        allow(category).to receive(:retired_at).and_return(Time.parse("2013-02-01"))
        expect { instance.validate!(:foo => :bar) }.to raise_error(::MetaEvents::Definition::DefinitionSet::RetiredEventError, /2013/)
      end

      it "should fail if required properties are missing" do
        expect { klass.new(category, :foo, "2016-1-1", "foobar", :required_properties => [ :foo ]).validate!(:baz => :bar) }.to raise_error(::MetaEvents::Definition::DefinitionSet::RequiredPropertyMissingError, /foo/)
      end

      it "should fail if required properties have blank values" do
        expect { klass.new(category, :foo, "2016-1-1", "foobar", :required_properties => [ :foo ]).validate!(:foo => '') }.to raise_error(::MetaEvents::Definition::DefinitionSet::RequiredPropertyMissingError, /foo/)
      end
    end

    it "should return and allow setting its description via #desc" do
      expect(instance.desc).to eq("foobar")
      instance.desc "barbaz"
      expect(instance.desc).to eq("barbaz")
    end

    it "should return and allow setting its introduction time via #introduced" do
      expect(instance.introduced).to eq(Time.parse("2014-01-01"))
      instance.introduced "2015-06-30"
      expect(instance.introduced).to eq(Time.parse("2015-06-30"))
    end

    it "should return its category" do
      expect(instance.category).to eq(category)
    end

    it "should return its name" do
      expect(instance.name).to eq(:foo)
    end

    it "should return its category name" do
      expect(instance.category_name).to eq(:catname)
    end

    it "should return its full name" do
      expect(instance.full_name).to eq("cp_foo")
    end

    it "should return the right value for #retired_at" do
      expect(instance.retired_at).to be_nil
      expect(klass.new(category, :foo, "2014-01-01", "foobar", :retired_at => "2013-06-01").retired_at).to eq(Time.parse("2013-06-01"))

      allow(category).to receive(:retired_at).with().and_return(Time.parse("2013-04-01"))
      expect(klass.new(category, :foo, "2014-01-01", "foobar", :retired_at => "2013-06-01").retired_at).to eq(Time.parse("2013-04-01"))
      expect(klass.new(category, :foo, "2014-01-01", "foobar", :retired_at => "2013-02-01").retired_at).to eq(Time.parse("2013-02-01"))
      expect(klass.new(category, :foo, "2014-01-01", "foobar").retired_at).to eq(Time.parse("2013-04-01"))
    end

    it "should become a string" do
      expect(instance.to_s).to match(/foo/i)
      expect(instance.to_s).to match(/cat_to_s/i)
    end

    it "should require valid data for #note" do
      expect { instance.note("", "me", "something here") }.to raise_error(ArgumentError)
      expect { instance.note("2014-01-01", "", "something here") }.to raise_error(ArgumentError)
      expect { instance.note("2014-01-01", "me", "") }.to raise_error(ArgumentError)
    end

    it "should allow you to add notes, and return them" do
      instance.note("2014-01-01", "me", "this is cool")
      instance.note("2013-02-27", "someone else", "whatever")

      expect(instance.notes.length).to eq(2)

      note_1 = instance.notes[0]
      expect(note_1[:when_left]).to eq(Time.parse("2014-01-01"))
      expect(note_1[:who]).to eq("me")
      expect(note_1[:text]).to eq("this is cool")

      note_2 = instance.notes[1]
      expect(note_2[:when_left]).to eq(Time.parse("2013-02-27"))
      expect(note_2[:who]).to eq("someone else")
      expect(note_2[:text]).to eq("whatever")
    end

    context "with a custom external name" do
      let(:instance) { klass.new(category, :foo, "2014-01-01", "foobar", :external_name => "custom external name") }

      it "should return and allow setting its external name via #external_name" do
        expect(instance.external_name).to eq("custom external name")
        instance.external_name "my name"
        expect(instance.external_name).to eq("my name")
      end
    end

    context "with required properties" do
      it "should work with strings and symbols" do
        expect do
          event = klass.new(category, :foo, "2016-1-1", "foobar", :required_properties => [ "string", :symbol ])
          event.validate!('string' => "foo", :symbol => "foo")
          event.validate!(:string => "foo", "symbol" => "foo")
        end.to_not raise_error(::MetaEvents::Definition::DefinitionSet::RequiredPropertyMissingError)
      end
    end
  end
end
