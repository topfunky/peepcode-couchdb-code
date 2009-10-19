class TagsController < ApplicationController

  def index
    # Both the map and the reduce will be run.
    @tags = Note.view(database_name, "notes/by_tag", :group => true)
  end

  def show
    @tag   = params[:id]
    # Specifying :reduce => false causes only the map to be run.
    @notes = Note.view(database_name, "notes/by_tag", :key => @tag, :reduce => false)
  end

end
