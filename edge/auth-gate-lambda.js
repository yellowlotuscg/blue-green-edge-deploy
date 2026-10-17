"use strict";

const { authGate } = require("./auth-gate");

// The verifier is a seam: production deployments should replace this decoder
// with Cognito JWKS signature/issuer/audience validation. Keeping it separate
// means the edge authorization matrix has no crypto or network dependency.
function verifyCognitoJwt(token) {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const claims = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
    return { valid: true, groups: claims["cognito:groups"] || [] };
  } catch (_) {
    return null;
  }
}

async function handler(event) {
  const request = event.Records[0].cf.request;
  const result = authGate(request, { verifyToken: verifyCognitoJwt });
  if (result.status === "200") return request;
  return { ...result, body: result.body ? { encoding: "text", data: result.body } : undefined };
}

module.exports = { handler, verifyCognitoJwt };
