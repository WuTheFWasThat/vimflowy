import gulp from 'gulp';

import browserify from 'browserify';
import babelify from 'babelify';
import del from 'del';
import express from 'express';
import jade from 'gulp-jade';
import rename from 'gulp-rename';
import sass from 'gulp-sass';
import sourcemaps from 'gulp-sourcemaps';
import util from 'gulp-util';
import mocha from 'gulp-mocha';
import uglify from 'gulp-uglify';
import streamify from 'gulp-streamify';
import toArray from 'stream-to-array';
import source from 'vinyl-source-stream';
import buffer from 'vinyl-buffer';
import plumber from 'gulp-plumber';

import 'babel-core/register';

// handles errors of a stream by ending it
let handle = (stream) => {
  return stream.on('error', function() {
    util.log.apply(this, arguments);
    return stream.end();
  });
};

let out_folder = 'public';

let test_glob = 'test/tests/*.js';
let js_glob = 'assets/**/*.js';
let sass_glob = 'assets/css/**/*.sass';

let plugins_folder = 'plugins';
let plugin_js_glob = `${plugins_folder}/**/*.js`;
let plugin_css_glob = `${plugins_folder}/**/*.css`;
let plugin_sass_glob = `${plugins_folder}/**/*.sass`;
let plugin_css_dst_path = 'css/plugins';
let plugin_css_dst = `${out_folder}/${plugin_css_dst_path}`;

gulp.task('clean', cb => del([`${out_folder}`], cb));


let jsTask = (isDev) => {
  return function() {
    const browserifyOpts = {
      entries: 'assets/js/index',
      ignore: /node_modules/,
      transform: [
        babelify.configure({
          presets: ['es2015', 'react', 'stage-3'],
          plugins: ['transform-runtime'],
        }),
      ],
      plugin: [],
      debug: isDev,
      insertGlobals: true,
      detectGlobals: false
    };

    if (isDev) {
      browserifyOpts.plugin.push(require('watchify'));
    }

    let b = browserify(browserifyOpts);

    function bundle() {
      let stream = b.bundle();
      if (isDev) {
        stream = stream.pipe(plumber());
      }

      stream = stream
        .pipe(source('index.js'))
        .pipe(rename('bundle.js'));

      if (!isDev) {
        stream = stream.pipe(streamify(uglify()));
      }

      return stream
        .pipe(gulp.dest(`${out_folder}/js`))
        .pipe(buffer());
    }

    b.on('update', function (files) {
      console.log('Updating', files);
      bundle();
    });

    return bundle();
  };
};

gulp.task('js:dev', jsTask(true));
gulp.task('js:prod', jsTask(false));

let htmlTask = (/* isDev */) => {
  return function() {
    let plugin_css_files_stream = gulp.src([
      plugin_sass_glob, plugin_css_glob
    ], { base: plugins_folder });

    return (toArray(plugin_css_files_stream)).then(function(plugin_css_files) {
      let plugin_css_filenames = plugin_css_files.map(x => x.relative.replace(/\.sass$/, '.css'));

      let stream = gulp.src('assets/html/index.jade')
        .pipe(handle(jade({
          locals: {
            plugin_css_path: plugin_css_dst_path,
            plugin_css_files: plugin_css_filenames,
          }
        })))
        .pipe(gulp.dest(`${out_folder}/`));
      return new Promise((resolve) => stream.on('finish', resolve));
    });
  };
};
gulp.task('html:dev', htmlTask(true));
gulp.task('html:prod', htmlTask(false));

gulp.task('css', ['main_css', 'plugins_sass', 'plugins_css']);

gulp.task('main_css', () =>
  gulp.src(sass_glob, { base: 'assets/css' })
    .pipe(sourcemaps.init())
    .pipe(sass().on('error', sass.logError))
    .pipe(sourcemaps.write())
    .pipe(gulp.dest(`${out_folder}/css`))

);

gulp.task('plugins_sass', () =>
  gulp.src(plugin_sass_glob, { base: plugins_folder })
    .pipe(sourcemaps.init())
    .pipe(sass().on('error', sass.logError))
    .pipe(sourcemaps.write())
    .pipe(gulp.dest(`${out_folder}/css/plugins`))
);

gulp.task('plugins_css', () =>
  gulp.src(plugin_css_glob, { base: plugins_folder })
    .pipe(gulp.dest(plugin_css_dst))
);

gulp.task('images', () =>
  gulp.src('assets/images/*')
    .pipe(gulp.dest(`${out_folder}/images`))
);

gulp.task('vendor', () =>
  gulp.src('vendor/**/*')
    .pipe(gulp.dest(`${out_folder}/`))
);

gulp.task('assets:dev', ['clean'], () => gulp.start('js:dev', 'css', 'html:dev', 'vendor', 'images'));

gulp.task('assets:prod', ['clean'], () => gulp.start('js:prod', 'css', 'html:prod', 'vendor', 'images'));

gulp.task('test', () =>
  gulp.src(test_glob, {read: false})
    .pipe(plumber())
    .pipe(mocha({
      reporter: 'dot',
      bail: true,
      compilers: 'js:babel-core/register'
    }))
);

// Rerun tasks when files changes
gulp.task('watch', function() {
  // technically, adding css plugin files could cause need to redo html..
  gulp.watch('assets/html/**/*', ['html:dev']);

  gulp.watch('vendor/**/*', ['vendor']);

  gulp.watch([sass_glob, plugin_sass_glob, plugin_css_glob], ['css']);

  gulp.watch([js_glob, plugin_js_glob, 'test/testcase.js'], ['test']);
  // js:dev reruns via watchify

  return gulp.watch(test_glob, ['test']);
});

// serves an express app
gulp.task('serve', function() {
  let app = express();
  app.use(express.static(`${__dirname}/${out_folder}`));
  let port = 8080; // TODO: make a way to specify?
  app.get('/:docname', ((req, res) => res.sendFile(`${__dirname}/${out_folder}/index.html`)));
  app.listen(port);
  return console.log(`Started server on port ${port}`);
});

gulp.task('default', () => gulp.start('assets:dev', 'watch', 'serve', 'test'));
