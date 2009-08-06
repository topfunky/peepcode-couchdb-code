class NotesController < ApplicationController

  def index
    @notes = Note.by_title
    respond_to do |wants|
      wants.html
      wants.json { render :json => @notes.rows.to_json }
    end
  end

  def show
    @note = Note.get(params[:id])

    # Attachment
    if params[:filename]
      metadata = @note['_attachments'][params[:filename]]
      data = @note.read_attachment(params[:filename])
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
    @note = Note.new
  end

  def create
    note = Note.new(params[:note])
    note.save
    respond_to do |wants|
      wants.html { redirect_to note_url(note.id) }
    end
  end

  def edit
    @note = Note.get(params[:id])
  end

  def update
    @note = Note.get(params[:id])
    @note.update_attributes(params[:note])
    respond_to do |wants|
      wants.html { redirect_to note_url(@note.id) }
    end
    # Can also catch RestClient::RequestFailed for a 412 conflict
  end

  def destroy
  end

end
