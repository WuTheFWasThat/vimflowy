gulp = require 'gulp'

coffee = require 'gulp-coffee'
del = require 'del'
express = require 'express'
jade = require 'gulp-jade'
rename = require 'gulp-rename'
sass = require 'gulp-sass'
sourcemaps = require 'gulp-sourcemaps'
util = require 'gulp-util'
watch = require 'gulp-watch'

out_folder = 'public'

# handles errors of a stream by ending it
handle = (stream) ->
  stream.on 'error', ->
    util.log.apply @, arguments
    do stream.end

gulp.task 'clean', (cb) ->
  del ["#{out_folder}"], cb

gulp.task 'coffee', ->
  gulp.src 'assets/js/*.coffee'
    .pipe sourcemaps.init()
    .pipe handle coffee()
    .pipe sourcemaps.write()
    .pipe gulp.dest "#{out_folder}/js"

gulp.task 'jade', ->
  gulp.src 'views/index.jade'
    .pipe handle jade({})
    .pipe gulp.dest "#{out_folder}/"

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

gulp.task 'vendor', ->
  gulp.src 'vendor/*'
    .pipe gulp.dest "#{out_folder}/"
  gulp.src 'node_modules/lodash/index.js'
    .pipe rename "lodash.js"
    .pipe gulp.dest "#{out_folder}/"

gulp.task 'fonts', ->
  gulp.src 'assets/fonts/*'
    .pipe gulp.dest "#{out_folder}/fonts"

gulp.task 'images', ->
  gulp.src 'assets/images/*'
    .pipe gulp.dest "#{out_folder}/images"

gulp.task 'assets', [
  'coffee',
  'sass',
  'jade',
  'vendor',
  'fonts',
  'images',
]

# Rerun tasks when files changes
# TODO: use gulp-watch?
gulp.task 'watch', ->
  gulp.watch 'assets/css/**/*', ['sass']
  gulp.watch 'views/**/*', ['jade']
  gulp.watch 'assets/js/**/*', ['coffee']

# serves an express app
gulp.task 'serve', ->
  app = express()
  app.use express.static(__dirname + '/public')
  port = process.argv[2] or 8080
  app.listen port
  console.log 'Started server on port ' + port

gulp.task 'default', ['clean'], () ->
  gulp.start 'assets', 'watch', 'serve'
