ARG ZNUNY_VERSION=7.3
# sha256 of https://download.znuny.org/releases/znuny-7.3.tar.gz, recomputed
# 2026-09-02. NOTE: this URL is a mutable alias for the latest 7.3.x patch
# release (currently resolves to 7.3.6) rather than an immutable artifact —
# znuny.org has changed its contents in place before (the previously pinned
# checksum here was stale, matching neither 7.3.3, the version actually
# deployed, nor the 7.3.6 content served today). Bumping this checksum is
# therefore how a version bump gets deliberately acknowledged; a mismatch
# now fails the build instead of silently extracting whatever is being served.
ARG ZNUNY_CHECKSUM=bea98ea445d08f998ecff757601dd8a9e59622d5feb664c2f356723c4446b6cb

FROM ruby:alpine AS builder

ARG ZNUNY_VERSION

RUN gem install bashly

COPY ./ /tmp

WORKDIR /tmp/

RUN bashly generate --env production

FROM debian:bookworm-slim

ARG ZNUNY_VERSION
ARG ZNUNY_CHECKSUM

WORKDIR /opt/znuny

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  cpanminus \
  libjq-dev \
  wget \
  curl \
  jq \
  apache2 \
  openssl \
  cron \
  locales \
  gnupg2 \
  libapache2-mod-perl2 \
  libssl-dev \
  libxml2-dev \
  libtimedate-perl \
  libnet-dns-perl \
  libnet-ldap-perl \
  libio-socket-ssl-perl \
  libpdf-api2-perl \
  libsoap-lite-perl \
  libtext-csv-xs-perl \
  libjson-xs-perl \
  libapache-dbi-perl \
  libxml-libxml-perl \
  libxml-libxslt-perl \
  libyaml-perl \
  libarchive-zip-perl \
  libcrypt-eksblowfish-perl \
  libencode-hanextra-perl \
  libmail-imapclient-perl \
  libtemplate-perl \
  libdatetime-perl \
  libmoo-perl \
  bash-completion \
  libyaml-libyaml-perl \
  libjavascript-minifier-xs-perl \
  libcss-minifier-xs-perl \
  libauthen-sasl-perl \
  libauthen-ntlm-perl \
  libhash-merge-perl \
  libical-parser-perl \
  libspreadsheet-xlsx-perl \
  libdata-uuid-perl \
  libdbd-odbc-perl \
  libdbd-pg-perl \
  libcpan-audit-perl \
  libcrypt-jwt-perl \
  libcrypt-openssl-x509-perl \
  libexcel-writer-xlsx-perl \
  libcrypt-smime-perl \
  sendmail \
  && apt-get clean all

RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
  && sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
  && apt update \
  && apt install -y postgresql-client-16 \
  && apt-get clean all

RUN cpanm Jq Net::SAML2

COPY --from=builder /tmp/zcli /usr/bin/

RUN /usr/bin/zcli download -r ${ZNUNY_VERSION} -s ${ZNUNY_CHECKSUM} \
      && zcli config locales

EXPOSE 80

ENTRYPOINT [ "zcli", "init", "all" ]
