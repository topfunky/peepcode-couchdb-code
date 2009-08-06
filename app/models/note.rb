class Note < CouchRest::ExtendedDocument

  use_database SERVER.default_database

  property :title
  property :description
  property :tags, :default => []
  property :visited_on, :default => lambda { Time.now }

  timestamps!

  save_callback :before, :coerce_tags
  #  save_callback :before, :handle_attachments

  def attachment=(attachment)
    if attachment.is_a?(Tempfile)
      attachment_filename = File.basename(attachment.original_filename)
      attachment_options = {
        :file => attachment,
        :name => attachment_filename,
        :content_type => attachment.content_type
      }
      if self['_attachments'].has_key?(attachment_filename)
        update_attachment(attachment_options)
      else
        create_attachment(attachment_options)
      end
    end
  end

  ##
  # Force tags to go through the assignment which converts them to an Array.

  def coerce_tags
    self.tags = self.tags
  end

  ##
  # If a String is given, split it into an Array for storage.

  def tags=(tags)
    if tags.is_a?(String)
      self['tags'] = tags.split(' ')
    else
      self['tags'] = tags
    end
  end

  ##
  # Return the tags array as a whitespace delimited string.

  def tags_string
    tags.join(' ')
  end

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
        emit(Date.parse(doc.visited_on.data), doc);
      }
    }"
  }

  private

  def handle_attachments
    # Save an attachment
    if self['attachment'].is_a?(ActionController::UploadedTempfile)
      attachment = self.delete("attachment")
      self["_attachments"] ||= {}
      filename = File.basename(attachment.original_filename)
      self["_attachments"][filename] = {
        "content_type" => attachment.content_type,
        "data" => attachment.read
      }
    else
      self.delete("attachment")
    end
  end

end
