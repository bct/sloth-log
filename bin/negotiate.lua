-- Copyright (c) 2009 Michael Gorven

-- Permission is hereby granted, free of charge, to any person
-- obtaining a copy of this software and associated documentation
-- files (the "Software"), to deal in the Software without
-- restriction, including without limitation the rights to use,
-- copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following
-- conditions:

-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
-- OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
-- HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
-- OTHER DEALINGS IN THE SOFTWARE.

qualities = {
	["application/xhtml+xml"] = 1.0,
	["text/html"] = 0.9,
	["application/atom+xml"] = 0.8,
	["*/*"] = 0.5,
}

header = [[
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
         "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title>406 - Not Acceptable</title>
 </head>
 <body>
  <h1>406 - Not Acceptable</h1>
  <p>No variants matched your preferences. These are the available variants.</p>
<ul>
]]
footer = [[
</ul>
</body>
</html>]]

-- Load mime types
if not _G["types"] then
	print("Loading /etc/mime.types")
	_G["types"] = {}
	for line in io.lines("/etc/mime.types") do
		if line:match("^%s*[^#]%s*%S+") then
			local split = {}
			for part in line:gmatch("(%S+)") do
				table.insert(split, part)
			end
			for i = 2, #split, 1 do
				_G["types"][split[i]] = split[1]
			end
		end
	end
end

-- Don't do anything if the file exists or the directory doesn't exist
path = lighty.env["physical.path"]
dir = path:match("^(.*/)[^/]*$")
reldir = lighty.env["physical.rel-path"]:match("^(.*/)[^/]*$")
uripath = lighty.env["uri.path"]:match("^(.*/)[^/]*$")
if (path ~= dir and lighty.stat(path)) or not lighty.stat(dir) then
	return
end

-- Extract filename and create the pattern
file = path:match("^.*/([^/]*)$")
if file == "" then file = "index" end
pattern = file.."."
len = pattern:len()

require "lfs"

-- XXX bottleneck here - 11.26s!!!
-- start = os.clock()
-- for xxx=1,100000 do

-- Find the available mime types
local variants = {}
local found = false
for filename in lfs.dir(dir) do
	if filename:sub(0, len) == pattern then
		mime = _G["types"][filename:sub(len+1)] or "application/octet-stream"
		variants[mime] = filename
		found = true
	end
end

-- end
-- stop = os.clock()
-- print("time = "..(stop-start))

-- Don't do anything if there aren't any variants to choose from
if not found then
	return
end


-- Parse Accept header
local accept = {}
if not lighty.request["Accept"] then
	accept["*/*"] = 1
else
	for range in lighty.request["Accept"]:gmatch(" *([^,]+) *") do
		accept[range:match("([^;]+)")] = range:match("q *= *([0-9.]+)") or 1
	end
end

-- Hack for user agents which don't send quality values for wildcards
if lighty.request["Accept"] and not lighty.request["Accept"]:find("q=") then
	for mime, quality in pairs(accept) do
		if mime == "*/*" then
			accept[mime] = 0.01
		elseif mime:find("*") then
			accept[mime] = 0.02
		end
	end
end

-- Calculate quality of each candidate
local candidates = {}
for mime, filename in pairs(variants) do
	q1 = accept[mime] or accept[mime:match("(%S+/)").."*"] or accept["*/*"] or 0
	q2 = qualities[mime] or qualities[mime:match("(%S+/)").."*"] or qualities["*/*"] or 1
	candidates[filename] = q1 * q2
end

-- Find the candidate with the highest quality
local max = 0
local winner = ""
for filename, quality in pairs(candidates) do
	if quality > max then
		max = quality
		winner = filename
	end
end

-- Try to make caches do the right thing
-- lighttpd < 1.4.20 doesn't have request.protocol
if not lighty.env["request.protocol"] or lighty.env["request.protocol"] == "HTTP/1.1" then
	lighty.header["Vary"] = "Accept"
else
	lighty.header["Expires"] = "Thu, 01 Jan 1970 00:00:00 GMT"
end

-- If we have a winner, update the paths
if max ~= 0 then
	lighty.env["physical.path"] = dir..winner
	lighty.env["physical.rel-path"] = reldir..winner
	return
end

-- Return '406 Not Acceptable' if no variants match
-- lighttpd < 1.4.20 doesn't return the body
lighty.content = {header}
for filename, quality in pairs(candidates) do
	table.insert(lighty.content, '<li><a href="'..uripath..filename..'">'..filename..'</a></li>\n')
end
table.insert(lighty.content, footer)
lighty.header["Content-Type"] = "text/html"
return 406
