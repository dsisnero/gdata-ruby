require 'gdata/client'
require 'builder'
require 'hpricot'
require 'rexml/document'

module GData

  class Blogger < GData::Client
    attr_reader :blog_id, :entry_id, :blogs, :posts
    # Default initialization method.  The blog ID and the entry ID may 
    # or may not be known ahead of time.
    def initialize(username, password, blog_id=nil, entry_id=nil)
      super 'blogger', 'gdata-ruby', 'www.blogger.com'
      authenticate(username, password)
      @entry_id = entry_id unless entry_id==nil
      retrieve_blog_list unless blog_id != nil
    end
    
    # Pull down a list of the user's blogs.  This allows the use of muliple
    # blogs per user.  The @blogs Array will store the available blogs by
    # internal hash.
    # ex. @blogs[0] = {"Blog Name" => "blog_id(a string of numbers)"}
    # returns @blogs - an outer program can use this to set the blog id using
    # the set_blog_id method.
    def retrieve_blog_list
      # retrieve the user's list of blogs from 
      blog_feed = get('/feeds/default/blogs')
      @blogs = Array.new
      REXML::Document.new(blog_feed[1]).root.elements.each('entry') do |entry|
        @blogs.push(entry.elements['id'].get_text.to_s.split(/blog-/).last)
      end
      set_blog_id(@blogs[0]) # set the initial blog ID to the first blog.
      @blogs
    end

    # Sets the current blog_id to the specified blog - use the @blogs variable
    # to define the blog id!
    # ex: b.set_blog_id(b.blogs[1])
    def set_blog_id(blog)
      @blog_id = blog
      # Now we've changed blogs, but we also need to clear the entry id's and
      # Post list.
      @posts = nil
      @entry_id = nil
    end

    # Retrieves the post feed from the blog contained in @blog_id.  Run through
    # REXML, it returns an array of the different id's of that blog's posts.
    def get_post_feed
      post_feed = get "/feeds/#{@blog_id}/posts/default"
      @posts = Array.new
      REXML::Document.new(post_feed[1]).elements.each('feed/entry') do |entry|
        @posts.push(entry.elements['id'].get_text.to_s.split(/post-/).last)
      end
    end
    
    # Sets the post (entry) id to the one specified.  Retrieve from the @posts
    # variable.
    def set_post_id(post)
      @entry_id = post
    end

    def entry
      @entry ||= Hpricot(request("/feeds/#{@blog_id}/posts/default/#{@entry_id}"))
    end

    def enclosure
      entry.search('//link[@rel="enclosure"]')
    end

    def enclosure?
      enclosure.any?
    end
  
    def add_enclosure(enclosure_url, enclosure_length)
      raise "An enclosure has already been added to this entry" if enclosure?
      # todo(stevejenson): replace with builder
      entry.search('//entry').append(%Q{<link rel="enclosure" type="audio/mpeg" title="MP3" href="#{enclosure_url}" length="#{enclosure_length}" />})
      save_entry
    end

    def remove_enclosure
      if enclosure?
        enclosure.remove
        save_entry
      end
    end

    def save_entry
      path = "/feeds/#{@blog_id}/posts/default/#{@entry_id}"
  
      put(path, entry.to_s)
    end

    # Creates a new entry with the given title and body
    def entry(title, body)
      x = Builder::XmlMarkup.new :indent => 2
      x.entry 'xmlns' => 'http://www.w3.org/2005/Atom' do
        x.title title, 'type' => 'text'
        x.content 'type' => 'xhtml' do
          x.div body, 'xmlns' => 'http://www.w3.org/1999/xhtml'
        end
      end
      
      @entry ||= x.target!
      path = "/feeds/#{@blog_id}/posts/default"
      post(path, @entry)
    end

  end

end
