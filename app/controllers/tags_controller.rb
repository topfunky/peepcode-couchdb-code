class TagsController < ApplicationController

  def index
    @tags = Note.view(database_name, "notes/by_tag-reduce", :group => true)
  end

  def show
    @tag   = params[:id]
    @notes = Note.view(database_name, "notes/by_tag-map", :key => @tag)
  end

end
