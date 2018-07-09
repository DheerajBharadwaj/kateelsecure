FROM alpine:3.7

MAINTAINER Durga Devotee "devotee@kateel.temple"

ENV NGINX_VERSION 1.14.0
ENV MODSEC_CRS_VERSION v3.0.2

#RUN apt-get clean && apt-get update
RUN GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
        && CONFIG="\
                --prefix=/etc/nginx \
                --sbin-path=/usr/sbin/nginx \
                --modules-path=/usr/lib/nginx/modules \
                --conf-path=/etc/nginx/nginx.conf \
                --error-log-path=/var/log/nginx/error.log \
                --http-log-path=/var/log/nginx/access.log \
                --pid-path=/var/run/nginx.pid \
                --lock-path=/var/run/nginx.lock \
                --http-client-body-temp-path=/var/cache/nginx/client_temp \
                --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
                --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
                --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
                --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
                --user=nginx \
                --group=nginx \
                --with-http_ssl_module \
                --with-http_realip_module \
                --with-http_addition_module \
                --with-http_sub_module \
                --with-http_dav_module \
                --with-http_flv_module \
                --with-http_mp4_module \
                --with-http_gunzip_module \
                --with-http_gzip_static_module \
                --with-http_random_index_module \
                --with-http_secure_link_module \
                --with-http_stub_status_module \
                --with-http_auth_request_module \
                --with-http_xslt_module=dynamic \
                --with-http_image_filter_module=dynamic \
                --with-http_geoip_module=dynamic \
                --with-http_perl_module=dynamic \
                --with-threads \
                --with-stream \
                --with-stream_ssl_module \
                --with-stream_ssl_preread_module \
                --with-stream_realip_module \
                --with-stream_geoip_module=dynamic \
                --with-http_slice_module \
                --with-mail \
                --with-mail_ssl_module \
                --with-compat \
                --with-file-aio \
                --with-http_v2_module \
                --add-module=/usr/src/ModSecurity-nginx \
        " \
        && addgroup -S nginx \
        && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
        && apk add --no-cache --virtual .build-deps \
                gcc \
                libc-dev \
                make \
                openssl-dev \
                pcre-dev \
                zlib-dev \
                linux-headers \
                curl \
                gnupg \
                libxslt-dev \
                gd-dev \
                geoip-dev \
                perl-dev \
        && apk add --no-cache --virtual .libmodsecurity-deps \
                pcre-dev \
                libxml2-dev \
                git \
                libtool \
                automake \
                autoconf \
                g++ \
                flex \
                bison \
                yajl-dev \
        # Add runtime dependencies that should not be removed
        && apk add --no-cache \
                yajl \
                libstdc++ \
        && curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
        && curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
        && export GNUPGHOME="$(mktemp -d)" \
        && gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys "$GPG_KEYS" \
        && gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
        && rm -r "$GNUPGHOME" nginx.tar.gz.asc \
        && mkdir -p /usr/src \
        && tar -zxC /usr/src -f nginx.tar.gz \
        && rm nginx.tar.gz \
        && cd /usr/src \
        && git clone https://github.com/SpiderLabs/ModSecurity \
        && cd ModSecurity \
        && git checkout v3/master \
        && git submodule init \
        && git submodule update \
        && sed -i -e 's/u_int64_t/uint64_t/g' \
                ./src/actions/transformations/html_entity_decode.cc \
                ./src/actions/transformations/html_entity_decode.h \
                ./src/actions/transformations/js_decode.cc \
                ./src/actions/transformations/js_decode.h \
                ./src/actions/transformations/parity_even_7bit.cc \
                ./src/actions/transformations/parity_even_7bit.h \
                ./src/actions/transformations/parity_odd_7bit.cc \
                ./src/actions/transformations/parity_odd_7bit.h \
                ./src/actions/transformations/parity_zero_7bit.cc \
                ./src/actions/transformations/parity_zero_7bit.h \
                ./src/actions/transformations/remove_comments.cc \
                ./src/actions/transformations/url_decode_uni.cc \
                ./src/actions/transformations/url_decode_uni.h \
        && sh build.sh \
        && ./configure \
        && make \
        && make install \
        && cd /usr/src \
        && git clone https://github.com/SpiderLabs/ModSecurity-nginx \
        && cd /usr/src/nginx-$NGINX_VERSION \
        && ./configure $CONFIG --with-debug \
        && make -j$(getconf _NPROCESSORS_ONLN) \
        && mv objs/nginx objs/nginx-debug \
        && mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
        && mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
        && mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
        && mv objs/ngx_http_perl_module.so objs/ngx_http_perl_module-debug.so \
        && mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
        && ./configure $CONFIG \
        && make -j$(getconf _NPROCESSORS_ONLN) \
        && make install \
        && rm -rf /etc/nginx/html/ \
        && mkdir /etc/nginx/conf.d/ \
        && mkdir -p /usr/share/nginx/html/ \
        && install -m644 html/index.html /usr/share/nginx/html/ \
        && install -m644 html/50x.html /usr/share/nginx/html/ \
        && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
        && install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
        && install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
        && install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
        && install -m755 objs/ngx_http_perl_module-debug.so /usr/lib/nginx/modules/ngx_http_perl_module-debug.so \
        && install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
        && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
        && strip /usr/sbin/nginx* \
        && strip /usr/lib/nginx/modules/*.so \
        && rm -rf /usr/src/nginx-$NGINX_VERSION \
        \
        # Bring in gettext so we can get `envsubst`, then throw
        # the rest away. To do this, we need to install `gettext`
        # then move `envsubst` out of the way so `gettext` can
        # be deleted completely, then move `envsubst` back.
        && apk add --no-cache --virtual .gettext gettext \
        && mv /usr/bin/envsubst /tmp/ \
        \
        && runDeps="$( \
                scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
                        | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
                        | sort -u \
                        | xargs -r apk info --installed \
                        | sort -u \
        )" \
        && apk add --no-cache --virtual .nginx-rundeps $runDeps \
        && apk del .build-deps \
        && apk del .libmodsecurity-deps \
        && apk del .gettext \
        && mv /tmp/envsubst /usr/local/bin/ \
        && rm -rf /usr/src/ModSecurity /usr/src/ModSecurity-nginx \
        \
        # forward request and error logs to docker log collector
        && ln -sf /dev/stdout /var/log/nginx/access.log \
        && ln -sf /dev/stderr /var/log/nginx/error.log

# Start of Geo IP
#RUN apk add geoipupdate
RUN mkdir /etc/nginx/geoip
WORKDIR /etc/nginx/geoip
RUN wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
RUN wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz
RUN gunzip GeoIP.dat.gz
RUN gunzip GeoLiteCity.dat.gz
RUN mkdir /www
RUN mkdir /www/data
COPY IN.html /www/data/IN.html
COPY US.html /www/data/US.html
# Note nginx.conf is modified for Geo
COPY nginx.conf /etc/nginx/nginx.conf
COPY nginx.vh.default.conf /etc/nginx/conf.d/default.conf
# End of Geo IP

#MOD SECURITY RULES START
COPY proxy.conf /etc/nginx/conf.d/proxy.conf
COPY echo.conf /etc/nginx/conf.d/echo.conf
RUN mkdir /etc/nginx/modsec
# What is working directory for wget and mv
WORKDIR /etc/nginx/modsec
RUN wget https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended
RUN mv modsecurity.conf-recommended modsecurity.conf
COPY main.conf /etc/nginx/modsec/main.conf
RUN wget https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v3.0.2.tar.gz
RUN  tar -xzvf v3.0.2.tar.gz
RUN  mv owasp-modsecurity-crs-3.0.2 /usr/local
WORKDIR  /usr/local/owasp-modsecurity-crs-3.0.2
RUN  cp crs-setup.conf.example crs-setup.conf
RUN  cp crs-setup.conf.example /etc/nginx/modsec/crs-setup.conf
#MOD SECURITY RULES END

# Commented out as this is done above
#COPY nginx.conf /etc/nginx/nginx.conf
#COPY nginx.vh.default.conf /etc/nginx/conf.d/default.conf

RUN ls -l /etc/nginx/modsec
RUN ls -l /usr/local/owasp-modsecurity-crs-3.0.2
RUN nginx -V
RUN nginx -V 2>&1 | grep -- 'http_geoip_module'
RUN nginx -V 2>&1 | grep -- 'stream_geoip_module'
RUN nginx -t

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
