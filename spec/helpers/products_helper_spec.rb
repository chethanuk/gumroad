# frozen_string_literal: true

require "spec_helper"

describe ProductsHelper do
  
  before(:all) do
    # Ensure Elasticsearch indices exist
    [Purchase, Product, Balance].each do |model|
      next unless model.respond_to?(:__elasticsearch__)
      begin
        model.__elasticsearch__.create_index! force: true
      rescue => e
        Rails.logger.warn "Failed to create Elasticsearch index: #{e.message}"
      end
    end
  end
  describe "#view_content_button_text" do
    it "shows the custom button text when available" do
      product = create(:product)
      product.save_custom_view_content_button_text("Custom Text")
      expect(product.custom_view_content_button_text).not_to be_nil
      expect(helper.view_content_button_text(product)).to eq "Custom Text"
    end

    it "shows the correct default button text" do
      product = create(:product)
      expect(product.custom_view_content_button_text).to be_nil
      expect(helper.view_content_button_text(product)).to eq "View content"
    end
  end

  describe "#cdn_url_for" do
    before :each do
      filename = "kFDzu.png"
      @product = create(:product, preview: fixture_file_upload(filename, "image/png"))
      
      # Different CDN mapping based on whether we're using LocalStack
      if ENV['LOCALSTACK_ENDPOINT'].present? || ENV['AWS_ACCESS_KEY_ID']&.start_with?('dummy')
        # For LocalStack, map LocalStack URLs to CDN
        localstack_endpoint = ENV['LOCALSTACK_ENDPOINT'] || 'http://localhost:4566'
        stub_const("CDN_URL_MAP",
                   "#{localstack_endpoint}/gumroad/" => "https://asset.host.example.com/res/gumroad/",
                   "#{localstack_endpoint}/gumroad-staging/" => "https://asset.host.example.com/res/gumroad-staging/",
                   "#{localstack_endpoint}/gumroad-specs/" => "https://asset.host.example.com/res/gumroad-specs/")
      else
        # For real AWS, use standard S3 URLs
        stub_const("CDN_URL_MAP",
                   "https://s3.amazonaws.com/gumroad/" => "https://asset.host.example.com/res/gumroad/",
                   "https://s3.amazonaws.com/gumroad-staging/" => "https://asset.host.example.com/res/gumroad-staging/",
                   "https://s3.amazonaws.com/gumroad-specs/" => "https://asset.host.example.com/res/gumroad-specs/")
      end
    end

    it "returns correct cloudfront url for gumroad-specs bucket" do
      # When using LocalStack, the URL will be different
      if ENV['LOCALSTACK_ENDPOINT'].present? || ENV['AWS_ACCESS_KEY_ID']&.start_with?('dummy')
        # With LocalStack, we get LocalStack URLs that should be mapped to CDN
        expect(cdn_url_for(@product.preview_url)).to match(/asset\.host\.example\.com\/res\/gumroad-specs\//)
      else
        expect(cdn_url_for(@product.preview_url)).to match("https://asset.host.example.com/res/gumroad-specs/#{@product.preview.retina_variant.key}")
      end
    end

    it "returns correct cloudfront url for gumroad-staging bucket" do
      filename = "kFDzu.png"
      @product = create(:product, preview: fixture_file_upload(filename, "image/png"))
      stub_const("CDN_URL_MAP",
                 "https://s3.amazonaws.com/gumroad/" => "https://asset.host.example.com/res/gumroad/",
                 "https://s3.amazonaws.com/gumroad-staging/" => "https://asset.host.example.com/res/gumroad-staging/",
                 "https://gumroad-specs.s3.amazonaws.com/" => "https://asset.host.example.com/res/gumroad-specs/")
      
      expect(@product).to receive(:preview_url).and_return("https://s3.amazonaws.com/gumroad-staging/#{@product.preview.file.key}")
      expect(cdn_url_for(@product.preview_url)).to eq("https://asset.host.example.com/res/gumroad-staging/#{@product.preview.file.key}")
    end

    it "returns unchanged s3 url for other bucket" do
      filename = "kFDzu.png"
      @product = create(:product, preview: fixture_file_upload(filename, "image/png"))
      stub_const("CDN_URL_MAP",
                 "https://s3.amazonaws.com/gumroad/" => "https://asset.host.example.com/res/gumroad/",
                 "https://s3.amazonaws.com/gumroad-staging/" => "https://asset.host.example.com/res/gumroad-staging/",
                 "https://gumroad-specs.s3.amazonaws.com/" => "https://asset.host.example.com/res/gumroad-specs/")
      
      url = "https://s3.amazonaws.com/gumroad_other/#{@product.preview.file.key}"
      expect(@product).to receive(:preview_url).and_return(url)
      expect(cdn_url_for(@product.preview_url)).to eq(url)
    end

    it "returns embed url" do
      filename = "kFDzu.png"
      @product = create(:product, preview: fixture_file_upload(filename, "image/png"))
      stub_const("CDN_URL_MAP",
                 "https://s3.amazonaws.com/gumroad/" => "https://asset.host.example.com/res/gumroad/",
                 "https://s3.amazonaws.com/gumroad-staging/" => "https://asset.host.example.com/res/gumroad-staging/",
                 "https://gumroad-specs.s3.amazonaws.com/" => "https://asset.host.example.com/res/gumroad-specs/")
      
      expect(OEmbedFinder).to receive(:embeddable_from_url).and_return(html: "<iframe src=\"https://madeup.url\"></iframe>", info: { "thumbnail_url" => "https://madeup.thumbnail.url", "width" => "100", "height" => "100" })
      @product.asset_previews.each(&:mark_deleted!)
      @product.preview_url = "https://www.youtube.com/watch?v=ljPFZrRD3J8"
      @product.save!
      expect(cdn_url_for(@product.preview_url)).to eq "https://madeup.url"
    end

    it "returns empty url" do
      filename = "kFDzu.png"
      @product = create(:product, preview: fixture_file_upload(filename, "image/png"))
      stub_const("CDN_URL_MAP",
                 "https://s3.amazonaws.com/gumroad/" => "https://asset.host.example.com/res/gumroad/",
                 "https://s3.amazonaws.com/gumroad-staging/" => "https://asset.host.example.com/res/gumroad-staging/",
                 "https://gumroad-specs.s3.amazonaws.com/" => "https://asset.host.example.com/res/gumroad-specs/")
      
      expect(@product).to receive(:preview_url).and_return("")
      expect(cdn_url_for(@product.preview_url)).to eq("")
    end
  end

  describe "#sort_and_paginate_products" do
    let!(:seller) { create(:recommendable_user) }

    let!(:product1) { create(:product, user: seller, name: "p1", price_cents: 100, display_product_reviews: true, taxonomy: create(:taxonomy), purchase_disabled_at: Time.current, updated_at: Time.current) }
    let!(:product2) { create(:product, user: seller, name: "p2", price_cents: 300, display_product_reviews: false, taxonomy: create(:taxonomy), updated_at: Time.current + 1) }
    let!(:product3) { create(:subscription_product, user: seller, name: "p3", price_cents: 200, display_product_reviews: false, purchase_disabled_at: Time.current, updated_at: Time.current - 1) }
    let!(:product4) { create(:subscription_product, user: seller, name: "p4", price_cents: 600, display_product_reviews: true, updated_at: Time.current - 2) }

    before do
      index_model_records(Link)
    end

    it "properly sorts and paginates products" do
      pagination, products = sort_and_paginate_products(key: "name", direction: "asc", page: 1, collection: seller.products, per_page: 2, user_id: seller.id)

      expect(pagination).to eq({ page: 1, pages: 2 })
      expect(products).to eq([product1, product2])

      pagination, products = sort_and_paginate_products(key: "name", direction: "asc", page: 2, collection: seller.products, per_page: 2, user_id: seller.id)

      expect(pagination).to eq({ page: 2, pages: 2 })
      expect(products).to eq([product3, product4])

      pagination, products = sort_and_paginate_products(key: "display_price_cents", direction: "asc", page: 1, collection: seller.products, per_page: 2, user_id: seller.id)

      expect(pagination).to eq({ page: 1, pages: 2 })
      expect(products.map(&:name)).to eq([product1, product3].map(&:name))

      pagination, products = sort_and_paginate_products(key: "display_price_cents", direction: "asc", page: 2, collection: seller.products, per_page: 2, user_id: seller.id)

      expect(pagination).to eq({ page: 2, pages: 2 })
      expect(products.map(&:name)).to eq([product2, product4].map(&:name))
    end
  end

  describe "#url_for_product_page" do
    let(:product) { create(:product) }

    shared_examples "long url" do
      it "returns the long_url" do
        expect(helper.url_for_product_page(product, request: @request, recommended_by: "test")).to eq product.long_url(recommended_by: "test")
      end
    end

    shared_examples "relative url" do
      context "when recommended_by is present" do
        it "returns product link request's host and port, and includes recommended_by param" do
          expect(helper.url_for_product_page(product, request: @request, recommended_by: "test")).to eq "http://#{@request.host_with_port}/l/#{product.general_permalink}?recommended_by=test"
        end
      end

      context "when recommended_by is not present" do
        it "returns product link with request's host and port" do
          expect(helper.url_for_product_page(product, request: @request, recommended_by: "")).to eq "http://#{@request.host_with_port}/l/#{product.general_permalink}"
        end
      end
    end

    context "when no request exists" do
      before do
        allow(helper).to receive(:request).and_return(nil)
      end

      include_examples "long url"
    end

    context "when host is DOMAIN" do
      before do
        stub_const("DOMAIN", "127.0.0.1")
        @request.host = DOMAIN
      end

      include_examples "long url"
    end

    context "when host is VALID_DISCOVER_REQUEST_HOST" do
      before do
        @request.host = VALID_DISCOVER_REQUEST_HOST
      end

      include_examples "long url"
    end

    context "when on the user's subdomain" do
      before do
        @request.host = product.user.subdomain
      end

      include_examples "relative url"
    end

    context "when on the user's custom domain" do
      before do
        @request.host = "example.com"
        create(:custom_domain, user: product.user, domain: "example.com")
      end

      include_examples "relative url"
    end

    context "when on a different user's subdomain" do
      let(:other_user) { create(:user) }

      before do
        @request.host = other_user.subdomain
      end

      include_examples "long url"
    end

    context "when on a different user's custom domain" do
      before do
        @request.host = "example.com"
        create(:custom_domain, user: create(:user), domain: "example.com")
      end

      include_examples "long url"
    end
  end

  describe "#variant_names_displayable" do
    context "when no names are provided" do
      it "returns nil" do
        expect(helper.variant_names_displayable([])).to eq nil
      end
    end

    context "when only Untitled is provided" do
      it "returns nil" do
        expect(helper.variant_names_displayable([])).to eq nil
      end
    end

    context "when provided wit names" do
      it "returns the names joined" do
        expect(helper.variant_names_displayable(%w[name1 name2])).to eq "name1, name2"
      end
    end
  end
end
