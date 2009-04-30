class Note < CouchRest::ExtendedDocument

  #   def default_attributes
  #     {
  #       "title" => nil,
  #       "description" => nil,
  #       "tags" => [],
  #       "visited_on" => Time.now.strftime('%Y/%m/%d')
  #     }
  #   end

  #   ##
  #   # Coerce fields into the proper types of objects.

  #   def on_update
  #     if (tags = @attributes['tags']) && tags.is_a?(String)
  #       @attributes['tags'] = tags.split(" ")
  #     end
  #   end

  # unique_id :slug

  use_database SERVER.default_database

  property :title
  property :description
  property :tags, :default => []
  property :visited_on, :default => lambda { Time.now.strftime('%Y/%m/%d') }

  timestamps!

  view_by :title, {
    :map =>
    "function(doc) {
      if (doc['couchrest-type'] == 'Note') {
        emit(doc.title, doc);
      }
    }"
  }

  view_by :tag, {
    :map =>
    "function(doc) {
      if (doc['couchrest-type'] == 'Note' && doc.tags) {
        doc.tags.map(function(tag) {
          emit(tag, doc);
        });
      }
    }",
    :reduce =>
    "function(key, values, combine) {
      return {'tag':key[0][0], 'count':values.length};
    }"
  }

  view_by :updated_at, {
    :map =>
    "function(doc) {
      if (doc['couchrest-type'] == 'Note') {
        emit(Date.parse(doc.updated_at.data), doc);
      }
    }"
  }

  view_by :visited_on, {
    :map =>
    "function(doc) {
      if (doc['couchrest-type'] == 'Note' && doc.visited_on) {
        emit(Util.dateAsArray(doc.visited_on), doc);
      }
    }"
  }

end
