import gulp from 'gulp';

import del from 'del';
import express from 'express';
import jade from 'gulp-jade';
import util from 'gulp-util';
import mocha from 'gulp-mocha';
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

gulp.task('clean', cb => del([`${out_folder}`], cb));

let htmlTask = (/* isDev */) => {
  return gulp.src('assets/html/index.jade')
    .pipe(handle(jade({})))
    .pipe(gulp.dest(`${out_folder}/`));
};
gulp.task('html:dev', htmlTask(true));
gulp.task('html:prod', htmlTask(false));

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
