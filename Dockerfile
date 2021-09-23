FROM docker.io/bitnami/python:3.9-prod AS python

RUN mkdir -p /var/lib/apt/lists/partial && \
  install_packages wget \
  gcc \
  git \
  sed \
  make \
  build-essential \
  procps \
  sysstat \
  libldap2-dev \
  # libpython-dev \
  libreadline-dev \
  libssl-dev \
  bison \
  flex \
  libghc-zlib-dev \
  libcrypto++-dev \
  libxml2-dev \
  libxslt1-dev \
  bzip2 \
  unzip \
  libgeos-dev \
  libproj-dev \
  libgdal-dev \
  zlib1g-dev \
  libncurses5-dev \
  libgdbm-dev \
  libnss3-dev \
  libsqlite3-dev \
  libffi-dev \
  libbz2-dev \
  libprotobuf-c1 \
  libprotobuf-c-dev \
  protobuf-c-compiler

ENV POSTGRES_VERSION 13.4
RUN wget -O /tmp/postgres.tar.gz "https://ftp.postgresql.org/pub/source/v${POSTGRES_VERSION}/postgresql-${POSTGRES_VERSION}.tar.gz"
RUN cd /tmp \
  && tar zxf postgres.tar.gz \
  && cd postgresql-${POSTGRES_VERSION} \
  # && cd src/pl/plpython \
  && export C_INCLUDE_PATH=/opt/bitnami/postgresql/include/:/opt/bitnami/common/include/ \
  && export LIBRARY_PATH=/opt/bitnami/postgresql/lib/:/opt/bitnami/common/lib/ \
  && export LD_LIBRARY_PATH=/opt/bitnami/postgresql/lib/:/opt/bitnami/common/lib/ \
  && ./configure \
  --enable-integer-datetimes \
  --enable-thread-safety \
  # --with-pgport=5432 \
  # --prefix=/opt/bitnami/postgresql \
  --with-ldap \
  --with-python \
  --with-openssl \
  --with-libxml \
  --with-libxslt \
  # --datadir=/bitnami/postgresql/data \
  # --sysconfdir=/bitnami/postgresql/conf \
  # --with-gssapi \
  # --with-perl \
  # --with-tcl \
  # --with-pam \
  # --with-system-tzdata=/usr/share/zoneinfo \
  # --with-uuid=e2fs \
  --with-icu \
  # --with-systemd \
  # --with-llvm \
  # --enable-nls \
  && make -j $(nproc) world-bin \
  && make install-world-bin

# FROM postgres:13.4 AS extensions

# RUN \
#     apt-get update && \
#     apt-get upgrade -y && \
#     apt-get install -y --no-install-recommends \
#     postgresql-contrib \
#     postgresql-plpython3-13 \
#     postgresql-plpython3-13-dbgsym

FROM bitnami/postgresql:13 AS plv8

USER root

ENV PLV8_VERSION=3.0.0
ENV PG_MAJOR 13

RUN mkdir -p /var/lib/apt/lists/partial

RUN buildDependencies="build-essential \
  ca-certificates \
  curl \
  git \
  gnupg2 \
  lsb-release \
  apt-utils \
  python \
  python3 \
  gpp \
  cpp \
  pkg-config \
  apt-transport-https \
  cmake \
  libc++-dev \
  libc++abi-dev \
  libpq-dev \
  libglib2.0-dev \
  postgresql-server-dev-$PG_MAJOR" \
  && runtimeDependencies="libc++1 \
  libtinfo5 \
  libc++abi1" \
  && apt-get update \
  && apt-get install lsb-release gnupg2 -y \
  && curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
  && echo "deb http://apt.postgresql.org/pub/repos/apt `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list \
  && apt-get update \
  && apt-get install libpq-dev cmake -y \
  && apt-get update \
  && apt-get install -y --no-install-recommends ${buildDependencies} ${runtimeDependencies} \
  && mkdir -p /tmp/build \
  && curl -o /tmp/build/v$PLV8_VERSION.tar.gz -SL "https://github.com/plv8/plv8/archive/v${PLV8_VERSION}.tar.gz" \
  && cd /tmp/build \
  # && echo $PLV8_SHASUM v$PLV8_VERSION.tar.gz | sha256sum -c \
  && tar -xzf /tmp/build/v$PLV8_VERSION.tar.gz -C /tmp/build/ \
  && cd /tmp/build/plv8-$PLV8_VERSION \
  && export C_INCLUDE_PATH=/opt/bitnami/postgresql/include/:/opt/bitnami/common/include/ \
  && export LIBRARY_PATH=/opt/bitnami/postgresql/lib/:/opt/bitnami/common/lib/ \
  && export LD_LIBRARY_PATH=/opt/bitnami/postgresql/lib/:/opt/bitnami/common/lib/ \
  && make -j $(nproc) PG_CONFIG=/opt/bitnami/postgresql/bin/pg_config static \
  && make install \
  && strip /opt/bitnami/postgresql/lib/plv8-${PLV8_VERSION}.so \
  && rm -rf /root/.vpython_cipd_cache /root/.vpython-root \
  && apt-get clean \
  && apt-get remove -y ${buildDependencies} \
  && apt-get autoremove -y \
  && rm -rf /tmp/build /var/lib/apt/lists/*

FROM bitnami/postgresql:13

USER root

## Copy python files into the final image
COPY --from=python /opt/bitnami/ /opt/bitnami/

ENV PATH="/opt/bitnami/python/bin:$PATH"

## Copy plpython related files into the final image
COPY --from=python /usr/local/pgsql/share/extension/*python* /opt/bitnami/postgresql/share/extension/
COPY --from=python /usr/local/pgsql/lib/*python* /opt/bitnami/postgresql/lib/

## Copy the plv8 extension and lib into the final image
COPY --from=plv8 /opt/bitnami/postgresql/share/extension/plv8* /opt/bitnami/postgresql/share/extension/
COPY --from=plv8 /opt/bitnami/postgresql/share/extension/plcoffee* /opt/bitnami/postgresql/share/extension/
COPY --from=plv8 /opt/bitnami/postgresql/share/extension/plls* /opt/bitnami/postgresql/share/extension/
COPY --from=plv8 /opt/bitnami/postgresql/lib/plv8* /opt/bitnami/postgresql/lib/



RUN mkdir -p /var/lib/apt/lists/partial \
  ## runtime dependencies for plv8
  && runtimeDependencies="libc++1 \
  libtinfo5 \
  libc++abi1" \
  && install_packages ${runtimeDependencies} wget git gcc make build-essential libxml2-dev libgeos-dev libproj-dev \
  libgdal-dev \
  libprotobuf-c1 libprotobuf-c-dev protobuf-c-compiler


ENV POSTGIS_VERSION 3.1.4

## Download Postgis
RUN wget -O /tmp/postgis.tar.gz "https://download.osgeo.org/postgis/source/postgis-$POSTGIS_VERSION.tar.gz"

## build and Install Postgis
RUN cd /tmp \
  && export C_INCLUDE_PATH=/opt/bitnami/postgresql/include/:/opt/bitnami/common/include/ \
  && export LIBRARY_PATH=/opt/bitnami/postgresql/lib/:/opt/bitnami/common/lib/ \
  && export LD_LIBRARY_PATH=/opt/bitnami/postgresql/lib/:/opt/bitnami/common/lib/ \
  && tar zxf postgis.tar.gz \
  && cd postgis-$POSTGIS_VERSION \
  && ./configure --with-pgconfig=/opt/bitnami/postgresql/bin/pg_config \
  && make \
  && make install \
  && cd ~ \
  && rm /tmp/postgis.tar.gz \
  && rm -rf /tmp/postgis-$POSTGIS_VERSION

## git clone pgjwt repo, make and install
RUN cd /tmp \
  && git clone https://github.com.cnpmjs.org/michelp/pgjwt.git \
  && cd pgjwt \
  && sed 's;PG_CONFIG = pg_config;PG_CONFIG = \/opt\/bitnami\/postgresql\/bin\/pg_config;g' Makefile \
  && export C_INCLUDE_PATH=/opt/bitnami/postgresql/include/:/opt/bitnami/common/include/ \
  && export LIBRARY_PATH=/opt/bitnami/postgresql/lib/:/opt/bitnami/common/lib/ \
  && export LD_LIBRARY_PATH=/opt/bitnami/postgresql/lib/:/opt/bitnami/common/lib/ \
  && make \
  && make install \
  && cd ~ \
  && rm -rf /tmp/pgjwt

RUN apt-get update && apt-get purge --auto-remove -y \
  wget git gcc make build-essential libxml2-dev libgeos-dev libproj-dev \
  libgdal-dev \
  libprotobuf-c-dev protobuf-c-compiler \
  && apt-get install -y libxml2 \
  && rm -rf /var/lib/apt/lists/*

USER 1001
