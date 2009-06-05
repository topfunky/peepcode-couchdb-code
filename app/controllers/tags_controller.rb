class TagsController < ApplicationController

  def index
    @tags = Note.by_tag :reduce => true, :group => true
  end

  def show
    @tag   = params[:id]
    @notes = Note.by_tag :key => @tag
  end

end
