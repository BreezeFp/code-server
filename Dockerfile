FROM node:10.15.1

# Install VS Code's deps. These are the only two it seems we need.
RUN apt-get update && apt-get install -y \
	libxkbfile-dev \
	libsecret-1-dev

# Ensure latest yarn.
RUN npm install -g yarn@1.13

WORKDIR /src
COPY . .

# In the future, we can use https://github.com/yarnpkg/rfcs/pull/53 to make yarn use the node_modules
# directly which should be fast as it is slow because it populates its own cache every time.
RUN yarn && NODE_ENV=production yarn task build:server:binary

# We deploy with ubuntu so that devs have a familiar environment.
FROM ubuntu:18.04

RUN apt-get update && apt-get install -y \
	openssl \
	net-tools \
	git \
	locales \
	sudo \
	dumb-init \
	vim \
	curl \
	wget

RUN locale-gen en_US.UTF-8
# We unfortunately cannot use update-locale because docker will not use the env variables
# configured in /etc/default/locale so we need to set it manually.
ENV LC_ALL=en_US.UTF-8

RUN adduser --gecos '' --disabled-password coder && \
	echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

USER coder
# We create first instead of just using WORKDIR as when WORKDIR creates, the user is root.
RUN mkdir -p /home/coder/project

WORKDIR /home/coder/project

# This assures we have a volume mounted even if the user forgot to do bind mount.
# So that they do not lose their data if they delete the container.
VOLUME [ "/home/coder/project" ]

COPY --from=0 /src/packages/server/cli-linux-x64 /usr/local/bin/code-server
EXPOSE 8443

ENTRYPOINT ["dumb-init", "code-server"]


ENV DEBIAN_FRONTEND noninteractive

ENV VERSION 8
ENV UPDATE 171
ENV BUILD 11
ENV SIG 512cd62ec5174c3487ac17c61aaa89e8

ENV JAVA_HOME /usr/lib/jvm/java-${VERSION}-oracle

# install jdk
RUN apt-get update -qq && \
  apt-get upgrade -qqy --no-install-recommends && \
  apt-get install curl unzip bzip2 -qqy && \
  mkdir -p "${JAVA_HOME}" && \
  curl --silent --location --insecure --junk-session-cookies --retry 3 \
	  --header "Cookie: oraclelicense=accept-securebackup-cookie;" \
	  http://download.oracle.com/otn-pub/java/jdk/"${VERSION}"u"${UPDATE}"-b"${BUILD}"/"${SIG}"/jdk-"${VERSION}"u"${UPDATE}"-linux-x64.tar.gz \
	| tar -xzC "${JAVA_HOME}" --strip-components=1 && \
  apt-get remove --purge --auto-remove -y curl unzip bzip2 && \
  apt-get autoclean && apt-get --purge -y autoremove && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
  update-alternatives --install "/usr/bin/java" "java" "${JAVA_HOME}/bin/java" 1 && \
	update-alternatives --install "/usr/bin/javaws" "javaws" "${JAVA_HOME}/bin/javaws" 1 && \
	update-alternatives --install "/usr/bin/javac" "javac" "${JAVA_HOME}/bin/javac" 1 && \
	update-alternatives --set java "${JAVA_HOME}/bin/java" && \
	update-alternatives --set javaws "${JAVA_HOME}/bin/javaws" && \
	update-alternatives --set javac "${JAVA_HOME}/bin/javac"