# frozen_string_literal: true

module TaxonomyTestHelper
  def create_test_taxonomies
    return unless defined?(Taxonomy)
    
    # Create base taxonomies
    education = Taxonomy.find_or_create_by!(slug: "education") do |t|
      t.label = "Education"
    end
    
    three_d = Taxonomy.find_or_create_by!(slug: "3d") do |t|
      t.label = "3D"
    end
    
    other = Taxonomy.find_or_create_by!(slug: "other") do |t|
      t.label = "Other"
    end
    
    # Create child taxonomies
    Taxonomy.find_or_create_by!(slug: "math") do |t|
      t.label = "Math"
      t.parent = education
    end
    
    Taxonomy.find_or_create_by!(slug: "history") do |t|
      t.label = "History"
      t.parent = education
    end
    
    Taxonomy.find_or_create_by!(slug: "3d-assets") do |t|
      t.label = "3D Assets"
      t.parent = three_d
    end
  end
end

RSpec.configure do |config|
  config.include TaxonomyTestHelper
  
  config.before(:each, type: :presenter) do
    if described_class.name&.include?("TaxonomyPresenter")
      create_test_taxonomies
    end
  end
end