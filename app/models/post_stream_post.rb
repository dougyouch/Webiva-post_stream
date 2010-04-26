
class PostStreamPost < DomainModel
  attr_accessor :folder_id, :name, :post_on_facebook, :additional_target

  has_end_user :end_user_id, :name_column => :name
  belongs_to :shared_content_node, :class_name => 'ContentNode', :foreign_key => 'shared_content_node_id'

  has_domain_file :domain_file_id

  # posted_by models must have a name and image field
  belongs_to :posted_by, :polymorphic => true
  has_many :post_stream_post_targets, :dependent => :delete_all
  has_many :post_stream_post_comments, :order => 'posted_at DESC', :dependent => :delete_all

  validates_presence_of :post_type
  has_options :post_type, [['Post', 'post'], ['Content','content'], ['Link','link'], ['Image', 'image'], ['Media', 'media']] 

  validates_presence_of :body
  validates_presence_of :posted_at

  serialize :data

  safe_content_filter(:body => :body_html)  do |post|
    { :filter => post.content_filter,
      :folder_id => post.folder_id
    }
  end

  content_node

  named_scope :with_types, lambda { |types| types.empty? ? {} : {:conditions => {:post_type => types}} }

  def identifier
    "#{self.id}-#{self.post_hash}"
  end

  def content_node_body(language)
    self.body
  end

#  def content_admin_url
#    { :controller => '/post_stream/manage', :action => 'post', :path => [ self.id ] }
#  end

  def post_on_facebook=(val)
    val = val == 'true' if val.is_a?(String)
    @post_on_facebook = val
  end

  def share_url(site_node)
    if self.shared_content_node
      "#{self.shared_content_node.node_path}/#{self.identifier}"
    else
      "#{site_node.node_path}/#{self.identifier}"
    end
  end

  def image
    @image ||= self.posted_by ? self.posted_by.image : Configuration.missing_image(nil)
  end

  def image=(image)
    @image = image
  end

  def posted_by_shared_content_node
    @shared_content_node ||= ContentNode.find_by_node_type_and_node_id(self.posted_by_type, self.posted_by_id)
  end

  def posted_by_shared_content_node=(node)
    @shared_content_node = node
  end

  def user_profile_entry
    nil
  end

  def self.find_by_identifier(identifier)
    return nil unless identifier
    post_id, post_hash = *identifier.split('-')
    PostStreamPost.find_by_id_and_post_hash(post_id, post_hash)
  end

  def validate
    case self.post_type
    when 'link'
      self.errors.add(:link, 'is required') if self.link.blank?
    when 'image'
      if self.link.blank? && self.handler.blank?
        self.errors.add(:domain_file_id, 'is required') if self.domain_file.nil?
        self.errors.add(:domain_file_id, 'is invalid') if self.domain_file && ! self.domain_file.image?
      end
    when 'media'
      self.errors.add(:domain_file_id, 'is required') if self.domain_file.nil? && self.link.blank? && self.handler.blank?
    when 'content'
      self.errors.add(:shared_content_node_id, 'is required') if self.shared_content_node.nil?
    end

    if self.handler_obj
      self.errors.add(:handler, 'is invalid') unless self.handler_obj.valid?
    end

    self.errors.add(:name, 'is missing') if self.end_user && self.end_user.missing_name? && self.name.blank?
  end

  def before_validation_on_create
    if self.post_type.nil?
      if self.shared_content_node
        self.post_type = 'content'
      elsif self.domain_file
        self.post_type = self.domain_file.image? ? 'image' : 'media'
      elsif self.link
        self.post_type = 'link'
      else
        self.post_type = 'post'
      end
    end

    self.posted_at ||= Time.now
  end

  def before_create
    self.post_hash ||= DomainModel.generate_hash[0..8]

    self.posted_by = self.user_profile_entry || self.end_user if self.posted_by.nil? && self.end_user

    self.title = self.posted_by ? self.posted_by.name : 'Anonymous'.t if self.title.blank?
    self.title = self.name if self.name && self.title == 'Anonymous'.t
  end

  def before_save
    self.data = self.handler_obj.options.to_h if self.handler_obj
  end

  def content_filter
    PostStream::AdminController.module_options.content_filter || 'comment'
  end

  def self.find_for_targets(targets, page=1, opts={})
    page = (page || 1).to_i
    limit = opts.delete(:limit) || 10
    offset = (page-1) * limit

    post_types = opts.delete(:post_types)
    if post_types && ! post_types.empty?
      scope = PostStreamPostTarget.with_types(post_types)
    else
      scope = PostStreamPostTarget
    end

    items = scope.with_target(targets).find(:all, {:select => 'DISTINCT post_stream_post_id', :limit => limit + 1, :offset => offset, :order => 'posted_at DESC'}.merge(opts))

    has_more = items.length > limit
    items.pop if has_more

    posts = PostStreamPost.find(:all, :conditions => {:id => items.collect { |item| item.post_stream_post_id }}, :order => 'posted_at DESC')
    [has_more, posts]
  end

  def handler_class
    @handler_class ||= self.handler.classify.constantize if self.handler
  end

  def handler_obj
    @handler_obj ||= self.handler_class.new(self) if self.handler_class
  end

  def update_comments_count
    self.post_stream_post_comments_count = self.post_stream_post_comments.count
    self.save
  end

  def comments
    @comments ||= []
  end

  def comments=(comments)
    @comments = comments
  end

  def preview_image_url
    if self.domain_file && self.domain_file.image?
      self.domain_file.full_url
    elsif self.handler_obj
      self.handler_obj.preview_image_url
    end
  end
end
