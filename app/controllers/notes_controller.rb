class NotesController < ApplicationController

  def index
    @notes = Note.init_from_rows(db.view("notes/by_title"))
    respond_to do |wants|
      wants.html
      wants.json { render :json => @notes.rows.to_json }
    end    
  end

  def show
    @note = Note.new(db.get(params[:id]))
    respond_to do |wants|
      wants.html
      wants.json { render :json => @note.attributes.to_json }
    end
  end

  def new
    @note = Note.new
  end

  def create
    result = db.save(params[:note])
    respond_to do |wants|
      wants.html { redirect_to note_url(result["id"]) }
    end
  end

  def edit
    @note = Note.new(db.get(params[:id]))
  end

  def update
    @note = Note.new(db.get(params[:id]))
    @note.updated_at = DateTime.now
    if db.save(@note.update(params[:note]))
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

  private
  
  def db
    @@couchrest ||= CouchRest.new(COUCHDB_SERVER)
    # TODO Run creation tasks, load views, etc.
    @@couchrest.create_db("travel_topfunky") rescue nil
    @db = @@couchrest.database("travel_topfunky")
  end
  
end
