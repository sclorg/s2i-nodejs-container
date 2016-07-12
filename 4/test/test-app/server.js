var util = require('util');
var http = require('http');
var url = require('url');
var qs = require('querystring');
var os = require('os')
var port = process.env.PORT || process.env.port || process.env.OPENSHIFT_NODEJS_PORT || 8080;
var ip = process.env.OPENSHIFT_NODEJS_IP || '0.0.0.0';
var nodeEnv = process.env.NODE_ENV || 'unknown';
var server = http.createServer(function (req, res) {
	var url_parts = url.parse(req.url, true);

	var body = '';
	req.on('data', function (data) {
		body += data;
	});
	req.on('end', function () {
		var formattedBody = qs.parse(body);

		res.writeHead(200, {'Content-Type': 'text/plain'});

		res.write('This is a node.js echo service\n');
		res.write('Host: ' + req.headers.host + '\n');
		res.write('\n');
		res.write('node.js Production Mode: ' + (nodeEnv == 'production' ? 'yes' : 'no') + '\n');
		res.write('\n');
		res.write('HTTP/' + req.httpVersion +'\n');
		res.write('Request headers:\n');
		res.write(util.inspect(req.headers, null) + '\n');
		res.write('Request query:\n');
		res.write(util.inspect(url_parts.query, null) + '\n');
		res.write('Request body:\n');
		res.write(util.inspect(formattedBody, null) + '\n');
		res.write('\n');
		res.write('Host: ' + os.hostname() + '\n');
		res.write('OS Type: ' + os.type() + '\n');
		res.write('OS Platform: ' + os.platform() + '\n');
		res.write('OS Arch: ' + os.arch() + '\n');
		res.write('OS Release: ' + os.release() + '\n');
		res.write('OS Uptime: ' + os.uptime() + '\n');
		res.write('OS Free memory: ' + os.freemem() / 1024 / 1024 + 'mb\n');
		res.write('OS Total memory: ' + os.totalmem() / 1024 / 1024 + 'mb\n');
		res.write('OS CPU count: ' + os.cpus().length + '\n');
		res.write('OS CPU model: ' + os.cpus()[0].model + '\n');
		res.write('OS CPU speed: ' + os.cpus()[0].speed + 'mhz\n');
		res.end('\n');

	});
});
server.listen(port);
console.log('Server running on ' + ip + ':' + port);
