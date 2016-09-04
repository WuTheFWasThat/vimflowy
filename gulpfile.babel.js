import gulp from 'gulp';

import mocha from 'gulp-mocha';
import plumber from 'gulp-plumber';

import 'babel-core/register';

gulp.task('test', () =>
  gulp.src('test/tests/*.js', {read: false})
    .pipe(plumber())
    .pipe(mocha({
      reporter: 'dot',
      bail: true,
      compilers: 'js:babel-core/register'
    }))
);

// Rerun tasks when files changes
gulp.task('watch', function() {
  gulp.watch(['assets/**/*', 'plugins/**/*', 'test/**/*'], ['test']);
});

gulp.task('default', () => gulp.start('watch', 'test'));
