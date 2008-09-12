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
    result = note.save(params[:note])
    respond_to do |wants|
      wants.html { redirect_to note_url(result["id"]) }
    end
  end

  def edit
    @note = Note.find(database_name, params[:id])
  end

  def update
    @note = Note.find(database_name, params[:id])
    if @note.save(params[:note])
      respond_to do |wants|
        wants.html { redirect_to note_url(@note) }
      end
    else
      respond_to do |wants|
        wants.html { render :action => "edit" }
      end
    end
  end

  def destroy
  end
  
end
