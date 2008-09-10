class Note < BasicModel

  def initialize(attributes={})
    defaults = {"title" => nil, "description" => nil}
    super(defaults.merge(attributes))
  end

end
