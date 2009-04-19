require File.dirname(__FILE__) + '/../../spec_helper'
require File.join(FIXTURE_PATH, 'more', 'article')
require File.join(FIXTURE_PATH, 'more', 'course')

describe "ExtendedDocument views" do

  class Unattached < CouchRest::ExtendedDocument
    # Note: no use_database here
    property :title
    property :questions
    property :professor
    view_by :title
  end
  
  describe "a model with simple views and a default param" do
    before(:all) do
      Article.all.map{|a| a.destroy(true)}
      Article.database.bulk_delete
      written_at = Time.now - 24 * 3600 * 7
      @titles = ["this and that", "also interesting", "more fun", "some junk"]
      @titles.each do |title|
        a = Article.new(:title => title)
        a.date = written_at
        a.save
        written_at += 24 * 3600
      end
    end

    it "should have a design doc" do
      Article.design_doc["views"]["by_date"].should_not be_nil
    end
  
    it "should save the design doc" do
      Article.by_date #rescue nil
      doc = Article.database.get Article.design_doc.id
      doc['views']['by_date'].should_not be_nil
    end
  
    it "should return the matching raw view result" do
      view = Article.by_date :raw => true
      view['rows'].length.should == 4
    end
  
    it "should not include non-Articles" do
      Article.database.save_doc({"date" => 1})
      view = Article.by_date :raw => true
      view['rows'].length.should == 4
    end
  
    it "should return the matching objects (with default argument :descending => true)" do
      articles = Article.by_date
      articles.collect{|a|a.title}.should == @titles.reverse
    end
  
    it "should allow you to override default args" do
      articles = Article.by_date :descending => false
      articles.collect{|a|a.title}.should == @titles
    end
  end

  describe "another model with a simple view" do
    before(:all) do
      reset_test_db!
      %w{aaa bbb ddd eee}.each do |title|
        Course.new(:title => title).save
      end
    end
    it "should make the design doc upon first query" do
      Course.by_title 
      doc = Course.design_doc
      doc['views']['all']['map'].should include('Course')
    end
    it "should can query via view" do
      # register methods with method-missing, for local dispatch. method
      # missing lookup table, no heuristics.
      view = Course.view :by_title
      designed = Course.by_title
      view.should == designed
    end
    it "should get them" do
      rs = Course.by_title 
      rs.length.should == 4
    end
    it "should yield" do
      courses = []
      Course.view(:by_title) do |course|
        courses << course
      end
      courses[0]["doc"]["title"].should =='aaa'
    end
    it "should yield with by_key method" do
      courses = []
      Course.by_title do |course|
        courses << course
      end
      courses[0]["doc"]["title"].should =='aaa'
    end
  end


  describe "a ducktype view" do
    before(:all) do
      @id = TEST_SERVER.default_database.save_doc({:dept => true})['id']
    end
    it "should setup" do
      duck = Course.get(@id) # from a different db
      duck["dept"].should == true
    end
    it "should make the design doc" do
      @as = Course.by_dept
      @doc = Course.design_doc
      @doc["views"]["by_dept"]["map"].should_not include("couchrest")
    end
    it "should not look for class" do |variable|
      @as = Course.by_dept
      @as[0]['_id'].should == @id
    end
  end

  describe "a model class not tied to a database" do
    before(:all) do
      reset_test_db!
      @db = TEST_SERVER.default_database
      %w{aaa bbb ddd eee}.each do |title|
        u = Unattached.new(:title => title)
        u.database = @db
        u.save
        @first_id ||= u.id
      end
    end
    it "should barf on all if no database given" do
      lambda{Unattached.all}.should raise_error
    end
    it "should query all" do
      rs = Unattached.all :database=>@db
      rs.length.should == 4
    end
    it "should barf on query if no database given" do
      lambda{Unattached.view :by_title}.should raise_error
    end
    it "should make the design doc upon first query" do
      Unattached.by_title :database=>@db
      doc = Unattached.design_doc
      doc['views']['all']['map'].should include('Unattached')
    end
    it "should merge query params" do
      rs = Unattached.by_title :database=>@db, :startkey=>"bbb", :endkey=>"eee"
      rs.length.should == 3
    end
    it "should query via view" do
      view = Unattached.view :by_title, :database=>@db
      designed = Unattached.by_title :database=>@db
      view.should == designed
    end
    it "should yield" do
      things = []
      Unattached.view(:by_title, :database=>@db) do |thing|
        things << thing
      end
      things[0]["doc"]["title"].should =='aaa'
    end
    it "should yield with by_key method" do
      things = []
      Unattached.by_title(:database=>@db) do |thing|
        things << thing
      end
      things[0]["doc"]["title"].should =='aaa'
    end
    it "should barf on get if no database given" do
      lambda{Unattached.get("aaa")}.should raise_error
    end
    it "should get from specific database" do
      u = Unattached.get(@first_id, @db)
      u.title.should == "aaa"
    end
    it "should barf on first if no database given" do
      lambda{Unattached.first}.should raise_error
    end
    it "should get first" do
      u = Unattached.first :database=>@db
      u.title.should =~ /\A...\z/
    end
    it "should barf on all_design_doc_versions if no database given" do
      lambda{Unattached.all_design_doc_versions}.should raise_error
    end
    it "should clean up design docs left around on specific database" do
      Unattached.by_title :database=>@db
      Unattached.all_design_doc_versions(@db)["rows"].length.should == 1
      Unattached.view_by :questions
      Unattached.by_questions :database=>@db
      Unattached.all_design_doc_versions(@db)["rows"].length.should == 2
      Unattached.cleanup_design_docs!(@db)
      Unattached.all_design_doc_versions(@db)["rows"].length.should == 1
    end
  end

  describe "class proxy" do
    before(:all) do
      reset_test_db!
      @us = Unattached.on(TEST_SERVER.default_database)
      %w{aaa bbb ddd eee}.each do |title|
        u = @us.new(:title => title)
        u.save
        @first_id ||= u.id
      end
    end
    it "should query all" do
      rs = @us.all
      rs.length.should == 4
    end
    it "should make the design doc upon first query" do
      @us.by_title
      doc = @us.design_doc
      doc['views']['all']['map'].should include('Unattached')
    end
    it "should merge query params" do
      rs = @us.by_title :startkey=>"bbb", :endkey=>"eee"
      rs.length.should == 3
    end
    it "should query via view" do
      view = @us.view :by_title
      designed = @us.by_title
      view.should == designed
    end
    it "should yield" do
      things = []
      @us.view(:by_title) do |thing|
        things << thing
      end
      things[0]["doc"]["title"].should =='aaa'
    end
    it "should yield with by_key method" do
      things = []
      @us.by_title do |thing|
        things << thing
      end
      things[0]["doc"]["title"].should =='aaa'
    end
    it "should get from specific database" do
      u = @us.get(@first_id)
      u.title.should == "aaa"
    end
    it "should get first" do
      u = @us.first
      u.title.should =~ /\A...\z/
    end
    it "should clean up design docs left around on specific database" do
      @us.by_title
      @us.all_design_doc_versions["rows"].length.should == 1
      Unattached.view_by :professor
      @us.by_professor
      @us.all_design_doc_versions["rows"].length.should == 2
      @us.cleanup_design_docs!
      @us.all_design_doc_versions["rows"].length.should == 1
    end
  end

  describe "a model with a compound key view" do
    before(:all) do
      Article.design_doc_fresh = false
      Article.by_user_id_and_date.each{|a| a.destroy(true)}
      Article.database.bulk_delete
      written_at = Time.now - 24 * 3600 * 7
      @titles = ["uniq one", "even more interesting", "less fun", "not junk"]
      @user_ids = ["quentin", "aaron"]
      @titles.each_with_index do |title,i|
        u = i % 2
        a = Article.new(:title => title, :user_id => @user_ids[u])
        a.date = written_at
        a.save
        written_at += 24 * 3600
      end
    end
    it "should create the design doc" do
      Article.by_user_id_and_date rescue nil
      doc = Article.design_doc
      doc['views']['by_date'].should_not be_nil
    end
    it "should sort correctly" do
      articles = Article.by_user_id_and_date
      articles.collect{|a|a['user_id']}.should == ['aaron', 'aaron', 'quentin', 
        'quentin']
      articles[1].title.should == 'not junk'
    end
    it "should be queryable with couchrest options" do
      articles = Article.by_user_id_and_date :limit => 1, :startkey => 'quentin'
      articles.length.should == 1
      articles[0].title.should == "even more interesting"
    end
  end

  describe "with a custom view" do
    before(:all) do
      @titles = ["very uniq one", "even less interesting", "some fun", 
        "really junk", "crazy bob"]
      @tags = ["cool", "lame"]
      @titles.each_with_index do |title,i|
        u = i % 2
        a = Article.new(:title => title, :tags => [@tags[u]])
        a.save
      end
    end
    it "should be available raw" do
      view = Article.by_tags :raw => true
      view['rows'].length.should == 5
    end

    it "should be default to :reduce => false" do
      ars = Article.by_tags
      ars.first.tags.first.should == 'cool'
    end
  
    it "should be raw when reduce is true" do
      view = Article.by_tags :reduce => true, :group => true
      view['rows'].find{|r|r['key'] == 'cool'}['value'].should == 3
    end
  end

  # TODO: moved to Design, delete
  describe "adding a view" do
    before(:each) do
      reset_test_db!
      Article.by_date
      @design_docs = Article.database.documents :startkey => "_design/", :endkey => "_design/\u9999"
    end
    it "should not create a design doc on view definition" do
      Article.view_by :created_at
      newdocs = Article.database.documents :startkey => "_design/", :endkey => "_design/\u9999"
      newdocs["rows"].length.should == @design_docs["rows"].length
    end
    it "should create a new version of the design document on view access" do
      ddocs = Article.all_design_doc_versions["rows"].length
      Article.view_by :updated_at
      Article.by_updated_at
      Article.all_design_doc_versions["rows"].length.should == ddocs + 1
      Article.design_doc["views"].keys.should include("by_updated_at")
    end
  end

  describe "with a lot of designs left around" do
    before(:each) do
      reset_test_db!
      Article.by_date
      Article.view_by :field
      Article.by_field
    end
    it "should clean them up" do
      Article.view_by :stream
      Article.by_stream
      Article.all_design_doc_versions["rows"].length.should > 1
      Article.cleanup_design_docs!
      Article.all_design_doc_versions["rows"].length.should == 1
    end
  end
end
