require 'gdata/client'
require 'builder'
require 'hpricot'
require 'rexml/document'

module GData

  class Blogger < GData::Client
    attr_reader :blog_id, :entry_id, :user_id, :blogs
    attr_writer :blog_id, :entry_id
    # Default initialization method.  The blog ID and the entry ID may 
    # or may not be known ahead of time.
    def initialize(blog_id=nil, entry_id=nil)
      @blog_id = blog_id
      @entry_id = entry_id
      super 'blogger', 'gdata-ruby', 'www.blogger.com'
    end
    
    # Pull down a list of the user's blogs.  This allows the use of muliple blogs
    # per user.  The @blogs Array will store the available blogs by internal hash.
    # 
    def retrieve_blog_list
      # retrieve the user's list of blogs from 
      blog_feed = get('/feeds/default/blogs')
      @blog_list = REXML::Document.new(blog_feed[1]).root
      @blogs = Array.new
      @blog_list.elements.each('entry'){|entry| @blogs.push({entry.elements['title'].get_text.to_s => entry.elements['id'].get_text.to_s.split(/blog-/).last})}
      # By default, set the first blog to @blog_id
      @blog_id = @blogs[0].values.to_s
      @blogs
    end
    # retrieves the user$ ID from the blog_list feed.
    def get_user_id
      # Because someone might call this method without the blog_list called,
      # we wouldn't have data to pull from.  So let's call that method.
      self.blog_list
      uid = @blog_list.elements['id'].get_text.to_s.split(/-|\:/)
      @user_id = uid[uid.index("user")+1].delete(".blogs") 
    end
    
    def feed
      request "/feeds/#{@blog_id}/posts/default"
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
