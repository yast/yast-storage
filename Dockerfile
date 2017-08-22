FROM yastdevel/ruby:sle12-sp2
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  libstorage-devel \
  libstorage-ruby \
  libtool \
  "rubygem(ruby-dbus)" \
  yast2-core-devel
COPY . /usr/src/app

