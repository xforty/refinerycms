require 'spec_helper'

module Refinery
  describe Page do

    let(:page) {
      ::Refinery::Page.create!(:title => 'RSpec is great for testing too', :deletable => true)
    }
    let(:child) { page.children.create(:title => 'The child page') }

    def page_cannot_be_destroyed
      page.destroy.should == false
    end

    def turn_off_marketable_urls
      ::Refinery::Pages.stub(:use_marketable_urls?).and_return(false)
    end

    def turn_on_marketable_urls
      ::Refinery::Pages.stub(:use_marketable_urls?).and_return(true)
    end

    context 'cannot be deleted under certain rules' do
      it 'if link_url is present' do
        page.link_url = '/plugin-name'
        page_cannot_be_destroyed
      end

      it 'if refinery team deems it so' do
        page.deletable = false
        page_cannot_be_destroyed
      end

      it 'if menu_match is present' do
        page.menu_match = '^/RSpec is great for testing too.*$'
        page_cannot_be_destroyed
      end

      it 'unless you really want it to! >:]' do
        page.destroy.should be
      end
    end

    context 'page urls' do
      it 'return a full path' do
        page.path.should == 'RSpec is great for testing too'
      end

      it 'and all of its parent page titles, reversed' do
        child.path.should == 'RSpec is great for testing too - The child page'
      end

      it 'or normally ;-)' do
        child.path(:reversed => false).should == 'The child page - RSpec is great for testing too'
      end

      it 'returns its url' do
        page.link_url = '/contact'
        page.url.should == '/contact'
      end

      it 'returns its path with marketable urls' do
        page.url[:id].should be_nil
        page.url[:path].should == ['rspec-is-great-for-testing-too']
      end

      it 'returns its path underneath its parent with marketable urls' do
        child.url[:id].should be_nil
        child.url[:path].should == [page.url[:path].first, 'the-child-page']
      end

      it 'no path parameter without marketable urls' do
        turn_off_marketable_urls
        page.url[:path].should be_nil
        page.url[:id].should == 'rspec-is-great-for-testing-too'
        turn_on_marketable_urls
      end

      it "doesn't mention its parent without marketable urls" do
        turn_off_marketable_urls
        child.url[:id].should == 'the-child-page'
        child.url[:path].should be_nil
        turn_on_marketable_urls
      end

      it 'returns its path with slug set by menu_title' do
        page.menu_title = 'Rspec is great'
        page.save
        page.reload

        page.url[:id].should be_nil
        page.url[:path].should == ['rspec-is-great']
      end
    end

    context 'custom slugs' do
      let(:page_with_custom_slug) {
        ::Refinery::Page.create!(:title => 'RSpec is great for testing too', :custom_slug => 'custom-page-slug')
      }
      let(:child_with_custom_slug) { page.children.create(:title => 'The child page', :custom_slug => 'custom-child-slug') }

      it 'returns its path with custom slug' do
        page_with_custom_slug.url[:id].should be_nil
        page_with_custom_slug.url[:path].should == ['custom-page-slug']
      end

      it 'returns its path underneath its parent with custom urls' do
        child_with_custom_slug.url[:id].should be_nil
        child_with_custom_slug.url[:path].should == [page.url[:path].first, 'custom-child-slug']
      end

      it 'returns its path with custom slug when using different locale' do
        ::Refinery::I18n.current_frontend_locale = :ru
        ::Refinery::I18n.current_locale = :ru
        page_with_custom_slug.custom_slug = 'custom-page-slug-ru'
        page_with_custom_slug.save
        page_with_custom_slug.reload

        page_with_custom_slug.url[:id].should be_nil
        page_with_custom_slug.url[:path].should == ['custom-page-slug-ru']
      end

      it 'returns path underneath its parent with custom urls when using different locale' do
        ::Refinery::I18n.current_frontend_locale = :ru
        ::Refinery::I18n.current_locale = :ru
        child_with_custom_slug.custom_slug = 'custom-child-slug-ru'
        child_with_custom_slug.save
        child_with_custom_slug.reload

        child_with_custom_slug.url[:id].should be_nil
        child_with_custom_slug.url[:path].should == [page.url[:path].first, 'custom-child-slug-ru']
      end

    end

    context 'home page' do
      it 'responds as the home page' do
        page.link_url = '/'
        page.home?.should == true
      end

      it 'responds as a normal page when not set to home page' do
        page.home?.should == false
      end
    end

    context 'content sections (page parts)' do
      before do
        page.parts.create(:title => 'body', :content => "I'm the first page part for this page.")
        page.parts.create(:title => 'side body', :content => 'Closely followed by the second page part.')
        page.parts.reload
      end

      it 'return the content when using content_for' do
        page.content_for(:body).should == "<p>I'm the first page part for this page.</p>"
        page.content_for('BoDY').should == "<p>I'm the first page part for this page.</p>"
      end

      it 'return all page part content' do
        page.all_page_part_content.should == "<p>I'm the first page part for this page.</p> <p>Closely followed by the second page part.</p>"
      end

      it 'reposition correctly' do
        page.parts.first.update_attribute(:position, 6)
        page.parts.last.update_attribute(:position, 4)

        page.parts.first.position.should == 6
        page.parts.last.position.should == 4

        page.reposition_parts!

        page.parts.first.position.should == 0
        page.parts.last.position.should == 1
      end
    end

    context 'draft pages' do
      it 'not live when set to draft' do
        page.draft = true
        page.live?.should_not be
      end

      it 'live when not set to draft' do
        page.draft = false
        page.live?.should be
      end
    end

    context "should add url suffix" do
      let(:reserved_word) { ::Refinery::Page.friendly_id_config.reserved_words.last }
      let(:page_with_reserved_title) {
        ::Refinery::Page.create!(:title => reserved_word, :deletable => true)
      }
      let(:child_with_reserved_title_parent) {
        page_with_reserved_title.children.create(:title => 'reserved title child page')
      }

      before { turn_on_marketable_urls }

      it 'when title is set to a reserved word' do
        page_with_reserved_title.url[:path].should == ["#{reserved_word}-page"]
      end

      it "when parent page title is set to a reserved word" do
        child_with_reserved_title_parent.url[:path].should == ["#{reserved_word}-page", 'reserved-title-child-page']
      end
    end

    context 'meta data' do
      context 'responds to' do
        it 'meta_keywords' do
          page.respond_to?(:meta_keywords)
        end

        it 'meta_description' do
          page.respond_to?(:meta_description)
        end

        it 'browser_title' do
          page.respond_to?(:browser_title)
        end
      end

      context 'allows us to assign to' do
        it 'meta_keywords' do
          page.meta_keywords = 'Some, great, keywords'
          page.meta_keywords.should == 'Some, great, keywords'
        end

        it 'meta_description' do
          page.meta_description = 'This is my description of the page for search results.'
          page.meta_description.should == 'This is my description of the page for search results.'
        end

        it 'browser_title' do
          page.browser_title = 'An awesome browser title for SEO'
          page.browser_title.should == 'An awesome browser title for SEO'
        end
      end

      context 'allows us to update' do
        it 'meta_keywords' do
          page.meta_keywords = 'Some, great, keywords'
          page.save

          page.reload
          page.meta_keywords.should == 'Some, great, keywords'
        end

        it 'meta_description' do
          page.meta_description = 'This is my description of the page for search results.'
          page.save

          page.reload
          page.meta_description.should == 'This is my description of the page for search results.'
        end

        it 'browser_title' do
          page.browser_title = 'An awesome browser title for SEO'
          page.save

          page.reload
          page.browser_title.should == 'An awesome browser title for SEO'
        end
      end

    end

  end
end
