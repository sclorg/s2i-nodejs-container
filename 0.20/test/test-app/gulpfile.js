var gulp = require('gulp'),
    watch = require('gulp-watch'),
    shell = require('gulp-shell');

// For the oc rsync command to work, insert your pod id where POD-ID is.
// Note that if you're running multiple containers, you'll need to specify the
// right container with the -c flag. More information on how to do this can be found
// here: https://docs.openshift.org/latest/dev_guide/copy_files_to_container.html                                                 
gulp.task('rsync', shell.task(['oc rsync . POD-ID:/opt/app-root/src']));

gulp.task('default', function() {
    gulp.watch(['*.js'], ['rsync'])
});

