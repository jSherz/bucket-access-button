let plaintext_password = null;
let cloudFrontPrivateKey = null;

const KMS = require("aws-sdk/clients/kms");
const kms = new KMS({apiVersion: "2014-11-01"});

const crypto = require('crypto');

const BAD_REQUEST_RESPONSE = {
    statusCode: 400,
    body: JSON.stringify({
        error: "Bad request."
    })
};

const TWENTY_FOUR_HOURS = 60 * 60 * 24;

const decryptPassword = (callback) => {
    if (plaintext_password && cloudFrontPrivateKey) {
        console.log("Using previously decrypted password...");
        callback();
    } else {
        console.log("Decrypting password & CloudFront private key...");

        const params = {
            CiphertextBlob: new Buffer(process.env.ENCRYPTED_PASSWORD, 'base64')
        };

        kms.decrypt(params, (err, data) => {
            if (err) {
                console.error("Failed to decrypt password", err);
                throw err;
            } else {
                plaintext_password = data.Plaintext.toString();
                console.log("Decrypted and cached password...");

                const keyParams = {
                    CiphertextBlob: new Buffer(process.env.ENCRYPTED_CLOUDFRONT_PRIVATE_KEY, 'base64')
                };

                kms.decrypt(keyParams, (err, data) => {
                    if (err) {
                        console.error("Failed to decrypt private key", err);
                        throw err;
                    } else {
                        cloudFrontPrivateKey = data.Plaintext.toString();
                        console.log("Decrypted and cached private key...");

                        callback();
                    }
                });
            } // Mmmmm delicious callbacks
        });
    }
};

/**
 * Create a policy that allows access to our bucket's CloudFront domain.
 * 
 * See: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-setting-signed-cookie-canned-policy.html#private-content-canned-policy-signature-cookies
 * 
 * @param {*} expires Unix timestamp for expiry
 */
const makePolicy = (expires) => {
    const policy = JSON.stringify({
        Statement: [
            {
                Resource: `https://${process.env.CLOUDFRONT_DOMAIN_NAME}/*`,
                Condition: {
                    DateLessThan: {
                        "AWS:EpochTime": expires
                    }
                }
            }
        ]
    });

    console.log("Using policy", policy);

    return policy;
};

/**
 * Sign policy that allows access to our bucket's CloudFront domain.
 * 
 * See: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-setting-signed-cookie-canned-policy.html#private-content-canned-policy-signature-cookies
 * 
 * @param {*} expires Unix timestamp for expiry
 */
const makeSignature = (policy, expires) => {
    const signature = crypto.createSign('RSA-SHA1');
    signature.update(policy);

    return signature
        .sign(cloudFrontPrivateKey, 'base64')
        .replace(/\+/g, "-")
        .replace(/=/g, "_")
        .replace(/\//g, "~");
};

exports.handler = (event, context, callback) => {
    decryptPassword(() => {
        if (event.body) {
            const body = JSON.parse(event.body);

            if (body.password) {
                if (body.password === plaintext_password && plaintext_password !== null && plaintext_password !== "") {
                    const expires = Math.floor((new Date()).getTime() / 1000) + TWENTY_FOUR_HOURS;
                    const policy = makePolicy(expires);
                    const signature = makeSignature(policy, expires);
                    const keyPairId = process.env.CLOUDFRONT_KEYPAIR_ID;

                    callback(null, {
                        statusCode: 200,
                        headers: {
                            "Content-Type": "application/json"
                        },
                        body: JSON.stringify({
                            expires,
                            signature,
                            keyPairId,
                            policy: new Buffer(policy)
                                .toString("base64")
                                .replace(/\+/g, "-")
                                .replace(/=/g, "_")
                                .replace(/\//g, "~")
                        })
                    });
                } else {
                    console.error("Wrong password or it was set to null or an empty string.");
                    callback(null, {
                        statusCode: 401,
                        body: JSON.stringify({
                            error: "Unauthorized."
                        })
                    });
                }
            } else {
                console.error("No password in body!");
                callback(null, BAD_REQUEST_RESPONSE);
            }
        } else {
            console.error("No request body!");
            callback(null, BAD_REQUEST_RESPONSE);
        }
    });
};
