gulp = require 'gulp'

babel = require 'gulp-babel'
browserify = require 'browserify'
coffee = require 'gulp-coffee'
del = require 'del'
express = require 'express'
jade = require 'gulp-jade'
rename = require 'gulp-rename'
sass = require 'gulp-sass'
sourcemaps = require 'gulp-sourcemaps'
util = require 'gulp-util'
mocha = require 'gulp-mocha'
uglify = require 'gulp-uglify'
streamify = require 'gulp-streamify'
toArray = require 'stream-to-array'
source = require 'vinyl-source-stream'
buffer = require 'vinyl-buffer'

require 'babel-core/register'

# handles errors of a stream by ending it
handle = (stream) ->
  stream.on 'error', ->
    util.log.apply @, arguments
    do stream.end

out_folder = 'public'

test_glob = 'test/tests/*.js'
js_glob = 'assets/**/*.js'
coffee_glob = 'assets/**/*.coffee'
sass_glob = 'assets/css/**/*.sass'

plugins_folder = 'plugins'
plugin_coffee_glob = "#{plugins_folder}/**/*.coffee"
plugin_js_glob = "#{plugins_folder}/**/*.js"
plugin_css_glob = "#{plugins_folder}/**/*.css"
plugin_sass_glob = "#{plugins_folder}/**/*.sass"
plugin_css_dst_path = "css/plugins"
plugin_css_dst = "#{out_folder}/#{plugin_css_dst_path}"

gulp.task 'clean', (cb) ->
  del ["#{out_folder}"], cb


jsTask = (isDev) ->
  # TODO get watchify to work..
  return () ->
    stream = browserify({
      entries: 'assets/js/index.coffee'
      transform: ['coffeeify', 'require-globify']
      debug: isDev
      insertGlobals: true
      detectGlobals: false
    }).bundle()
      .pipe source 'index.js'
      .pipe rename 'bundle.js'

    if not isDev
      stream = stream.pipe streamify do uglify

    stream
      .pipe gulp.dest "#{out_folder}/js"
      .pipe buffer()

gulp.task 'js:dev', jsTask(true)
gulp.task 'js:prod', jsTask(false)

htmlTask = (isDev) ->
  return () ->
    plugin_css_files_stream = gulp.src [
      plugin_sass_glob, plugin_css_glob
    ], { base: plugins_folder }

    (toArray plugin_css_files_stream).then (plugin_css_files) ->
      plugin_css_filenames = plugin_css_files.map (x) ->
        x.relative.replace /\.sass$/, '.css'

      stream = gulp.src 'assets/html/index.jade'
        .pipe handle jade({
          locals: {
            plugin_css_path: plugin_css_dst_path
            plugin_css_files: plugin_css_filenames
            use_cdn: not isDev
          }
        })
        .pipe gulp.dest "#{out_folder}/"
      new Promise (resolve, reject) ->
        stream.on 'finish', resolve
gulp.task 'html:dev', htmlTask(true)
gulp.task 'html:prod', htmlTask(false)

gulp.task 'css', ['main_css', 'plugins_sass', 'plugins_css']

gulp.task 'main_css', ->
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

gulp.task 'assets:dev', ['clean'], () ->
  gulp.start 'js:dev', 'css', 'html:dev', 'vendor', 'images',

gulp.task 'assets:prod', ['clean'], () ->
  gulp.start 'js:prod', 'css', 'html:prod', 'vendor', 'images',

gulp.task 'test', () ->
  gulp.src test_glob, {read: false}
    .pipe mocha {
      reporter: 'dot',
      bail: true,
      compilers: 'js:babel-core/register'
    }

# Rerun tasks when files changes
gulp.task 'watch', ->
  # technically, adding css plugin files could cause need to redo html..
  gulp.watch 'assets/html/**/*', ['html:dev']

  gulp.watch 'vendor/**/*', ['vendor']

  gulp.watch [sass_glob, plugin_sass_glob, plugin_css_glob], ['css']

  gulp.watch [coffee_glob, plugin_coffee_glob, plugin_js_glob], ['js:dev', 'test']

  gulp.watch test_glob, ['test']

# serves an express app
gulp.task 'serve', ->
  app = express()
  app.use express.static "#{__dirname}/#{out_folder}"
  port = 8080 # TODO: make a way to specify?
  app.get '/:docname', ((req, res) -> res.sendFile "#{__dirname}/#{out_folder}/index.html")
  app.listen port
  console.log 'Started server on port ' + port

gulp.task 'default', () ->
  gulp.start 'assets:dev', 'watch', 'serve', 'test'
