require File.expand_path('../../../spec_helper', __FILE__)
require File.join(FIXTURE_PATH, 'more', 'person')
require File.join(FIXTURE_PATH, 'more', 'card')
require File.join(FIXTURE_PATH, 'more', 'invoice')
require File.join(FIXTURE_PATH, 'more', 'service')
require File.join(FIXTURE_PATH, 'more', 'event')


describe "ExtendedDocument properties" do
  
  before(:each) do
    reset_test_db!
    @card = Card.new(:first_name => "matt")
  end
  
  it "should be accessible from the object" do
    @card.properties.should be_an_instance_of(Array)
    @card.properties.map{|p| p.name}.should include("first_name")
  end
  
  it "should let you access a property value (getter)" do
    @card.first_name.should == "matt"
  end
  
  it "should let you set a property value (setter)" do
    @card.last_name = "Aimonetti"
    @card.last_name.should == "Aimonetti"
  end
  
  it "should not let you set a property value if it's read only" do
    lambda{@card.read_only_value = "test"}.should raise_error
  end
  
  it "should let you use an alias for an attribute" do
    @card.last_name = "Aimonetti"
    @card.family_name.should == "Aimonetti"
    @card.family_name.should == @card.last_name
  end
  
  it "should let you use an alias for a casted attribute" do
    @card.cast_alias = Person.new(:name => "Aimonetti")
    @card.cast_alias.name.should == "Aimonetti"
    @card.calias.name.should == "Aimonetti"
    card = Card.new(:first_name => "matt", :cast_alias => {:name => "Aimonetti"})
    card.cast_alias.name.should == "Aimonetti"
    card.calias.name.should == "Aimonetti"
  end
  
  it "should be auto timestamped" do
    @card.created_at.should be_nil
    @card.updated_at.should be_nil
    @card.save.should be_true
    @card.created_at.should_not be_nil
    @card.updated_at.should_not be_nil
  end
  
  describe "validation" do
    before(:each) do
      @invoice = Invoice.new(:client_name => "matt", :employee_name => "Chris", :location => "San Diego, CA")
    end
    
    it "should be able to be validated" do
      @card.valid?.should == true
    end

    it "should let you validate the presence of an attribute" do
      @card.first_name = nil
      @card.should_not be_valid
      @card.errors.should_not be_empty
      @card.errors.on(:first_name).should == ["First name must not be blank"]
    end
    
    it "should let you look up errors for a field by a string name" do
      @card.first_name = nil
      @card.should_not be_valid
      @card.errors.on('first_name').should == ["First name must not be blank"]
    end

    it "should validate the presence of 2 attributes" do
      @invoice.clear
      @invoice.should_not be_valid
      @invoice.errors.should_not be_empty
      @invoice.errors.on(:client_name).first.should == "Client name must not be blank"
      @invoice.errors.on(:employee_name).should_not be_empty
    end
    
    it "should let you set an error message" do
      @invoice.location = nil
      @invoice.valid?
      @invoice.errors.on(:location).should == ["Hey stupid!, you forgot the location"]
    end
    
    it "should validate before saving" do
      @invoice.location = nil
      @invoice.should_not be_valid
      @invoice.save.should be_false
      @invoice.should be_new_document
    end
  end
  
  describe "autovalidation" do
    before(:each) do
      @service = Service.new(:name => "Coumpound analysis", :price => 3_000)
    end
    
    it "should be valid" do
      @service.should be_valid
    end
    
    it "should not respond to properties not setup" do
      @service.respond_to?(:client_name).should be_false
    end
    
    describe "property :name, :length => 4...20" do
      
      it "should autovalidate the presence when length is set" do
        @service.name = nil
        @service.should_not be_valid
        @service.errors.should_not be_nil
        @service.errors.on(:name).first.should == "Name must be between 4 and 19 characters long"
      end
    
      it "should autovalidate the correct length" do
        @service.name = "a"
        @service.should_not be_valid
        @service.errors.should_not be_nil
        @service.errors.on(:name).first.should == "Name must be between 4 and 19 characters long"
      end
    end
  end
  
  describe "casting" do
    describe "cast keys to any type" do
      before(:all) do
        event_doc = { :subject => "Some event", :occurs_at => Time.now }
        e = Event.database.save_doc event_doc

        @event = Event.get e['id']
      end
      it "should cast created_at to Time" do
        @event['occurs_at'].should be_an_instance_of(Time)
      end
    end
    
    describe "casting to Float object" do
      class RootBeerFloat < CouchRest::ExtendedDocument
        use_database DB
        property :price, :cast_as => 'Float'
      end
      
      it "should convert a string into a float if casted as so" do
        RootBeerFloat.new(:price => '12.50').price.should == 12.50
        RootBeerFloat.new(:price => '9').price.should == 9.0
        RootBeerFloat.new(:price => '-9').price.should == -9.0
      end
      
      it "should not convert a string if it's not a string that can be cast as a float" do
        RootBeerFloat.new(:price => 'test').price.should == 'test'
      end
      
      it "should work fine when a float is being passed" do
        RootBeerFloat.new(:price => 9.99).price.should == 9.99
      end
    end
    
    describe "casting to a boolean value" do
      class RootBeerFloat < CouchRest::ExtendedDocument
        use_database DB
        property :tasty, :cast_as => :boolean
      end

      it "should add an accessor with a '?' for boolean attributes that returns true or false" do
        RootBeerFloat.new(:tasty => true).tasty?.should == true
        RootBeerFloat.new(:tasty => 'you bet').tasty?.should == true
        RootBeerFloat.new(:tasty => 123).tasty?.should == true

        RootBeerFloat.new(:tasty => false).tasty?.should == false
        RootBeerFloat.new(:tasty => 'false').tasty?.should == false
        RootBeerFloat.new(:tasty => 'FaLsE').tasty?.should == false
        RootBeerFloat.new(:tasty => nil).tasty?.should == false
      end

      it "should return the real value when the default accessor is used" do
        RootBeerFloat.new(:tasty => true).tasty.should == true
        RootBeerFloat.new(:tasty => 'you bet').tasty.should == 'you bet'
        RootBeerFloat.new(:tasty => 123).tasty.should == 123
        RootBeerFloat.new(:tasty => 'false').tasty.should == 'false'
        RootBeerFloat.new(:tasty => false).tasty.should == false
        RootBeerFloat.new(:tasty => nil).tasty.should == nil
      end
    end

  end
  
end
