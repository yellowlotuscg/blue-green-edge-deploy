"use strict";

function routeRequest(request, activeColor) {
  const color = String(activeColor || "").replace(/\/$/, "");
  if (!/^(blue|green)$/.test(color)) throw new Error("active color must be blue or green");
  const uri = request.uri || "/";
  const suffix = uri === "/" ? "/app/index.html" : uri.startsWith("/") ? uri : `/${uri}`;
  return { ...request, uri: `/${color}${suffix}` };
}

module.exports = { routeRequest };
