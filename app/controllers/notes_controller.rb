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
    note = Note.new
    result = db.save(note.update(params[:note]))
    respond_to do |wants|
      wants.html { redirect_to note_url(result["id"]) }
    end
  end

  def edit
    @note = Note.new(db.get(params[:id]))
  end

  def update
    @note = Note.new(db.get(params[:id]))
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
    db_name = ["travel", "topfunky", Rails.env].join("_")
    @@couchrest.create_db(db_name) rescue nil
    @db = @@couchrest.database(db_name)
  end
  
end
