require 'couchrest'

##
# A simple class to help use CouchDB and CouchRest with Rails.
#
# You should subclass this so routes are properly generated when making forms.
#
#   class Note < BasicModel; end
#
#   couch_rest = CouchRest.new('http://localhost:5984')
#   db         = couch_rest.database('my_db')
#   note       = Note.new(db.get('22323232'))
#   result     = db.save(note.attributes)
#

class BasicModel

  attr_accessor :attributes

  def self.db(database_name)
    puts "Getting #{database_name}"
    database = CouchRest.database!(database_name)
    # Load views
    file_manager = CouchRest::FileManager.new(File.basename(database_name))
    file_manager.push_views(File.join(Rails.root, "couchdb_views"))

    database
  end

  ##
  # Takes a record from CouchRest ID call and turns it into something
  # usable in Rails.
  #
  #   note = Note.new(db.get('283934927362'))
  #   note.id
  #   note._rev
  #   note.new_record?
  #   note.title # Any field from the record

  def initialize(database_name, attributes={})
    @database_name = database_name
    @attributes    = default_attributes.merge(attributes)
  end

  ##
  # To be overridden by subclasses.

  def default_attributes
    {}
  end

  ##
  # Get a document by its _id.

  def self.find(database_name, id)
    new(database_name, self.db(database_name).get(id))
  end

  ##
  # Takes a set of results from a CouchRest view call and turns the
  # rows into Rails-friendly objects.
  #
  #   notes = Note.init_from_rows(db.view("notes/by_title"))
  #   notes.rows.each {|row| row.id ... }

  def self.view(database_name, view_name, options={})
    results = new(database_name, self.db(database_name).view(view_name, options))
    results.rows.each_with_index do |row, index|
      results.rows[index] = new(database_name, row['value'])
    end
    results
  end

  ##
  # Takes a Hash, merges with existing attributes, and returns them with
  # the intent that they will be serialized to JSON.
  #
  # Useful for sending to CouchRest's db.save method.

  def save(attributes)
    @attributes = @attributes.merge(attributes)
    self.type = self.class.name
    if new_record?
      self.created_at = Time.now
    end
    self.updated_at = Time.now
    self.on_update if self.respond_to?(:on_update)
    self.class.db(@database_name).save(@attributes)
  end

  ##
  # Returns the ID so Rails can use it for forms.

  def id
    _id rescue nil
  end
  alias_method :to_param, :id

  def new_record?
    (_rev).nil?
  rescue NameError
    true
  end

  ##
  # Handles getters and setters for the first level of the hash.
  #
  #   record._rev
  #   record.title
  #   record.title = "Streetside bratwurst vendor"

  def method_missing(method_symbol, *arguments)
    method_name = method_symbol.to_s

    case method_name[-1..-1]
    when "="
      @attributes[method_name[0..-2]] = arguments.first
    when "?"
      @attributes[method_name[0..-2]] == true
    else
      # Returns nil on failure so forms will work
      @attributes.has_key?(method_name) ? @attributes[method_name] : nil
    end
  end

end
