import gulp from 'gulp';

import del from 'del';
import mocha from 'gulp-mocha';
import plumber from 'gulp-plumber';

import 'babel-core/register';

let out_folder = 'public';

let test_glob = 'test/tests/*.js';

gulp.task('clean', cb => del([`${out_folder}`], cb));

gulp.task('images', () =>
  gulp.src('assets/images/*')
    .pipe(gulp.dest(`${out_folder}/images`))
);

gulp.task('vendor', () =>
  gulp.src('vendor/**/*')
    .pipe(gulp.dest(`${out_folder}/`))
);

gulp.task('assets:dev', ['clean'], () => gulp.start('js:dev', 'css', 'vendor', 'images'));

gulp.task('assets:prod', ['clean'], () => gulp.start('js:prod', 'css', 'vendor', 'images'));

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
  gulp.watch('vendor/**/*', ['vendor']);

  gulp.watch(['assets/**/*', 'plugins/**/*', 'test/**/*'], ['test']);
  // js:dev reruns via watchify

  return gulp.watch(test_glob, ['test']);
});

gulp.task('default', () => gulp.start('assets:dev', 'watch', 'test'));
