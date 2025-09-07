# frozen_string_literal: true

require "spec_helper"

RSpec.describe DiscoverSearch do
  # Removed DummyCredentialHelper conditional skip

  it "can be created" do
    create(:discover_search)
  end
end
