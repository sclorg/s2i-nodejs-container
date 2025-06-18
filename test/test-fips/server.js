const crypto = require('crypto');
var http = require('http');
var port = process.env.PORT || process.env.port || process.env.OPENSHIFT_NODEJS_PORT || 8080;
var ip = process.env.OPENSHIFT_NODEJS_IP || '0.0.0.0';
var server = http.createServer(function (req, res) {
    const fipsMode = getFipsMode();

	res.writeHead(200, {'Content-Type': 'text/plain'});
    verifySupportedHash(fipsMode);
	res.write('Hash generation succesfully verified\n');
    verifySupportedCiphers(fipsMode);
	res.write('Cipher generation succesfully verified\n');
	res.end('\n');

});
server.listen(port);
console.log('Server running on ' + ip + ':' + port);

/*
    * Return boolean value 
    * True if FIPS is enabled
    * False if Disabled
*/
function getFipsMode () {
    return !!crypto.getFips();
}

/*
    * Verify usage of FIPS supported hash algs
    * sha256 is FIPS supported
    * MLD isn't FIPS supported
*/
function verifySupportedHash(fipsMode) {
    try {
        const hashSha256 = crypto.createHash('sha256').update('FIPS test').digest('hex');
    } catch (e) {
        console.error("Error: SHA256 generation should be supported with FIPS.");
        exit.process(1);
    }
    try {
        crypto.createHash('md5').update('MD5 test').digest('hex');
        if (fipsMode) {
            console.error('Error: MD5 generation should not be suscessfull with FIPS enabled.');
            exit.process(1);
        }
    } catch (e) {
        if (!fipsMode) {
            console.error('Error: MD5 generation should pass without FIPS mode.');
            exit.process(1);
        }
    }
}

/*
    * Verify usage of FIPS supported ciphers
    * AES is FIPS supported
    * 3DES with only two keys isn't FIPS supported
*/
function verifySupportedCiphers(fipsMode) {
    try {
        const key = crypto.randomBytes(32); 
        const iv = crypto.randomBytes(16);  
        const plaintext = 'Test of AES encryption.';
        const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
        let encrypted = cipher.update(plaintext, 'utf8', 'hex');
        encrypted += cipher.final('hex');
    } catch (e) {
        console.error('Error: AES-256 generation should be supported with FIPS');
        process.exit(1);
    }
    try {
        const key = crypto.randomBytes(16); 
        const iv = crypto.randomBytes(8); 
        crypto.createCipheriv('des-ede-cbc', key, iv);

        if (fipsMode) {
            console.error("Error: 3DES generation shoud not be succesfull with FIPS mode.")
            process.exit(1);
        }
    } catch (e) {
        if (!fipsMode) {
            console.error('Error: 3DES generation should be successfull without FIPS mode.',e.message);
            process.exit(1);
        }
    }


}
