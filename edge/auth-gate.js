"use strict";

function headerValue(headers, name) {
  const values = headers && (headers[name] || headers[name.toLowerCase()]);
  if (!values) return undefined;
  return Array.isArray(values) ? values[0]?.value : values.value || values;
}

function isConfigRequest(uri) {
  return uri.endsWith(".config.json") || uri.startsWith("/admin/config");
}

function isAdminRequest(uri) {
  return uri.startsWith("/admin");
}

function authGate(request, options = {}) {
  const uri = request.uri || "/";
  if (isConfigRequest(uri)) return { status: "404", statusDescription: "Not Found", body: "Not Found" };
  if (!isAdminRequest(uri)) return { status: "200", statusDescription: "OK", request };

  const authorization = headerValue(request.headers, "authorization");
  if (!authorization || !/^Bearer\s+[^\s]+$/i.test(authorization)) {
    return { status: "401", statusDescription: "Unauthorized", headers: { "www-authenticate": [{ key: "WWW-Authenticate", value: "Bearer" }] } };
  }
  const token = authorization.replace(/^Bearer\s+/i, "");
  let claims;
  try {
    claims = (options.verifyToken || (() => null))(token);
  } catch (_) {
    claims = null;
  }
  const groups = claims && Array.isArray(claims.groups) ? claims.groups : [];
  if (!claims || claims.valid === false || !groups.includes("admins")) {
    return { status: "403", statusDescription: "Forbidden", body: "Forbidden" };
  }
  return { status: "200", statusDescription: "OK", request, claims };
}

module.exports = { authGate, isConfigRequest, isAdminRequest };
