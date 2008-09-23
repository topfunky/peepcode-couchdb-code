class NotesController < ApplicationController

  def index
    @notes = Note.view(database_name, "notes/by_title-map")
    respond_to do |wants|
      wants.html
      wants.json { render :json => @notes.rows.to_json }
    end
  end

  def show
    @note = Note.find(database_name, params[:id])

    # Attachment
    if params[:filename]
      metadata = @note._attachments[params[:filename]]
      data = Note.db(database_name).fetch_attachment(@note.id, params[:filename])
      send_data(data, {
        :filename    => params[:filename],
        :type        => metadata['content_type'],
        :disposition => "inline",
      })
      return
    end

    respond_to do |wants|
      wants.html
      wants.json { render :json => @note.attributes.to_json }
    end
  end

  def new
    @note = Note.new(database_name)
  end

  def create
    note = Note.new(database_name)
    note.save(params[:note])
    respond_to do |wants|
      wants.html { redirect_to note_url(note) }
    end
  end

  def edit
    @note = Note.find(database_name, params[:id])
  end

  def update
    @note = Note.find(database_name, params[:id])
    @note.save(params[:note])
    respond_to do |wants|
      wants.html { redirect_to note_url(@note) }
    end
    # Can also catch RestClient::RequestFailed for a 412 conflict
  end

  def destroy
  end

end
