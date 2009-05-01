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
# directory to save output files to
output directory: ./output/

# system-wide author details - please fill in at least the name.
# (you can also give per-entry author names with the Author attribute)
#author:
#  name: The Author
#  uri: http://example.org/
#  email: author@example.org

# system-wide blog title
title: (configure me)

# string to be prefixed to an entry's local path to create an ID URL
#id prefix: http://example.org/

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
  entries.each do |mtime,file|
    page << [mtime,file]

    if page.length == per_page
      page.reverse # newest first
      pages << page
      page = []
    end
  end

  unless page.empty?
    page.reverse  # newest first
    pages << page
  end

  pages
end


def write_page(feed, path)
  fname = File.join(Conf['output directory'], path)
  outdir = File.dirname(fname)

  unless File.directory?(outdir)
    Dir.mkdir outdir
  end

  File.open(fname + '.atom', 'w') do |f|
    f.write feed
  end

  # set access and modification times to feed updated time
  File.utime(feed.updated, feed.updated, fname + '.atom')

  require 'xml/xslt'

  xslt = XML::XSLT.new
  xslt.xsl = './xsl/xhtml.xsl'
  xslt.xml = fname + '.atom'

  xslt.parameters = {'title' => Conf['title']}
  puts xslt.serve
end

def write_output
  # get a list of entries sorted by modification time, oldest first
  entries = Dir[ENTRIES_DIR + '/*'].map do |file|
    mrk = Maruku.new(File.read(file))

    mtime = File.mtime(file)
    mrk.attributes[:slug] = file.sub(/#{ENTRIES_DIR}\//, '')
    mrk.attributes[:updated] = mtime

    [mtime, mrk]
  end.sort

  # the newest entries
  front_page = entries.last(Conf['entries per page']).reverse
  fp_feed = Atom::Feed.new

  front_page.each do |mtime,mrk|
    fp_feed << maruku_to_atom(mrk)
  end

  fp_feed.updated = front_page.first[0]
  write_page(fp_feed, 'index')
end

if __FILE__ == $0
  Conf = load_config
  write_output
end
