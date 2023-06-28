FROM registry.access.redhat.com/ubi8/nodejs-14

# Add application sources
ADD app-src .

# In case you run into permission errors during build (eg. by use of umask)
# running the fix-permission script will make sure all bits are as expected by the image
# USER 0
# RUN fix-permissions ./
# USER 1001

# Install the dependencies
RUN npm install

# Run script uses standard ways to run the application
CMD npm run -d start
