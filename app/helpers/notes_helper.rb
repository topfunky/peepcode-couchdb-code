module NotesHelper

  def couchdb_rev_field(form, record)
    unless record.new_record?
      form.hidden_field("rev")
    end
  end

end
