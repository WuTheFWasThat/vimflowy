gulp = require 'gulp'
fs = require 'fs'
promisify = require 'es6-promisify'

coffee = require 'gulp-coffee'
del = require 'del'
express = require 'express'
jade = require 'gulp-jade'
rename = require 'gulp-rename'
sass = require 'gulp-sass'
sourcemaps = require 'gulp-sourcemaps'
util = require 'gulp-util'
mocha = require 'gulp-mocha'
toArray = require 'stream-to-array'

# handles errors of a stream by ending it
handle = (stream) ->
  stream.on 'error', ->
    util.log.apply @, arguments
    do stream.end

out_folder = 'public'

test_glob = 'test/tests/*.coffee'
coffee_glob = 'assets/**/*.coffee'
sass_glob = 'assets/css/**/*.sass'

plugins_folder = 'plugins'
plugin_coffee_glob = "#{plugins_folder}/**/*.coffee"
plugin_js_glob = "#{plugins_folder}/**/*.js"
plugin_css_glob = "#{plugins_folder}/**/*.css"
plugin_sass_glob = "#{plugins_folder}/**/*.sass"
plugin_js_dst_path = "js/plugins"
plugin_js_dst = "#{out_folder}/#{plugin_js_dst_path}"
plugin_css_dst_path = "css/plugins"
plugin_css_dst = "#{out_folder}/#{plugin_css_dst_path}"

gulp.task 'clean', (cb) ->
  del ["#{out_folder}"], cb

gulp.task 'coffee', ->
  gulp.src coffee_glob
    .pipe sourcemaps.init()
    .pipe handle coffee()
    .pipe sourcemaps.write()
    .pipe gulp.dest "#{out_folder}"

gulp.task 'plugins_coffee', ->
  gulp.src plugin_coffee_glob, { base: plugins_folder }
    .pipe sourcemaps.init()
    .pipe handle coffee()
    .pipe sourcemaps.write()
    .pipe gulp.dest plugin_js_dst

gulp.task 'plugins_js', ->
  gulp.src plugin_js_glob, { base: plugins_folder }
    .pipe gulp.dest plugin_js_dst

gulp.task 'jade', () ->
    (promisify fs.readdir)("assets/js/definitions").then (definitions_js_files) ->
      definitions_js_filenames = definitions_js_files
        .filter (x) -> (x.match /\.coffee$/) or (x.match /\.js$/)
        .map (x) -> x.replace /\.coffee$/, '.js'

      plugin_js_files_stream = gulp.src [
        plugin_coffee_glob, plugin_js_glob
      ], { base: plugins_folder }

      plugin_css_files_stream = gulp.src [
        plugin_sass_glob, plugin_css_glob
      ], { base: plugins_folder }

      (toArray plugin_js_files_stream).then (plugin_js_files) ->
        plugin_js_filenames = plugin_js_files.map (x) ->
          x.relative.replace /\.coffee$/, '.js'

        (toArray plugin_css_files_stream).then (plugin_css_files) ->
          plugin_css_filenames = plugin_css_files.map (x) ->
            x.relative.replace /\.sass$/, '.css'

          stream = gulp.src 'assets/html/index.jade'
            .pipe handle jade({
              locals: {
                definitions_js_path: "js/definitions"
                definitions_js_files: definitions_js_filenames
                plugin_js_path: plugin_js_dst_path
                plugin_js_files: plugin_js_filenames
                plugin_css_path: plugin_css_dst_path
                plugin_css_files: plugin_css_filenames
              }
            })
            .pipe gulp.dest "#{out_folder}/"
          new Promise (resolve, reject) ->
            stream.on 'finish', resolve

gulp.task 'sass', ->
  gulp.src sass_glob, { base: 'assets/css' }
    .pipe sourcemaps.init()
    .pipe sass().on 'error', sass.logError
    .pipe sourcemaps.write()
    .pipe gulp.dest "#{out_folder}/css"

gulp.task 'plugins_sass', ->
  gulp.src plugin_sass_glob, { base: plugins_folder }
    .pipe sourcemaps.init()
    .pipe sass().on 'error', sass.logError
    .pipe sourcemaps.write()
    .pipe gulp.dest "#{out_folder}/css/plugins"

gulp.task 'plugins_css', ->
  gulp.src plugin_css_glob, { base: plugins_folder }
    .pipe gulp.dest plugin_css_dst

gulp.task 'images', ->
  gulp.src 'assets/images/*'
    .pipe gulp.dest "#{out_folder}/images"

gulp.task 'vendor', ->
  gulp.src 'vendor/**/*'
    .pipe gulp.dest "#{out_folder}/"
  gulp.src 'node_modules/lodash/index.js'
    .pipe rename "lodash.js"
    .pipe gulp.dest "#{out_folder}/"
  gulp.src 'node_modules/tv4/tv4.js'
    .pipe rename "tv4.js"
    .pipe gulp.dest "#{out_folder}/"

gulp.task 'plugins', [
  'plugins_coffee',
  'plugins_js',
  'plugins_sass',
  'plugins_css',
]

gulp.task 'assets', [
  'plugins',
  'coffee',
  'sass',
  'jade',
  'vendor',
  'images',
]

gulp.task 'test', () ->
  gulp.src test_glob, {read: false}
    .pipe mocha {reporter: 'dot', bail: true, compilers: 'coffee:coffee-script/register'}

# Rerun tasks when files changes
gulp.task 'watch', ->
  gulp.watch 'assets/html/**/*', ['jade']
  gulp.watch 'vendor/**/*', ['vendor']
  gulp.watch sass_glob, ['sass']
  gulp.watch coffee_glob, ['coffee', 'test']
  gulp.watch test_glob, ['test']

  gulp.watch plugin_coffee_glob, ['plugins_coffee', 'test']
  gulp.watch plugin_js_glob, ['plugins_js', 'test']
  gulp.watch plugin_sass_glob, ['plugins_sass']
  gulp.watch plugin_css_glob, ['plugins_css']
  # only needs to happen when set of files change
  gulp.watch plugins_folder, ['jade']


# serves an express app
gulp.task 'serve', ->
  app = express()
  app.use express.static "#{__dirname}/#{out_folder}"
  port = 8080 # TODO: make a way to specify?
  app.get '/:docname', ((req, res) -> res.sendFile "#{__dirname}/#{out_folder}/index.html")
  app.listen port
  console.log 'Started server on port ' + port

gulp.task 'default', ['clean'], () ->
  gulp.start 'assets', 'watch', 'serve', 'test'
