# Pin the upstream node version for reproducible Railway/VPS deployments.
# Override at build time when upgrading: --build-arg PASARGUARD_NODE_IMAGE=pasarguard/node:vX.Y.Z
ARG PASARGUARD_NODE_IMAGE=pasarguard/node:v0.5.4
FROM ${PASARGUARD_NODE_IMAGE}

# The upstream image contains the node binary and runtime dependencies.
# OpenSSL is used by the bootstrap to create a self-signed internal cert.
# Nginx exposes a cleartext HTTP/2 gRPC bridge for Hostim's HTTP ingress.
RUN apk add --no-cache openssl nginx

COPY entrypoint.sh /entrypoint.sh
COPY nginx-hostim.conf /etc/nginx/http.d/hostim-grpc.conf
RUN chmod 0755 /entrypoint.sh

# Hostim routes its public HTTPS domain to this HTTP port. The PasarGuard node
# stays on SERVICE_PORT behind the local Nginx gRPC bridge.
ENV NODE_HOST=0.0.0.0 \
    SERVICE_PORT=62050 \
    PORT=8080 \
    HOSTIM_HTTP_BRIDGE=true \
    SSL_CERT_FILE=/var/lib/pg-node/certs/ssl_cert.pem \
    SSL_KEY_FILE=/var/lib/pg-node/certs/ssl_key.pem \
    GENERATED_CONFIG_PATH=/var/lib/pg-node/generated \
    SERVICE_PROTOCOL=grpc

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
