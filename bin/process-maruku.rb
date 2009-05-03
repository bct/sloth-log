#!/usr/bin/env ruby

require 'rubygems'
require 'maruku'

require 'atom/feed'
require 'atom/entry'

class Atom::Entry
  attrb ['ibes', 'http://necronomicorp.com/ns/ibes'], 'slug'
end

#
# ----- configuration -----
#
require 'yaml'

CONF_FILE = 'config.yaml'

def write_default_config_file
  File.open(CONF_FILE, 'w') do |f|
    f.write <<END
# directory to save output files to (required)
output directory: ./output/

# directory to get input files from (required)
maruku directory: ./entries/ # maruku files
atom directory: ./atom/      # XML Atom entries

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

#
# ----- maruku/atom conversion -----
#

require 'rexml/xpath'

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

#
# ----- output handling details -----
#

require 'xml/xslt'

# transformations and actual output
class Outputter
  def initialize
    @x = XML::XSLT.new
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

  def transform(xml, stylesheet)
    @x.parameters = get_params()
    @x.xsl = "./xsl/#{stylesheet}.xsl"
    @x.xml = xml
    @x.serve
  end

  # write 'data' to 'fname' with modification time 'mtime'
  def write(fname, mtime, data)
    File.open(fname, 'w') do |f|
      f.write data
    end

    File.utime(mtime, mtime, fname)
  end

  # 'atom' is an Atom::Feed or an Atom::Entry, it doesn't matter
  # 'slug' is just a path relative to the output directory
  # 'reprs' is a list of representations to be created
  def do(atom, slug, reprs = ['atom', 'xhtml'])
    fname = File.join(Conf['output directory'], slug)
    outdir = File.dirname(fname)

    unless File.directory?(outdir)
      Dir.mkdir outdir
    end

    xml = atom.to_s

    if reprs.member? 'atom'
      write(fname + '.atom', atom.updated, xml)
    end

    if reprs.member? 'xhtml'
      xhtml = transform(xml, 'xhtml')
      write(fname + '.xhtml', atom.updated, xhtml)

      html = transform(xhtml, 'xhtml2html')
      write(fname + '.html', atom.updated, html)
    end
  end
end

#
# ----- determining what goes into a feed -----
#

# a collection of entries converted from `maruku dir` or parsed from `atom dir`
# this class controls the loading, conversion and output
class Entries
  def initialize(maruku_dir, atom_dir)
    @es = get_entries(maruku_dir, atom_dir)

    @pages = paginate(Conf['entries per page'])

    @out = Outputter.new
  end

  # get a list of entries sorted by modification time, oldest first
  def get_entries(maruku_dir, atom_dir)
    # load maruku entries
    m = Dir[maruku_dir + '/*'].map do |file|
      mrk = Maruku.new(File.read(file))

      mrk.attributes[:slug] = file.sub(/#{maruku_dir}\//, '')
      mrk.attributes[:updated] = File.mtime(file)

      entry = maruku_to_atom(mrk)
      entry.links.new :href => url(entry.slug) # alternate link

      entry
    end

    # load XML Atom entries
    a = Dir[atom_dir + '/*'].map do |file|
      entry = Atom::Entry.parse(File.read(file))

      entry.slug = File.basename(file)
      entry.links.new :href => url(entry.slug) # alternate link

      entry
    end

    (m+a).sort_by { |e| e.updated }
  end

  def paginate(per_page)
    pages = []
    page = []

    @es.each do |e|
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

  def write_entry_pages
    # write individual entry pages
    @es.each do |entry|
      @out.do(entry, entry.slug, ['xhtml'])
    end
  end

  def write_front_page
    front_page = @es.last(Conf['entries per page']).reverse

    fp_feed = make_feed(front_page)
    fp_feed.title = Conf['title']

    fp_feed.links.new :rel => 'prev-archive',
                      :href => url('p', @pages.length-1)

    @out.do(fp_feed, 'index')
  end

  def write_archives
    @pages.each_with_index do |entries,i|
      p_feed = make_feed(entries.reverse)
      p_feed.title = Conf['title'] + " (page #{i})"
      p_feed.links.new :rel => 'current',
                        :href => url('index')

      unless i == 0
        p_feed.links.new :rel => 'prev-archive',
                          :href => url('p', i-1)
      end

      unless i == (@pages.length - 1)
        p_feed.links.new :rel => 'next-archive',
                          :href => url('p', i+1)
      end

      @out.do(p_feed, "p/#{i}")
    end
  end

  def url(*args)
    Conf['http root'] + '/' + args.join('/')
  end

  def make_feed(entries)
    feed = Atom::Feed.new
    entries.each { |entry| feed << entry }
    feed.updated = entries.first.updated # here we assume newest is first
    feed
  end
end

if __FILE__ == $0
  Conf = load_config

  e = Entries.new(Conf['maruku directory'], Conf['atom directory'])
  e.write_entry_pages
  e.write_archives
  e.write_front_page
end
