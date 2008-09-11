class Note < BasicModel

  def initialize(attributes={})
    defaults = {"title" => nil, "description" => nil, "tags" => []}
    super(defaults.merge(attributes))
  end

  ##
  # Coerce things into the proper types of objects.
  
  def on_update
    if (tags = @attributes['tags']) && tags.is_a?(String)
      @attributes['tags'] = tags.split(" ")
    end
  end

end
