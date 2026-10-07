ARG  BASE_IMAGE=debian:latest
FROM ${BASE_IMAGE}

ARG NGINX_VER
ARG NGINX_FLAVOR=nginx
ARG INSTALL_TYPE
ARG SSL
ARG HTTP3=n
ARG VTS=n
ARG DEBIAN_FRONTEND=noninteractive

COPY . .

RUN bash -x .github/workflows/docker/wrapper.sh

RUN nginx -V

RUN nginx -t
