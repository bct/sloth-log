#!/usr/bin/env ruby

require 'rubygems'
require 'maruku'
require 'atom/entry'

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

# takes a Maruku document, turns it into an Atom::Entry
def maruku_to_atom(mrk)
  e = Atom::Entry.new

  e.tag_with mrk.attributes[:tags]
  e.title     = mrk.attributes[:title]
  e.updated   = mrk.attributes[:updated]

  if mrk.attributes[:author]
    e.authors.new :name => mrk.attributes[:author]
  end

  e.content = ''
  e.content.type = 'xhtml'

  tree = mrk.to_html_document_tree

  # skip the <h1/> (it's already in the <atom:title/>)
  REXML::XPath.each(tree, '//body/*[name() != "h1"]') do |el|
    # unfortunately I didn't expose an atom-tools API for appending elements...
    e.content.instance_variable_get('@content') << el
  end

  e
end

def write_output
  outdir = Conf['output directory']

  unless File.directory?(outdir)
    Dir.mkdir outdir
  end

  Dir[ENTRIES_DIR + '/*'].each do |entry|
    mrk = Maruku.new(File.read(entry))
    mrk.attributes[:updated] = File.mtime(entry)

    bname = File.basename(entry)

    File.open(File.join(outdir + bname + '.html'), 'w') do |f|
      f.write mrk.to_html_document
    end

    File.open(File.join(outdir + bname + '.atom'), 'w') do |f|
      f.write maruku_to_atom(mrk).to_s
    end
  end
end

if __FILE__ == $0
  Conf = load_config
  write_output
end
