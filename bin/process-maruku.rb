#!/usr/bin/env ruby

require 'rubygems'
require 'maruku'

require 'yaml'

CONF_FILE = 'config.yaml'
ENTRIES_DIR = './entries'

def write_default_config_file
  File.open(CONF_FILE, 'w') do |f|
    f.write <<END
# directory to save output files to
output directory: ./output/
END
  end
end

def load_config
  unless File.file? CONF_FILE
    write_default_config_file
  end

  YAML.load(File.read(CONF_FILE))
end

def write_output
  outdir = Conf['output directory']

  unless File.directory?(outdir)
    Dir.mkdir outdir
  end

  Dir[ENTRIES_DIR + '/*'].each do |entry|
    doc = Maruku.new(File.read(entry))

    outname = (File.basename(entry) + '.html')
    outpath = File.join Conf['output directory'], outname

    File.open(outpath, 'w') do |f|
      f.write doc.to_html_document
    end
  end
end

if __FILE__ == $0
  Conf = load_config
  write_output
end
