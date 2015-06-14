path = require 'path'
fs = require 'fs'

files = []

if process.argv.length < 3
  dir = path.join __dirname, 'tests'
  files = fs.readdirSync dir
  files = files.filter (x) -> x[0] != '.'
               .map (x) -> path.join dir, x
else
  file = path.join process.cwd(), process.argv[2]
  files = [file]

print_header = (msg) ->
  msg = '# ' + msg + ' #'
  bar = ('#' for i in msg).join ''
  console.log bar
  console.log msg
  console.log bar

for file in files
  print_header ('Running test file: ' + file)
  require file

print_header 'Tests all passed!'
