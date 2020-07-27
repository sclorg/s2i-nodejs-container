FROM registry.access.redhat.com/ubi8/nodejs-12

# Add application sources
ADD app-src .

# Install the dependencies
RUN npm install

# Run script uses standard ways to run the application
CMD npm run -d start
