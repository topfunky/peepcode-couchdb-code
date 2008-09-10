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

  ##
  # Takes a record from CouchRest ID call and turns it into something
  # usable in Rails.
  #
  #   note = Note.new(db.get('283934927362'))
  #   note.id
  #   note._rev
  #   note.new_record?
  #   note.title # Any field from the record
  
  def initialize(attributes={})
    @attributes = attributes
  end

  ##
  # Takes a set of results from a CouchRest view call and turns the 
  # rows into Rails-friendly objects.
  #
  #   notes = Note.init_from_rows(db.view("notes/by_title"))
  #   notes.rows.each {|row| row.id ... }
  
  def self.init_from_rows(couchdb_results=[])
    results = self.new(couchdb_results)
    results.rows.each_with_index do |row, index|
      results.rows[index] = self.new(row['value'])
    end
    results
  end
  
  ##
  # Takes a Hash, merges with existing attributes, and returns them with
  # the intent that they will be serialized to JSON.
  
  def update(attributes)
    @attributes.merge(attributes)
  end
  
  def id
    _id rescue nil
  end
  alias_method :to_param, :id
  
  def new_record?
    (_id && _rev).nil?
  rescue NameError
    true
  end

  # def self.json_create(o)
  #   new(*o['data'])
  # end
  # 
  # def to_json(*a)
  #   {
  #     'json_class' => self.class.name,
  #     'data' => @attributes
  #   }.to_json(*a)
  # end

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
