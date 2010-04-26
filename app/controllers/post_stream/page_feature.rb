
class PostStream::PageFeature < ParagraphFeature

  include StyledFormBuilderGenerator::FormFor
  include ActionView::Helpers::DateHelper

  feature :post_stream_page_stream,
    :default_css_file => '/components/post_stream/stylesheets/stream.css',
    :default_feature => <<-FEATURE
  <div class="post_stream_form">
    <cms:form>
      <cms:errors prefix="* "><div class="errors"><cms:value/></div></cms:errors>
      <cms:no_name>
        <cms:name/>
      </cms:no_name>
      <cms:body/>
      <cms:handlers close='[X]'/>
      <div class="controls">
        <cms:share>
          <cms:buttons label="Share:"/>
        </cms:share>
  
        <cms:share_with>
          <cms:targets/>
          <cms:facebook/>
        </cms:share_with>
  
        <div class="post_stream_submit">
          <cms:submit/>
        </div>
      </div>
      <hr class="seperator"/>
    </cms:form>
  </div>

  <cms:stream/>
  FEATURE

  def post_stream_page_stream_feature(data)
    webiva_feature(:post_stream_page_stream,data) do |c|
      formClass = data[:poster].was_submitted? ? 'post_stream_active' : 'post_stream_inactive'
      c.form_for_tag('form','stream_post', :html => {:multipart => true, :id => 'stream_post_form', :class => formClass, :onsubmit => "PostStreamForm.onsubmit('#{self.ajax_url}', 'stream_post_form'); return false;"}) { |t| t.locals.stream_post = data[:poster].post if data[:poster].can_post? }

      c.value_tag('form:errors') do |t|
        errors = []
        
        errors << t.locals.stream_post.errors[:base] if t.locals.stream_post.errors[:base]

        errors << "Body #{t.locals.stream_post.errors[:body]}" if t.locals.stream_post.errors[:body]

        prefix = t.attr['prefix'] || ''
        postfix = t.attr['postfix'] || ''
        spacer = t.attr['spacer'] || '<br/>'
        errors.empty? ? nil : prefix + errors.join("#{postfix}#{spacer}#{prefix}") + postfix
      end

      c.expansion_tag('form:no_name') { |t| myself.missing_name? }
      c.define_tag('form:name') do |t|
        '<div class="name">' + 'Name:'.t + ' ' + t.locals.form.text_field(:name, t.attr) + '</div>'
      end

      c.define_tag('form:body') do |t|
        '<div class="body">' + t.locals.form.text_area(:body, {:onfocus => 'PostStreamForm.bodyOnFocus();'}.merge(t.attr)) + '</div>'
      end

      c.define_tag('form:handlers') do |t|
        t.locals.share_components_close = t.attr['close'] || '[X]'
        t.locals.share_components_close_image = t.attr['close_image']

        output = t.locals.form.hidden_field :handler
        output << '<div class="stream_post_handlers">'
        output << (t.single? ? self.render_handler_forms(t, data) : t.expand)
        output << '</div>'
      end

      c.define_tag('form:handlers:handler') do |t|
        title = t.single? ? t.attr['title'] : t.expand
        handler = data[:poster].get_handler_by_type(t.attr['type'])
        self.render_handler_form(handler, t, data, {'title' => title, 'close' => t.locals.share_components_close, 'close_image' => t.locals.share_components_close_image}.merge(t.attr))
      end

      c.define_tag('form:share') do |t|
        '<div id="post_stream_share" class="post_stream_share">' + t.expand + '&nbsp;</div>'
      end

      c.define_tag('form:share:buttons') do |t|
        style = data[:poster].post.handler ? "style='display:none;'" : ''
        output = "<ul id='post_stream_share_buttons' class='post_stream_share_buttons' #{style}>"
        output << "<li class='label'>#{t.attr['label']}</li>" unless t.attr['label'].blank?

        if t.single?
          output << ("<li class='button'>" + data[:poster].handlers.collect{ |handler| handler.render_button }.join("</li><li class='button'>") + "</li>")
        else
          output << t.expand
        end
        output << '</ul>'
      end

      c.define_tag('form:share:buttons:button') do |t|
        title = t.attr['title'] || t.expand
        handler = data[:poster].get_handler_by_type(t.attr['type'])
        handler ? '<li class="button">' + handler.render_button('title' => title) + '</li>' : ''
      end

      c.define_tag('form:share_with') do |t|
        '<div class="post_stream_share_with">' + t.expand + '</div>'
      end

      c.define_tag('form:share_with:facebook') do |t|
        if data[:options].post_on_facebook
          content = t.single? ? 'Post to facebook' : t.expand
          '<div class="facebook">' + t.locals.form.check_boxes(:post_on_facebook, [[content, true]], :single => true) + '</div>'
        end
      end

      c.define_tag('form:share_with:targets') do |t|
        unless data[:poster].additional_targets.empty?
          content = data[:poster].additional_targets.length == 1 ? t.locals.form.check_boxes(:additional_target, data[:poster].additional_target_options, :single => true) : t.locals.form.select(:additional_target, [['--Select an addiontal stream--'.t, nil]] + data[:poster].additional_target_options)
          '<div class="targets">' + content + '</div>'
        end
      end

      c.submit_tag('form:submit', :default => 'Post')

      c.define_tag('stream') { |t| render_to_string :partial => '/post_stream/page/stream', :locals => data[:poster].get_locals.merge(:attributes => t.attr) }
    end
  end

  def render_handler_forms(t, data)
    data[:poster].handlers.collect { |handler| self.render_handler_form(handler, t, data, t.attr) }.join("\n")
  end

  def render_handler_form(handler, t, data, opts={})
    cms_unstyled_fields_for(handler.form_name, handler.options) do |f|
      handler.render_form(self.renderer, f, opts)
    end
  end

  feature :post_stream_page_recent_posts,
    :default_css_file => '/components/post_stream/stylesheets/stream.css',
    :default_feature => <<-FEATURE
  <cms:posts>
    <div class="post_stream_posts">
      <cms:post>
        <div class="post_stream_post">
          <div class="post">
            <cms:photo size="thumb"/>
            <span class="title_body">
              <span class="title"><cms:post_link><cms:title/></cms:post_link></span>
              <span class="body"><cms:body/></span>
            </span>
          </div>
          <span class="actions">
            <span class="posted_at"><cms:posted_ago/> ago</span>
          </span>
          <div class="shared_content">
            <cms:embeded/>
          </div>
        <hr class="separator"/>
        </div>
      </cms:post>
    </div>
  </cms:posts>
  FEATURE

  def post_stream_page_recent_posts_feature(data)
    webiva_feature(:post_stream_page_recent_posts,data) do |c|
      c.loop_tag('post') { |t| data[:posts] }
      c.image_tag('post:photo') { |t| t.locals.post.image }
      c.link_tag('post:post') { |t| t.locals.post.content_node.link }
      c.link_tag('post:posted_by') { |t| t.locals.post.posted_by_shared_content_node.link if t.locals.post.posted_by_shared_content_node }
      c.link_tag('post:content') { |t| t.locals.post.shared_content_node.link if t.locals.post.shared_content_node }
      c.h_tag('post:title') { |t| t.locals.post.title }
      c.value_tag('post:body') { |t| t.locals.post.body_html }
      c.date_tag('post:posted_at',DEFAULT_DATETIME_FORMAT.t) { |t| t.locals.post.posted_at }
      c.value_tag('post:posted_ago') { |t| time_ago_in_words(t.locals.post.posted_at) }
      c.value_tag('post:embeded') { |t| t.locals.post.handler_obj.render(self.renderer, data[:poster].options) if t.locals.post.handler_obj }
    end
  end

  feature :post_stream_page_post,
    :default_css_file => '/components/post_stream/stylesheets/stream.css',
    :default_feature => <<-FEATURE
  <cms:stream/>
  FEATURE

  def post_stream_page_post_feature(data)
    webiva_feature(:post_stream_page_post,data) do |c|
      c.define_tag('stream') { |t| render_to_string :partial => '/post_stream/page/stream', :locals => data[:poster].get_locals.merge(:attributes => t.attr) }
    end
  end
end
