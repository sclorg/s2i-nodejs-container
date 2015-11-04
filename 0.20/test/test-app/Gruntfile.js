module.exports = function(grunt) {

    grunt.initConfig({
        shell: {
            target: {
                // For the oc rsync command to work, insert your pod id where POD-ID is.
                // Note that if you're running multiple containers, you'll need to specify the
                // right container with the -c flag. More information on how to do this can be found
                // here: https://docs.openshift.org/latest/dev_guide/copy_files_to_container.html
                command: "oc rsync . POD-ID:/opt/app-root/src"
            }
        },
        watch: {
            files: ['server.js'],
            tasks: ['shell']
        }
    });

    grunt.loadNpmTasks('grunt-contrib-watch');
    grunt.loadNpmTasks('grunt-shell');

    grunt.registerTask('default', ['watch']);

};
