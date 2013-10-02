require 'orm_asciidoctor/backends/_stylesheets'

module Asciidoctor

  class BaseTemplate
    def stratt(node, name, key)
      node.attr?("#{key}") ? %( #{name}="#{node.attr("#{key}")}") : nil
    end
  end

module HTMLBook

class DocumentTemplate < BaseTemplate
  def self.outline(node, to_depth = 2)
    toc_level_buffer = []
    sections = node.sections
    unless sections.empty?
      # FIXME the level for special sections should be set correctly in the model
      # sec_level will only be 0 if we have a book doctype with parts
      sec_level = sections.first.level
      if sec_level == 0 && sections.first.special
        sec_level = 1
      end
      toc_level_buffer << %(<ul class="sectlevel#{sec_level}">)
      sections.each do |section|
        section_num = section.numbered ? %(#{section.sectnum} ) : nil
        toc_level_buffer << %(<li><a href=\"##{section.id}\">#{section_num}#{section.captioned_title}</a></li>)
        if section.level < to_depth && (child_toc_level = outline(section, to_depth)) != ''
          toc_level_buffer << '<li>'
          toc_level_buffer << child_toc_level
          toc_level_buffer << '</li>'
        end
      end
      toc_level_buffer << '</ul>'
    end
    toc_level_buffer * EOL
  end

  def result(node)
    idatt = node.id ? %( id="#{node.id}") : nil
    author_copyright = node.attr?(:author) ? %(<h2 data-type="author">#{node.attr(:author)}</h2>) : nil
    author_dedication = node.attr?(:author) ? %(<p data-type="author">by #{node.attr(:author)}</p>) : nil
    
    doc = %(<!DOCTYPE html>
  <html xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:schemaLocation="http://www.w3.org/1999/xhtml ../schema/htmlbook.xsd"
xmlns="http://www.w3.org/1999/xhtml">

  <head>
    <title>#{node.doctitle}</title>
    <meta name="#{node.doctitle}" content="text/html; charset=utf-8"/>
  </head>
  <body#{idatt} data-type="book">
    <h1>#{node.header.title}</h1>
    <figure data-type="cover">
      <img src="cover.png"/>
    </figure>
    <section data-type="titlepage">
      <h1>#{node.header.title}</h1>
      #{author_copyright}
    </section>  
    <section data-type="copyright-page">
      <h1>#{node.header.title}</h1>
      #{author_dedication}
    </section>)

  if node.level == 1 && node.role == 'dedication'
    doc += %(<section data-type="dedication">
  <h#{node.level}>#{node.title}</h#{node.level}>
</section>)
  end

  doc += node.content
  doc += %(</body>
</html>)
  doc
  end

  def template
    :invoke_result
  end
end

class EmbeddedTemplate < BaseTemplate
  def result(node)
    result_buffer = []
    if !node.notitle && node.has_header?
      id_attr = node.id ? %( id="#{node.id}") : nil
      result_buffer << %(<h1#{id_attr}>#{node.header.title}</h1>)
    end

    result_buffer << node.content

    if node.footnotes? && !(node.attr? 'nofootnotes')
      result_buffer << '<div id="footnotes">'
      result_buffer << '<hr>'
      node.footnotes.each do |footnote|
        result_buffer << %(<div class="footnote" id="_footnote_#{footnote.index}">
<a href="#_footnoteref_#{footnote.index}">#{footnote.index}</a> #{footnote.text}
</div>)
      end

      result_buffer << '</div>'
    end

    result_buffer * EOL
  end

  def template
    :invoke_result
  end
end

class BlockTocTemplate < BaseTemplate
  def result(node)
    doc = node.document

    return '' unless (doc.attr? 'toc')

    if node.id
      id_attr = %( id="#{node.id}")
      title_id_attr = ''
    elsif doc.embedded? || !(doc.attr? 'toc-placement')
      id_attr = ' id="toc"'
      title_id_attr = ' id="toctitle"'
    else
      id_attr = ''
      title_id_attr = ''
    end
    title = node.title? ? node.title : (doc.attr 'toc-title')
    levels = (node.attr? 'levels') ? (node.attr 'levels').to_i : (doc.attr 'toclevels', 2).to_i
    role = node.role? ? node.role : (doc.attr 'toc-class', 'toc')

    %(<div#{id_attr} class="#{role}">
<div#{title_id_attr} class="title">#{title}</div>
#{DocumentTemplate.outline(doc, levels)}
</div>\n)
  end

  def template
    :invoke_result
  end
end

class BlockPreambleTemplate < BaseTemplate
  def toc(node)
    if (node.attr? 'toc') && (node.attr? 'toc-placement', 'preamble')
      %(\n<div id="toc" class="#{node.attr 'toc-class', 'toc'}">
<div id="toctitle">#{node.attr 'toc-title'}</div>
#{DocumentTemplate.outline(node.document, (node.attr 'toclevels', 2).to_i)}
</div>)
    else
      ''
    end
  end

  def result(node)
    %(<div id="preamble">
<div class="sectionbody">
#{node.content}
</div>#{toc node}
</div>)
  end

  def template
    :invoke_result
  end
end

class SectionTemplate < BaseTemplate
  
  def result(sec)
    idatt = sec.id ? %( id="#{sec.id}") : nil

    # stuff before tag
    if sec.level > 0
      title_html = %(#{sec.caption}#{sec.title})
      title_html = %(<a name="#{sec.id}" class="anchor" href="#{sec.id}">#{title_html}</a>) if sec.attr?('anchors')
      title_html = %(#{sec.sectnum} #{title_html}) if !sec.special && sec.attr?('numbered') && sec.level < 4
    end
    
    if sec.level == 0
      
      %(<div data-type="part"#{idatt}>
      <h1>#{sec.title}</h1>
      #{sec.content}
    </div>)
    
    elsif sec.level == 1
      
      if sec.sectname == 'preface[@role="foreword"]'
        %(<section data-type="foreword"#{idatt}>
      <h#{sec.level}>#{sec.title}</h#{sec.level}>
      #{sec.content}
    </section>)
      elsif sec.sectname == 'preface'
        %(<section data-type="preface"#{idatt}>
      <h#{sec.level}>#{sec.title}</h#{sec.level}>
      #{sec.content}
    </section>)
      elsif sec.sectname == 'appendix'
        %(<section data-type="appendix"#{idatt}>
      <h#{sec.level}>#{sec.title}</h#{sec.level}>
      #{sec.content}
    </section>)
      else
        %(<section data-type="chapter"#{idatt}>
      <h#{sec.level}>#{sec.title}</h#{sec.level}>
      #{sec.content}
    </section>)
      end
    
    elsif sec.level > 1 && sec.level < 6
      %(<section data-type="sect#{sec.level-1}"#{idatt}>
      <h#{sec.level-1}>#{sec.title}</h#{sec.level-1}>
      #{sec.content}
    </section>)  
    end  
    
  end

  def template
    :invoke_result
  end
end

class BlockFloatingTitleTemplate < BaseTemplate
  def result(node)
    tag_name = "h#{node.level + 1}"
    id_attribute = node.id ? %( id="#{node.id}") : nil
    classes = [node.style, node.role].compact
    %(<#{tag_name}#{id_attribute} class="#{classes * ' '}">#{node.title}</#{tag_name}>)
  end

  def template
    :invoke_result
  end
end

class BlockDlistTemplate < BaseTemplate
  def template
    @template ||= @eruby.new "something"
#    @template ||= @eruby.new <<-EOS
#<%#encoding:UTF-8%><%
#if attr? 'style', 'qanda', false %>
#<div<%= @id && %( id="#{@id}") %> class="qlist<%= attr?('style') ? %( #{attr('style')}) : nil %><%= attr?('role') ? %( #{attr 'role'}) : #nil %>"><%= title? ? %(
#<div class="title">#{title}</div>) : nil %>
#<ol><%
#items.each do |terms, dd| %>
#<li><%
#[*terms].each do |dt| %>
#<p><em><%= dt.text %></em></p><%
#end
#unless dd.nil? %><%
#if dd.text? %>
#<p><%= dd.text %></p><%
#end %><%
#if dd.blocks? %>
#<%= dd.content.chomp %><%
#end %><%
#end %>
#</li><%
#end %>
#</ol>
#</div><%
#elsif attr? 'style', 'horizontal', false %>
#<div<%= @id && %( id="#{@id}") %> class="hdlist<%= attr?('role') ? %( #{attr 'role'}) : nil %>"><%= title? ? %(
#<div class="title">#{title}</div>) : nil %>
#<table>
#<colgroup>
#<col<% if attr? 'labelwidth' %> style="width:<%= attr 'labelwidth' %>%;"<% end %>>
#<col<% if attr? 'itemwidth' %> style="width:<%= attr 'itemwidth' %>%;"<% end %>>
#</colgroup><%
#items.each do |terms, dd| %>
#<tr>
#<td class="hdlist1<% if attr? 'strong-option' %> strong<% end %>"><%
#[*terms].each do |dt| %>
#<%= dt.text %>
#<br><%
#end %>
#</td>
#<td class="hdlist2"><%
#unless dd.nil? %><%
#if dd.text? %>
#<p style="margin-top: 0;"><%= dd.text %></p><%
#end %><%
#if dd.blocks? %>
#<%= dd.content.chomp %><%
#end %><%
#end %>
#</td>
#</tr><%
#end %>
#</table>
#</div><%
#else %>
#<div<%= @id && %( id="#{@id}") %> class="dlist<%= attr?('style') ? %( #{attr 'style'}) : nil %><%= attr?('role') ? %( #{attr 'role'}) : #nil %>"><%= title? ? %(
#<div class="title">#{title}</div>) : nil %>
#<dl><%
#items.each do |terms, dd|
#[*terms].each do |dt| %>
#<dt<%= !(attr? 'style', nil, false) ? ' class="hdlist"' : nil %>>
#<%= dt.text %>
#</dt><%
#end
#unless dd.nil? %>
#<dd><%
#if dd.text? %>
#<p><%= dd.text %></p><%
#end %><%
#if dd.blocks? %>
#<%= dd.content.chomp %><%
#end %>
#</dd><%
#end %><%
#end %>
#</dl>
#</div><%
#end %>
#    EOS
  end
end

class BlockListingTemplate < BaseTemplate
  def result(node)
    idatt = node.id? ? %( id=#{node.id}) : nil
    lang = node.attr?('style', 'source', false) ? %(data-code-language="#{node.attr('language')}") : nil
    %(<pre#{idatt} data-type="programlisting" class="programlisting"#{lang}>#{node.content}</pre>)
  end

  def template
    :invoke_result
  end
end

class BlockLiteralTemplate < BaseTemplate
  def result(node)
    %(<pre>#{node.content}</pre>)
  end

  def template
    :invoke_result
  end
end

class BlockAdmonitionTemplate < BaseTemplate
  def result(node)
    role = stratt(node, 'class', :role)
    title = node.title? ? %(<h1>#{node.title}</h1>) : nil
    %(<div data-type="#{node.attr('name')}"#{role}>
  #{title}
  #{node.content.chomp}
</div>)
  end

  def template
    :invoke_result
  end
end

class BlockParagraphTemplate < BaseTemplate
  def result(node)
    %(<p>#{node.content}</p>)
  end

  def template
    :invoke_result
  end
end

class BlockSidebarTemplate < BaseTemplate
  def result(node)
    id_attribute = node.id ? %( id="#{node.id}") : nil
    role_attribute   = node.attr?('role') ? %( class="#{node.attr('width')}") : nil
    %(<aside#{id_attribute} data-type="sidebar" class="sidebar#{role_attribute}">
<h5>#{node.title}</h5>
#{node.content}
</aside>)
  end

  def template
    :invoke_result
  end
end

class BlockLatexmathTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><div data-type="equation">
<p data-type="tex">
<%= content %>
</p>
</div>
    EOS
  end
end

class BlockExampleTemplate < BaseTemplate
  def result(node)
    idatt = node.id ? %( id="#{node.id}") : nil
    lang = node.attr?('style', 'source', false) ? %( data-code-language="#{node.attr('language')}") : nil
    role = stratt(node, 'class', :role)
    caption_title = node.document.attributes["example-caption"]
    caption_num = node.document.attributes["example-number"]
    section_num = node.next_section_index += 1

    %(<div#{idatt} data-type="example"#{role}>
  <h5><span data-type="label">#{caption_title} #{section_num}-#{caption_num}.</span> #{node.title}</h5>
  <pre#{lang}>#{node.content}</pre>
</div>)
  end

  def template
    :invoke_result
  end
end

class BlockOpenTemplate < BaseTemplate
  def result(node)
    open_block(node, node.id, node.style, node.role, node.title? ? node.title : nil, node.content)
  end

  def open_block(node, id, style, role, title, content)
    if style == 'abstract'
      if node.parent == node.document && node.document.doctype == 'book'
        warn 'asciidoctor: WARNING: abstract block cannot be used in a document without a title when doctype is book. Excluding block content.'
        ''
      else
        %(<div#{id && " id=\"#{id}\""} class="quoteblock abstract#{role && " #{role}"}">#{title &&
"<div class=\"title\">#{title}</div>"}
<blockquote>
#{content}
</blockquote>
</div>)
      end
    elsif style == 'partintro' && (node.level != 0 || node.parent.context != :section || node.document.doctype != 'book')
      warn 'asciidoctor: ERROR: partintro block can only be used when doctype is book and it\'s a child of a book part. Excluding block content.'
      ''
    else
      %(<div#{id && " id=\"#{id}\""} class="openblock#{style != 'open' ? " #{style}" : ''}#{role && " #{role}"}">#{title &&
"<div class=\"title\">#{title}</div>"}
<div class="content">
#{content}
</div>
</div>)
    end
  end

  def template
    :invoke_result
  end
end

class BlockPassTemplate < BaseTemplate
  def template
    :content
  end
end

class BlockQuoteTemplate < BaseTemplate
  def result(node)
    role = stratt(node, 'class', :role)
    quote = %(<blockquote data-type="epigraph"#{role}>#{node.content.chomp})
    
    if node.attr?(:attribution) or node.attr?(:citetitle)
      quote += %(<p data-type="attribution">)
      if node.attr?(:citetitle)
        quote += %(<cite>#{node.attr(:citetitle)}</cite>) 
      end
      if node.attr?(:attribution)
        quote += %(<br />) if node.attr?(:citetitle)
        quote += %(&#8212; #{node.attr(:attribution)})
      end
    end
    quote += %(</blockquote>)
    quote
  end

  def template
    :invoke_result
  end
end

class BlockVerseTemplate < BaseTemplate
  def result(node)
    id_attribute = node.id ? %( id="#{node.id}") : nil
    classes = ['verseblock', node.role].compact
    class_attribute = %( class="#{classes * ' '}")
    title_element = node.title? ? %(\n<div class="title">#{node.title}</div>) : nil
    attribution = (node.attr? 'attribution') ? (node.attr 'attribution') : nil
    citetitle = (node.attr? 'citetitle') ? (node.attr 'citetitle') : nil
    if attribution || citetitle
      cite_element = citetitle ? %(<cite>#{citetitle}</cite>) : nil
      attribution_text = attribution ? %(#{citetitle ? "<br>\n" : nil}&#8212; #{attribution}) : nil
      attribution_element = %(\n<div class="attribution">\n#{cite_element}#{attribution_text}\n</div>)
    else
      attribution_element = nil
    end

    %(<div#{id_attribute}#{class_attribute}>#{title_element}
<pre class="content">#{preserve_endlines node.content, node}</pre>#{attribution_element}
</div>)
  end

  def template
    :invoke_result
  end
end

class BlockUlistTemplate < BaseTemplate
  def result(node)
    idatt = node.id ? %( id="#{node.id}") : nil
    role = stratt(node, 'class', :role)
    list = %(<ul#{idatt}#{role}>)
    list += node.content.map { |item|
      li = %(<li><p>#{item.text}</p>)
      li += item.content if item.blocks?
      li += %(</li>)
    }.join("")
    list += %(</ul>)
  end

  def template
    :invoke_result
  end
end

class BlockOlistTemplate < BaseTemplate
  def result(node)
    idatt = node.id ? %( id="#{node.id}") : nil
    role = stratt(node, 'class', :role)
    start = stratt(node, 'start', :start)
    list = %(<ol#{idatt}#{role}#{start}>)
    list += node.content.map { |item|
      li = %(<li><p>#{item.text}</p>)
      li += item.content if item.blocks?
      li += %(</li>)
    }.join("")
    list += %(</ol>)
  end

  def template
    :invoke_result
  end
end

class BlockColistTemplate < BaseTemplate
  def result(node)
    result_buffer = []
    id_attribute = node.id ? %( id="#{node.id}") : nil
    classes = ['colist', node.style, node.role].compact
    class_attribute = %( class="#{classes * ' '}")

    result_buffer << %(<div#{id_attribute}#{class_attribute}>)
    result_buffer << %(<div class="title">#{node.title}</div>) if node.title?

    if node.document.attr? 'icons'
      result_buffer << '<table>'

      font_icons = node.document.attr? 'icons', 'font'
      node.items.each_with_index do |item, i|
        num = i + 1
        num_element = font_icons ?
            %(<i class="conum" data-value="#{num}"></i><b>#{num}</b>) :
            %(<img src="#{node.icon_uri "callouts/#{num}"}" alt="#{num}">)
        result_buffer << %(<tr>
<td>#{num_element}</td>
<td>#{item.text}</td>
</tr>)
      end

      result_buffer << '</table>'
    else
      result_buffer << '<ol>'
      node.items.each do |item|
        result_buffer << %(<li>
<p>#{item.text}</p>
</li>)
      end
      result_buffer << '</ol>'
    end

    result_buffer << '</div>'
    result_buffer * EOL
  end

  def template
    :invoke_result
  end
end

class BlockTableTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><table<%= @id && %( id="#{@id}") %><%= attr?('role') ? %( class="#{attr 'role'}") : nil %>>
<% if title? %>
<caption><span data-type="label"><%= caption_title = @document.attributes["table-caption"]
caption_num = @document.attributes["table-number"]
section_num = @next_section_index += 1
@caption = "#{caption_title} #{section_num}-#{caption_num}."%></span> <%= title %></caption><% end %><%
if (attr 'rowcount') >= 0 %>
<colgroup><%
if attr? 'autowidth-option' %><%
@columns.each do %>
<col><%
end %><%
else %><%
@columns.each do |col| %>
<col style="width:<%= col.attr 'colpcwidth' %>%;"/><%
end %><%
end %>
</colgroup><%
[:head, :foot, :body].select {|tsec| !@rows[tsec].empty? }.each do |tsec| %>
<t<%= tsec %>><%
@rows[tsec].each do |row| %>
<tr><%
row.each do |cell| %>
<<%= tsec == :head ? 'th' : 'td' %><%= cell.colspan ? %( colspan="#{cell.colspan}") : nil %><%= cell.rowspan ? %( rowspan="#{cell.rowspan}") : nil %>><% 
if tsec == :head %><%= cell.text %><% else %><% 
case cell.attr('style', nil, false)
when :asciidoc %><div><%= cell.content %></div><%
else %><% cell.content.each do |text| %><p<%= attr?('role') ? %( class="#{attr 'role'}") : nil %>><%= text %></p><% end %><%
end %><% end %></<%= tsec == :head ? 'th' : 'td' %>><%
end %>
</tr><%
end %>
</t<%= tsec %>><%
end %><%
end %>
</table>
    EOS
  end
end

class BlockImageTemplate < BaseTemplate

  def result(node)
    
    idatt = node.id? ? %( id=#{node.id}) : nil
    role = stratt(node, 'class', :role)
    alt = stratt(node, 'alt', :alt)
    width = stratt(node, 'width', :width)
    caption_title = node.document.attributes["figure-caption"]
    caption_num = node.document.attributes["figure-number"]
    section_num = node.next_section_index += 1

    img = %(<figure#{idatt}#{role}>
  <img src="#{image_uri(node.attr('target'))}"#{alt}#{width} />)

    if node.title?
      img += %(<figcaption><span data-type="label">#{caption_title} #{section_num}-#{caption_num}.</span> #{node.title}</figcaption>)
    else
      img += %(<figcaption/>)
    end

    img += %(</figure>)
    img
  end

  def template
    :invoke_result
  end
end

class BlockAudioTemplate < BaseTemplate
  def result(node)
    id_attribute = node.id ? %( id="#{node.id}") : nil
    classes = ['audioblock', node.style, node.role].compact
    class_attribute = %( class="#{classes * ' '}")
    title_element = node.title? ? %(\n<div class="title">#{node.captioned_title}</div>) : nil
    %(<div#{id_attribute}#{class_attribute}>#{title_element}
<div class="content">
<audio src="#{node.media_uri(node.attr 'target')}"#{(node.option? 'autoplay') ? ' autoplay' : nil}#{(node.option? 'nocontrols') ? nil : ' controls'}#{(node.option? 'loop') ? ' loop' : nil}>
Your browser does not support the audio tag.
</audio>
</div>
</div>)
  end

  def template
    :invoke_result
  end
end

class BlockVideoTemplate < BaseTemplate
  def result(node)
    idatt  = node.id ? %( id="#{node.id}") : nil
    role   = stratt(node, 'class', :role)
    width  = stratt(node, 'width', :width)
    height = stratt(node, 'height', :height)
    poster = stratt(node, 'poster', :poster)
    %(<video#{idatt}#{role}#{width}#{height} controls="controls"#{poster}>
<source src="#{node.media_uri(node.attr 'target')}"/>
Sorry, the &lt;video&gt; element is not supported in your reading system.
</video>)
  end

  def template
    :invoke_result
  end
end

class BlockRulerTemplate < BaseTemplate
  def result(node)
    '<hr>'
  end

  def template
    :invoke_result
  end
end

class BlockPageBreakTemplate < BaseTemplate
  def result(node)
    %(<div style="page-break-after: always;"></div>\n)
  end

  def template
    :invoke_result
  end
end

class InlineBreakTemplate < BaseTemplate
  def result(node)
    %(#{node.text}<br>\n)
  end

  def template
    :invoke_result
  end
end

class InlineLatexmathTemplate < BaseTemplate
  def template
    @template ||= @eruby.new <<-EOS
<%#encoding:UTF-8%><span data-type="tex"><%= %(#{text}) %></span>
    EOS
  end
end

class InlineCalloutTemplate < BaseTemplate
  def result(node)
    if node.document.attr? 'icons', 'font'
      %(<i class="conum" data-value="#{node.text}"></i><b>(#{node.text})</b>)
    elsif node.document.attr? 'icons'
      src = node.icon_uri("callouts/#{node.text}")
      %(<img src="#{src}" alt="#{node.text}">)
    else
      "<b>(#{node.text})</b>"
    end
  end

  def template
    :invoke_result
  end
end

class InlineQuotedTemplate < BaseTemplate

  def result(node)
    text_span = node.attr?('role') ? %(<span class="#{node.attr('role')}">#{node.text}</span>) : node.text
    case node.type
    when :emphasis
      %(<em>#{text_span}</em>)
    when :strong
      %(<strong>#{text_span}</strong>)
    when :monospaced
      %(<code>#{text_span}</code>)
    when :superscript
      %(<sup>#{text_span}</sup>)
    when :subscript
      %(<sub>#{text_span}</sub>)
    when :double
      %(&#8220;#{text_span}&#8221;)
    when :single
      %(&#8216;#{text_span}&#8217;)
    else
      text_span
    end
  end

  def template
    :invoke_result
  end
end

class InlineButtonTemplate < BaseTemplate
  def result(node)
    %(<b class="button">#{node.text}</b>)
  end

  def template
    :invoke_result
  end
end

class InlineKbdTemplate < BaseTemplate
  def result(node)
    keys = node.attr 'keys'
    if keys.size == 1
      %(<kbd>#{keys.first}</kbd>)
    else
      key_combo = keys.map{|key| %(<kbd>#{key}</kbd>+) }.join.chop
      %(<kbd class="keyseq">#{key_combo}</kbd>)
    end
  end

  def template
    :invoke_result
  end
end

class InlineMenuTemplate < BaseTemplate
  def menu(menu, submenus, menuitem)
    if !submenus.empty?
      submenu_path = submenus.map{|submenu| %(<span class="submenu">#{submenu}</span>&#160;&#9656; ) }.join.chop
      %(<span class="menuseq"><span class="menu">#{menu}</span>&#160;&#9656; #{submenu_path} <span class="menuitem">#{menuitem}</span></span>)
    elsif !menuitem.nil?
      %(<span class="menuseq"><span class="menu">#{menu}</span>&#160;&#9656; <span class="menuitem">#{menuitem}</span></span>)
    else
      %(<span class="menu">#{menu}</span>)
    end
  end

  def result(node)
    menu(node.attr('menu'), node.attr('submenus'), node.attr('menuitem'))
  end

  def template
    :invoke_result
  end
end

class InlineAnchorTemplate < BaseTemplate
  def anchor(target, text, type, document, node)
    case type
    when :xref
      %(<a data-type="xref" href="#{target}">#{text || document.references[:ids].fetch(target, "[#{target}]").tr_s("\n", ' ')}</a>)
    when :ref
      %(<a id="#{target}"></a>)
    when :bibref
      %(<a id="#{target}">[#{target}]</a>)
    else 
      role = stratt(node, 'role', :role)
      window = stratt(node, 'window', :window)
      %(<a href="#{target}"#{role}#{window}>#{node.text}</a>)
    end
  end

  def result(node)
    anchor(node.target, node.text, node.type, node.document, node)
  end

  def template
    :invoke_result
  end
end

class InlineImageTemplate < BaseTemplate

  def result(node)
    extra_class = node.attr?('role') ? %( #{node.attr('role')}) : nil
    width = stratt(node, 'width', :width)
    height = stratt(node, 'height', :height)

    img = %(<span class="image#{extra_class}">)

    if node.attr? 'link'
      img += %(<a class="image" href="#{node.attr('link')}">)
    end
    img += %(<img src="#{image_uri(@target)}" alt="#{width}#{height}"/>)

    if node.attr? 'link'
      img += "</a>"
    end

    img += %(</span>)
    img
  end

  def template
    :invoke_result
  end
end

class InlineFootnoteTemplate < BaseTemplate
  def result(node)
    index = node.attr :index
    if node.type == :xref
      %(<a data-type="footnoteref" href="##{node.target}"/>)
    else
      idatt = node.id ? %( id="#{node.id}") : nil
      %(<span data-type="footnote"#{idatt}>#{node.text}%></span>)
    end
  end

  def template
    :invoke_result
  end
end

class InlineIndextermTemplate < BaseTemplate
  def result(node)
    terms = node.attr(:terms).map { |term| term.gsub("\"", "") }
    numterms = terms.size
    index = ""
    if numterms > 2
      index += %(<a data-type="indexterm" data-primary="#{terms[0]}" data-secondary="#{terms[1]}" data-tertiary="#{terms[2]}"></a>)
    end
    if numterms > 1
      index += %(<a data-type="indexterm" data-primary="#{terms[-2]}" data-secondary="#{terms[-1]}"></a>)
    end
    index += %(<a data-type="indexterm" data-primary="#{terms[-1]}"></a>)
  end

  def template
    :invoke_result
  end
end

end # module HTMLBook
end # module Asciidoctor
