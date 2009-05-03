#!/usr/bin/env ruby

require 'rubygems'
require 'maruku'

require 'atom/feed'
require 'atom/entry'

class Atom::Entry
  attrb ['ibes', 'http://necronomicorp.com/ns/ibes'], 'slug'
end

require 'yaml'

CONF_FILE = 'config.yaml'
ENTRIES_DIR = './entries'

def write_default_config_file
  File.open(CONF_FILE, 'w') do |f|
    f.write <<END
# directory to save output files to (required)
output directory: ./output/

# HTTP path that this will all be accessible under (required)
http root:

# this is prefixed to each entry's slug to create an ID URL (required)
#id prefix: http://example.org/

# system-wide blog title
title: (configure me)

# system-wide author details - good idea to fill in at least the name.
# (you can also give per-entry author names with the Author attribute)
#author:
#  name: The Author
#  uri: http://example.org/
#  email: author@example.org

# URL of stylesheet to use
#css url:

entries per page: 10
END
  end
end

def load_config
  unless File.file? CONF_FILE
    write_default_config_file
  end

  YAML.load(File.read(CONF_FILE))
end

require 'rexml/xpath'

def url(*args)
  Conf['http root'] + '/' + args.join('/')
end

# fill an Atom::Entry's content in from a REXML HTML tree
def html_to_atom_content(html_tree, atom_entry)
  # make a blank XHTML <atom:content/>
  atom_entry.content = ''
  atom_entry.content.type = 'xhtml'

  # skip the <h1/> (it's already in the <atom:title/>)
  REXML::XPath.each(html_tree, '//body/*[name() != "h1"]') do |el|
    # unfortunately I didn't expose an atom-tools API for appending elements...
    atom_entry.content.instance_variable_get('@content') << el
  end
end

# takes a Maruku document, turns it into an Atom::Entry
def maruku_to_atom(mrk)
  e = Atom::Entry.new

  e.slug      = mrk.attributes[:slug]
  e.id        = Conf['id prefix'] + mrk.attributes[:slug]
  e.title     = mrk.attributes[:title]
  e.updated   = mrk.attributes[:updated]
  e.tag_with mrk.attributes[:tags]

  if mrk.attributes[:author]
    e.authors.new :name => mrk.attributes[:author]
  end

  html_to_atom_content(mrk.to_html_document_tree, e)

  e
end

def paginate(entries, per_page)
  pages = []
  page = []

  entries.each do |e|
    page << e

    if page.length == per_page
      pages << page
      page = []
    end
  end

  unless page.empty?
    pages << page
  end

  pages
end

require 'xml/xslt'
class XSLTer
  def initialize
    @xslt = XML::XSLT.new
  end

  # this needs to be done this way (with the dups) because ruby-xslt is a bit goofy
  # (it's probably my fault, hopefully i can fix that)
  def get_params
    ps = {
      'blog-title' => Conf['title'].dup,
      'http-root' => Conf['http root'].dup
    }

    if Conf['css url']
      ps['css-url'] = Conf['css url'].dup
    end

    ps
  end

  def transform(stylesheet, xml)
    @xslt.parameters = get_params()
    @xslt.xsl = "./xsl/#{stylesheet}.xsl"
    @xslt.xml = xml
    @xslt.serve
  end
end

$xslt = XSLTer.new

def transform_and_write(atom, slug, reprs = ['atom', 'xhtml'])
  fname = File.join(Conf['output directory'], slug)
  outdir = File.dirname(fname)

  unless File.directory?(outdir)
    Dir.mkdir outdir
  end

  xml = atom.to_s

  if reprs.member? 'atom'
    File.open(fname + '.atom', 'w') do |f|
      f.write xml
    end

    File.utime(atom.updated, atom.updated, fname + '.atom')
  end

  if reprs.member? 'xhtml'
    File.open(fname + '.xhtml', 'w') do |f|
      f.write $xslt.transform('xhtml', xml)
    end

    File.utime(atom.updated, atom.updated, fname + '.xhtml')

    File.open(fname + '.html', 'w') do |f|
      f.write $xslt.transform('xhtml2html', fname + '.xhtml')
    end

    File.utime(atom.updated, atom.updated, fname + '.html')
  end
end

# get a list of entries sorted by modification time, oldest first
def get_entries(dir)
  m = Dir[dir + '/*'].map do |file|
    mrk = Maruku.new(File.read(file))

    mtime = File.mtime(file)
    mrk.attributes[:slug] = file.sub(/#{dir}\//, '')
    mrk.attributes[:updated] = mtime

    entry = maruku_to_atom(mrk)
    entry.links.new :href => url(entry.slug) # alternate link

    [mtime, entry]
  end

  a = Dir['./atom/*'].map do |file|
    entry = Atom::Entry.parse(File.read(file))
    mtime = entry.updated

    entry.slug = File.basename(file)
    entry.links.new :href => url(entry.slug) # alternate link

    [mtime, entry]
  end

  (m+a).sort.map { |m,e| e }
end

def write_entry_pages(entries)
  # write individual entry pages
  entries.each do |entry|
    transform_and_write(entry, entry.slug, ['xhtml'])
  end
end

def write_front_page(entries, next_page_href)
  # the newest entries
  front_page = entries.last(Conf['entries per page']).reverse
  fp_feed = Atom::Feed.new
  fp_feed.title = Conf['title']

  front_page.each do |entry|
    fp_feed << entry
  end

  fp_feed.updated = front_page.first.updated
  fp_feed.links.new :rel => 'prev-archive',
                    :href => next_page_href

  transform_and_write(fp_feed, 'index')
end

def write_archives(pages)
  pages.each_with_index do |entries,i|
    p_feed = Atom::Feed.new
    p_feed.title = Conf['title'] + " (page #{i})"

    entries.reverse.each do |entry|
      p_feed << entry
    end

    p_feed.updated = entries.first.updated

    p_feed.links.new :rel => 'current',
                      :href => url('index')

    unless i == 0
      p_feed.links.new :rel => 'prev-archive',
                        :href => url('p', i-1)
    end

    unless i == (pages.length - 1)
      p_feed.links.new :rel => 'next-archive',
                        :href => url('p', i+1)
    end

    transform_and_write(p_feed, "p/#{i}")
  end
end

if __FILE__ == $0
  Conf = load_config

  entries = get_entries(ENTRIES_DIR)
  write_entry_pages(entries)

  pages = paginate(entries, Conf['entries per page'])
  write_archives(pages)

  write_front_page(entries, url('p', pages.length-1))
end
