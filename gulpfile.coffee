gulp = require 'gulp'
fs = require 'fs'

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

out_folder = 'public'

# handles errors of a stream by ending it
handle = (stream) ->
  stream.on 'error', ->
    util.log.apply @, arguments
    do stream.end

test_files = 'test/tests/*.coffee'
coffee_files = 'assets/**/*.coffee'

gulp.task 'clean', (cb) ->
  del ["#{out_folder}"], cb

gulp.task 'coffee', ->
  gulp.src coffee_files
    .pipe sourcemaps.init()
    .pipe handle coffee()
    .pipe sourcemaps.write()
    .pipe gulp.dest "#{out_folder}"
  gulp.src 'plugins/**/*.coffee', { base: 'plugins' }
    .pipe sourcemaps.init()
    .pipe handle coffee()
    .pipe sourcemaps.write()
    .pipe gulp.dest "#{out_folder}/js/plugin"

gulp.task 'js', ->
  gulp.src 'plugins/**/*.js', { base: 'plugins' }
    .pipe gulp.dest "#{out_folder}/js/plugin"

gulp.task 'jade', () ->
    stream = gulp.src ["plugins/**/*.coffee", "plugins/**/*.js"], { base: 'plugins' }
    (toArray stream).then (pluginSourceFiles) ->
      pluginJsFiles = pluginSourceFiles.map (x) ->
        x.relative.replace /\.coffee$/, '.js'
      stream = gulp.src 'assets/html/index.jade'
        .pipe handle jade({
          locals: {pluginJsFiles: pluginJsFiles}
        })
        .pipe gulp.dest "#{out_folder}/"
      new Promise (resolve, reject) ->
        stream.on 'finish', resolve

gulp.task 'sass', ->
  gulp.src 'assets/css/*.sass'
    .pipe sourcemaps.init()
    .pipe sass().on 'error', sass.logError
    .pipe sourcemaps.write()
    .pipe gulp.dest "#{out_folder}/css"

  gulp.src 'assets/css/themes/*.sass'
    .pipe sourcemaps.init()
    .pipe sass().on 'error', sass.logError
    .pipe sourcemaps.write()
    .pipe gulp.dest "#{out_folder}/css/themes"

gulp.task 'images', ->
  gulp.src 'assets/images/*'
    .pipe gulp.dest "#{out_folder}/images"

gulp.task 'vendor', ->
  gulp.src 'vendor/**/*'
    .pipe gulp.dest "#{out_folder}/"
  gulp.src 'node_modules/lodash/index.js'
    .pipe rename "lodash.js"
    .pipe gulp.dest "#{out_folder}/"

gulp.task 'assets', [
  'js',
  'coffee',
  'sass',
  'jade',
  'vendor',
  'images',
]

gulp.task 'test', () ->
  gulp.src test_files, {read: false}
    .pipe mocha {reporter: 'dot', bail: true, compilers: 'coffee:coffee-script/register'}

# Rerun tasks when files changes
gulp.task 'watch', ->
  gulp.watch 'assets/css/**/*', ['sass']
  gulp.watch 'assets/html/**/*', ['jade']
  gulp.watch 'vendor/**/*', ['vendor']
  gulp.watch 'plugins/**/*.js', ['js', 'jade']
  gulp.watch 'plugins/**/*.coffee', ['coffee', 'jade']
  gulp.watch coffee_files, ['coffee', 'test']
  gulp.watch test_files, ['test']

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
