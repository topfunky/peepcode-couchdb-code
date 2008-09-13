class Note < BasicModel

  def default_attributes
    {
      "title" => nil,
      "description" => nil,
      "tags" => [],
      "visited_on" => Time.now.strftime('%Y/%m/%d')
    }
  end

  ##
  # Coerce things into the proper types of objects.

  def on_update
    if (tags = @attributes['tags']) && tags.is_a?(String)
      @attributes['tags'] = tags.split(" ")
    end
  end

end
