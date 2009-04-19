class Card < CouchRest::ExtendedDocument  
  # Include the validation module to get access to the validation methods
  include CouchRest::Validation
  # set the auto_validation before defining the properties
  auto_validate!
  
  # Set the default database to use
  use_database TEST_SERVER.default_database
  
  # Official Schema
  property :first_name
  property :last_name,        :alias     => :family_name
  property :read_only_value,  :read_only => true
  
  timestamps!
  
  # Validation
  validates_present :first_name
  
end